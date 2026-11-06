# Nebula overlay client for fleet hosts: joins the mozart409 overlay served by
# the lighthouse fleet in ~/code/nixos-ventara-ai (lighthouse-{a,b,c}.oyabu.cc).
# Overlay addresses are allocated in services/nebula/tenants.nix in that repo
# and mirrored as `overlay` in lib/hosts.nix. Generalised from
# hosts/wotan/nebula.nix; the plan is todo/tailscale-to-nebula.md.
{
  config,
  lib,
  ...
}: let
  cfg = config.homelab.nebula;
  hosts = import ../lib/hosts.nix;

  network = "mozart409";
  port = 4343;
  overlay = "172.16.20";
  device = "nebula-mz409"; # upstream default "nebula.mozart409" is 16 chars and fails eval

  secretName = "nebula-${network}-${cfg.node}";
  secretFile = ../secrets/${secretName}.age;
  # Not under hosts/: some hosts live in odd directories (mcp is hosts/mcp_vm).
  # The dir is created with the first cert.
  certFile = ./nebula/${network}-${cfg.node}.crt;
  # One copy of the CA for the whole repo; wotan's directory holds it.
  caFile = ../hosts/wotan/nebula/${network}-ca.crt;

  # pathExists on a flake source: an untracked file counts as missing.
  ready = builtins.pathExists secretFile && builtins.pathExists certFile;

  tailscaleRanges = {
    "100.64.0.0/10" = false;
    "fd7a:115c:a1e0::/48" = false;
  };

  # One inbound rule per group x port x protocol.
  inboundRules = lib.concatMap (group:
    (map (p: {
        port = p;
        proto = "tcp";
        inherit group;
      })
      cfg.allowedTCPPorts)
    ++ (map (p: {
        port = p;
        proto = "udp";
        inherit group;
      })
      cfg.allowedUDPPorts))
  cfg.allowedGroups;
in {
  options.homelab.nebula = {
    enable = lib.mkEnableOption "the mozart409 Nebula overlay client";

    node = lib.mkOption {
      type = lib.types.str;
      description = "Registry name in lib/hosts.nix; names the cert and key files and gives the overlay address.";
      example = "dns";
    };

    allowedTCPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [];
      description = "TCP ports overlay clients in allowedGroups may reach.";
    };

    allowedUDPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [];
      description = "UDP ports overlay clients in allowedGroups may reach.";
    };

    allowedGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["admin" "mobile"];
      description = "Nebula cert groups allowed to reach the ports above.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      warnings = lib.optional (!ready) "homelab.nebula (${cfg.node}): secrets/${secretName}.age and modules/nebula/${network}-${cfg.node}.crt are not both present. The host does not join the ${network} overlay until they exist and are `git add`ed.";
    }

    (lib.mkIf ready {
      assertions = [
        {
          assertion = (hosts.hosts.${cfg.node}.overlay or null) != null;
          message = "homelab.nebula: ${cfg.node} has no `overlay` address in lib/hosts.nix";
        }
      ];

      age.secrets.${secretName} = {
        file = secretFile;
        # The upstream module runs nebula@<network> as user nebula-<network>.
        owner = "nebula-${network}";
        group = "nebula-${network}";
        mode = "0400";
      };

      services.nebula.networks.${network} = {
        enable = true;
        isLighthouse = false;
        ca = caFile;
        cert = certFile;
        key = config.age.secrets.${secretName}.path;

        # All three lighthouses in BOTH lists: that is the whole HA config.
        # Keyed by overlay IP; the name is re-resolved every static_map.cadence.
        staticHostMap = {
          "${overlay}.1" = ["lighthouse-a.oyabu.cc:${toString port}"];
          "${overlay}.2" = ["lighthouse-b.oyabu.cc:${toString port}"];
          "${overlay}.3" = ["lighthouse-c.oyabu.cc:${toString port}"];
        };

        lighthouses = ["${overlay}.1" "${overlay}.2" "${overlay}.3"];
        # Accept traffic relayed by the lighthouses when hole punching fails.
        relays = ["${overlay}.1" "${overlay}.2" "${overlay}.3"];

        # Dual-stack bind on a fixed port, open in the host firewall below.
        # With the module's ephemeral default a LAN peer's handshake is dropped
        # and the tunnel falls back to a lighthouse relay (15 ms, not 0.25 ms).
        listen = {
          host = "::";
          inherit port;
        };
        tun.device = device;

        # ICMP, TCP and DNS only -- NO general UDP. Tailscale advertises every
        # local address as a WireGuard endpoint, so two hosts on both overlays
        # route Tailscale THROUGH nebula; its packets exceed nebula's 1300 MTU
        # and SSH over the tailnet stalls silently. Widen once Tailscale is
        # gone.
        firewall.outbound = [
          {
            port = "any";
            proto = "icmp";
            host = "any";
          }
          {
            port = "any";
            proto = "tcp";
            host = "any";
          }
          {
            port = 53;
            proto = "udp";
            host = "any";
          }
        ];

        # Nebula's own firewall is the overlay ACL -- do NOT add the tun
        # device to networking.firewall.trustedInterfaces. ICMP from anyone,
        # the configured ports only from the configured cert groups.
        firewall.inbound =
          [
            {
              port = "any";
              proto = "icmp";
              host = "any";
            }
          ]
          ++ inboundRules;

        settings = {
          # Defaults to "ip4" upstream. "ip" tries both families: a v6 host
          # uses the AAAA records, a v4-only one the A records.
          static_map = {
            network = "ip";
            cadence = "30s";
          };
          punchy = {
            punch = true;
            respond = true;
          };
          # Never advertise or accept a Tailscale address (nebula over
          # Tailscale breaks above its 1280 MTU), nor advertise a container
          # bridge. Within one map every value must be the same.
          lighthouse = {
            local_allow_list =
              tailscaleRanges
              // {
                interfaces = {
                  "docker.*" = false;
                  "podman.*" = false;
                  "tailscale.*" = false;
                  "nebula.*" = false;
                };
              };
            remote_allow_list = tailscaleRanges;
          };
        };
      };

      # Nebula's underlay port, so peers on the LAN can reach this host directly.
      networking.firewall.allowedUDPPorts = [port];

      # Both layers must allow a port: nebula's inbound rules above and the
      # host firewall here. One option list feeds both, so they cannot drift.
      networking.firewall.interfaces.${device} = {
        inherit (cfg) allowedTCPPorts allowedUDPPorts;
      };

      # Same value the Tailscale module sets today; set here too so removing
      # that module later does not change it.
      networking.firewall.checkReversePath = "loose";

      # The decrypted path is stable, so a rotated key would otherwise not
      # restart the unit.
      systemd.services."nebula@${network}".restartTriggers = [
        config.age.secrets.${secretName}.file
      ];
    })
  ]);
}
