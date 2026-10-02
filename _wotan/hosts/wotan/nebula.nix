# Nebula overlay client: wotan joins the amartum and mozart409 overlays served
# by the lighthouse fleet in ~/code/nixos-ventara-ai (lighthouse-{a,b,c}.oyabu.cc).
# One tenant = one CA = one nebula process (nebula@<tenant>), one tun device,
# one cert + key. Tenant facts come from that repo's services/nebula/tenants.nix.
# Full plan and rationale: todo/nebula-clients.md.
{
  config,
  lib,
  ...
}: let
  tenants = {
    amartum = {
      port = 4242;
      overlay = "172.16.10";
      device = "nebula-amartum"; # <= 15 chars (IFNAMSIZ)
    };
    mozart409 = {
      port = 4343;
      overlay = "172.16.20";
      device = "nebula-mz409"; # upstream default "nebula.mozart409" is 16 chars and fails eval
    };
  };

  mkSecret = t: {
    file = ../../secrets/nebula-${t}-wotan.age;
    # The upstream module runs nebula@<t> as user nebula-<t>.
    owner = "nebula-${t}";
    group = "nebula-${t}";
    mode = "0400";
  };

  mkNetwork = t: v: {
    enable = true;
    isLighthouse = false;
    ca = ./nebula/${t}-ca.crt;
    cert = ./nebula/${t}-wotan.crt;
    key = config.age.secrets."nebula-${t}-wotan".path;

    # All three lighthouses in BOTH lists: that is the whole HA config.
    # Keyed by overlay IP; the name is re-resolved every static_map.cadence.
    staticHostMap = {
      "${v.overlay}.1" = ["lighthouse-a.oyabu.cc:${toString v.port}"];
      "${v.overlay}.2" = ["lighthouse-b.oyabu.cc:${toString v.port}"];
      "${v.overlay}.3" = ["lighthouse-c.oyabu.cc:${toString v.port}"];
    };

    lighthouses = ["${v.overlay}.1" "${v.overlay}.2" "${v.overlay}.3"];
    # Accept traffic relayed by the lighthouses (isRelay since ADR 0007) when
    # hole punching fails, e.g. to vm01 behind vidar-01's MASQUERADE.
    relays = ["${v.overlay}.1" "${v.overlay}.2" "${v.overlay}.3"];

    # Client behind home NAT: dual-stack bind, ephemeral port (module
    # default for non-lighthouses), punch through.
    listen.host = "::";
    tun.device = v.device;

    # ICMP, TCP and DNS only -- NO general UDP. Tailscale advertises every
    # local address as a WireGuard endpoint, so two hosts on both overlays
    # route Tailscale THROUGH nebula; its packets exceed nebula's 1300 MTU and
    # SSH over the tailnet stalls silently. Same rule as ventara's
    # `ventara.nebula.defaultOutbound` (its AGENTS.md §5). Widen once
    # Tailscale is gone.
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

    # A workstation offers nothing on the overlay; widen per port + group
    # when needed. Nebula's own firewall is the overlay ACL -- do NOT add the
    # tun devices to networking.firewall.trustedInterfaces.
    firewall.inbound = [
      {
        port = "any";
        proto = "icmp";
        host = "any";
      }
    ];

    settings = {
      # Defaults to "ip4" upstream. "ip" tries both families: wotan has no
      # IPv6 route today so it uses the A records; a v6 host the AAAA.
      static_map = {
        network = "ip";
        cadence = "30s";
      };
      punchy = {
        punch = true;
        respond = true;
      };
      # Never advertise or accept a Tailscale address (nebula over Tailscale
      # breaks above its 1280 MTU), nor advertise a container bridge. Same as
      # ventara's `underlayExclude` / `localExcludeInterfaces`. Within one
      # map every value must be the same.
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

  tailscaleRanges = {
    "100.64.0.0/10" = false;
    "fd7a:115c:a1e0::/48" = false;
  };
in {
  age.secrets = lib.mapAttrs' (t: _: lib.nameValuePair "nebula-${t}-wotan" (mkSecret t)) tenants;
  services.nebula.networks = lib.mapAttrs mkNetwork tenants;

  # Split DNS for ~int.oyabu.cc needs resolved. mDNS stays with avahi (the
  # CUPS printer's .local URI), so resolved must not bind 5353 too.
  services.resolved = {
    enable = true;
    settings.Resolve.MulticastDNS = false;
  };

  # Keep NetworkManager off the tuns, so it never claims the link and resets
  # the per-link DNS set below.
  networking.networkmanager.unmanaged = ["interface-name:nebula-*"];

  # "-" keeps a resolvectl failure from failing nebula@amartum itself.
  systemd.services."nebula@amartum".serviceConfig.ExecStartPost = [
    "-+${config.systemd.package}/bin/resolvectl dns nebula-amartum 172.16.10.1 172.16.10.2 172.16.10.3"
    "-+${config.systemd.package}/bin/resolvectl domain nebula-amartum ~int.oyabu.cc"
  ];
}
