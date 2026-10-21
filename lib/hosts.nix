# The homelab host registry: the one place that maps names to LAN addresses.
#
# Everything that used to repeat an IP derives from this file:
#   - `dns.localData` / `dns.localDataPtr`: unbound's A and PTR records
#     (hosts/dns/configuration.nix)
#   - `deployAddr`: the colmena targetHost behind hostAddrs (flake.nix)
#   - `staticNetwork`: the ens18 address + default gateway module each fleet
#     VM imports
#   - `fqdn`: the name prometheus scrapes (hosts/otel/configuration.nix)
# OpenTofu (iac/main.tf) still carries its own copy of the VM addresses.
#
# Pure builtins on purpose (no nixpkgs lib), so it can be imported from any
# module, the flake's let-block or a `nix eval` that renders it for another
# tool.
#
# Entries:
#   ip         LAN address (192.168.2.0/24).
#   zones      DNS zones that get an A record for <name> (and every alias),
#              first entry = the primary name `fqdn` returns. Default
#              ["homelab.internal" "homelab.local"]; .internal-only for names
#              born after the legacy zone was frozen.
#   ptr        zones whose <name>.<zone> gets a PTR record. Default
#              ["homelab.local"] (PTRs were never mirrored into .internal).
#   aliases    extra names on the same ip: name -> { zones?, ptr? } with the
#              same defaults.
#   tailscale  tailnet name; only colmena-deployed fleet hosts have one.
#   deployByIp colmena reaches the host by raw IP, not by name (the resolver
#              itself: you cannot deploy a fix for a broken unbound through
#              unbound).
#   interface  NIC that staticNetwork configures (default "ens18", the Proxmox
#              virtio NIC).
#
# Machines outside this repo (pocketid LXC, the Proxmox hypervisor, Home
# Assistant) and wotan are listed only for their DNS records. The Raspberry Pi
# fleet takes DHCP leases and lives in lib/pi-fleet.nix.
let
  network = {
    gateway = "192.168.2.1";
    prefixLength = 24;
  };

  legacyAndInternal = ["homelab.internal" "homelab.local"];
  internalOnly = {
    zones = ["homelab.internal"];
    ptr = [];
  };

  hosts = {
    agents = {
      ip = "192.168.2.190";
      zones = ["homelab.internal"];
      ptr = ["homelab.internal"];
      tailscale = "homelab-agents";
    };
    ca = {
      ip = "192.168.2.160";
      tailscale = "homelab-ca";
    };
    containers = {
      ip = "192.168.2.149";
      tailscale = "homelab-containers";
      aliases = {
        dashboard = {};
        hindsight = internalOnly;
        hindsight-ui = internalOnly;
        mailpit = internalOnly;
        multica = internalOnly;
        romm = {};
        searxng = {};
      };
    };
    database = {
      ip = "192.168.2.134";
      tailscale = "homelab-database";
    };
    dns = {
      ip = "192.168.2.145";
      tailscale = "homelab-dns";
      deployByIp = true;
    };
    forgejo = {
      ip = "192.168.2.178";
      tailscale = "homelab-forgejo";
    };
    homeassistant = {
      ip = "192.168.2.208";
      zones = ["local"];
      ptr = ["local"];
    };
    jellyfin = {
      ip = "192.168.2.180";
      tailscale = "homelab-jellyfin";
      aliases.hofvarpnir = {};
    };
    k3s-cntrl-1 = {
      ip = "192.168.2.186";
    };
    mcp = {
      ip = "192.168.2.152";
      tailscale = "homelab-mcp";
      aliases.axon = {};
    };
    otel = {
      ip = "192.168.2.135";
      tailscale = "homelab-otel";
      aliases = {
        alertmanager = {};
        loki = {};
        prometheus = {};
        tempo = {};
      };
    };
    # Pocket-ID (OIDC provider for forgejo, romm, grafana). An LXC on
    # pve-gigabyte, not a NixOS guest in this repo. The tailnet name
    # pocketid.dropbear-butterfly.ts.net stays the issuer every consumer is
    # configured with -- the issuer URL is part of token identity, so these
    # records ADD a LAN path, they do not replace it. A client that switches
    # to the .internal name also needs Pocket-ID to serve a certificate valid
    # for it.
    pocketid = {
      ip = "192.168.2.102";
    };
    pve-gigabyte = {
      ip = "192.168.2.46";
      zones = legacyAndInternal ++ ["local"];
      ptr = ["homelab.local" "local"];
    };
    scratchpad = {
      ip = "192.168.2.185";
    };
    unifi = {
      ip = "192.168.2.142";
      tailscale = "homelab-unifi";
    };
    wotan = {
      ip = "192.168.2.71";
    };
  };

  # Every DNS name: { name, ip, zones, ptr } for each host and each alias.
  names = builtins.concatMap (host: let
    h = hosts.${host};
    entry = name: e: {
      inherit name;
      inherit (h) ip;
      zones = e.zones or legacyAndInternal;
      ptr = e.ptr or ["homelab.local"];
    };
    aliases = h.aliases or {};
  in
    [(entry host h)]
    ++ map (a: entry a aliases.${a}) (builtins.attrNames aliases))
  (builtins.attrNames hosts);

  sortStrings = builtins.sort builtins.lessThan;

  byName = builtins.listToAttrs (map (n: {
      inherit (n) name;
      value = n;
    })
    names);

  # Primary DNS name of a host or alias: <name>.<first zone>.
  fqdn = name: "${name}.${builtins.head byName.${name}.zones}";
in {
  inherit network hosts fqdn;

  # What colmena's targetHost resolves to off the tailnet.
  deployAddr = name:
    if hosts.${name}.deployByIp or false
    then hosts.${name}.ip
    else fqdn name;

  # The hosts colmena deploys (those with a tailnet name).
  fleet = builtins.filter (n: hosts.${n} ? tailscale) (builtins.attrNames hosts);

  # unbound local-data / local-data-ptr, already quoted and sorted byte-wise
  # (the order keep-sorted kept the hand-written lists in).
  dns = {
    localData = sortStrings (builtins.concatMap (n:
      map (zone: ''"${n.name}.${zone}. A ${n.ip}"'') n.zones)
    names);
    localDataPtr = sortStrings (builtins.concatMap (n:
      map (zone: ''"${n.ip} ${n.name}.${zone}"'') n.ptr)
    names);
  };

  # NixOS module: static address on the host's NIC plus the default gateway.
  staticNetwork = name: {
    networking.interfaces.${hosts.${name}.interface or "ens18"} = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = hosts.${name}.ip;
          inherit (network) prefixLength;
        }
      ];
    };
    networking.defaultGateway = network.gateway;
  };
}
