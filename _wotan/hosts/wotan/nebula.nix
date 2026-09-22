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

    # Client behind home NAT: dual-stack bind, ephemeral port (module
    # default for non-lighthouses), punch through.
    listen.host = "::";
    tun.device = v.device;

    # A workstation offers nothing on the overlay; widen per port + group
    # when needed. Nebula's own firewall is the overlay ACL -- do NOT add the
    # tun devices to networking.firewall.trustedInterfaces.
    firewall.outbound = [
      {
        port = "any";
        proto = "any";
        host = "any";
      }
    ];
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
    };
  };
in {
  age.secrets = lib.mapAttrs' (t: _: lib.nameValuePair "nebula-${t}-wotan" (mkSecret t)) tenants;
  services.nebula.networks = lib.mapAttrs mkNetwork tenants;
}
