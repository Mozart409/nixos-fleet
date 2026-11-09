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
#   colmena    true for hosts colmena deploys (the fleet).
#   deployByIp colmena reaches the host by raw IP, not by name (the resolver
#              itself: you cannot deploy a fix for a broken unbound through
#              unbound).
#   overlay    mozart409 Nebula overlay address; must match
#              services/nebula/tenants.nix in ~/code/nixos-ventara-ai. Only
#              hosts on the overlay have one.
#   interface  NIC that staticNetwork configures (default "ens18", the Proxmox
#              virtio NIC).
#
# Machines outside this repo (the Proxmox hypervisor, Home
# Assistant, the UniFi OS VM) and wotan are listed only for their DNS records. The Raspberry Pi
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
      overlay = "172.16.20.9";
      zones = ["homelab.internal"];
      ptr = ["homelab.internal"];
      colmena = true;
    };
    ca = {
      ip = "192.168.2.160";
      overlay = "172.16.20.5";
      colmena = true;
    };
    containers = {
      ip = "192.168.2.149";
      overlay = "172.16.20.12";
      colmena = true;
      aliases = {
        countdown = internalOnly;
        dashboard = {};
        # Home Assistant (the HAOS VM below) behind this host's Caddy.
        ha = internalOnly;
        hindsight = internalOnly;
        hindsight-ui = internalOnly;
        mailpit = internalOnly;
        multica = internalOnly;
        # Moved from the CT 102 LXC.
        pocketid = internalOnly;
        romm = {};
        searxng = {};
      };
    };
    database = {
      ip = "192.168.2.134";
      overlay = "172.16.20.6";
      colmena = true;
    };
    dns = {
      ip = "192.168.2.145";
      overlay = "172.16.20.4";
      colmena = true;
      deployByIp = true;
    };
    forgejo = {
      ip = "192.168.2.178";
      overlay = "172.16.20.7";
      colmena = true;
    };
    homeassistant = {
      ip = "192.168.2.208";
      zones = ["local"];
      ptr = ["local"];
    };
    jellyfin = {
      ip = "192.168.2.180";
      overlay = "172.16.20.8";
      colmena = true;
      aliases.hofvarpnir = {};
    };
    k3s-cntrl-1 = {
      ip = "192.168.2.186";
    };
    mcp = {
      ip = "192.168.2.152";
      overlay = "172.16.20.10";
      colmena = true;
      aliases.axon = {};
    };
    otel = {
      ip = "192.168.2.135";
      overlay = "172.16.20.11";
      colmena = true;
      aliases = {
        alertmanager = {};
        loki = {};
        prometheus = {};
        tempo = {};
      };
    };
    pve-gigabyte = {
      ip = "192.168.2.46";
      zones = legacyAndInternal ++ ["local"];
      ptr = ["homelab.local" "local"];
    };
    scratchpad = {
      ip = "192.168.2.185";
    };
    # UniFi OS Server, a Fedora VM (iac/main.tf unifi_vm), installed by hand,
    # not NixOS. Same name, address and zones as the retired NixOS controller,
    # so a device that informs by name still finds it. Its own Caddy serves
    # the UI on :443 (todo/unifi-os-server-vm.md).
    unifi = {
      ip = "192.168.2.142";
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
      overlay = h.overlay or null;
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

  # Names with an overlay address that are served in homelab.internal.
  overlayNames = builtins.filter (n: n.overlay != null && builtins.elem "homelab.internal" n.zones) names;

  # Primary DNS name of a host or alias: <name>.<first zone>.
  fqdn = name: "${name}.${builtins.head byName.${name}.zones}";
in {
  inherit network hosts fqdn;

  # What colmena's targetHost resolves to.
  deployAddr = name:
    if hosts.${name}.deployByIp or false
    then hosts.${name}.ip
    else fqdn name;

  # The hosts colmena deploys (those with colmena = true).
  fleet = builtins.filter (n: hosts.${n}.colmena or false) (builtins.attrNames hosts);

  # unbound local-data / local-data-ptr, already quoted and sorted byte-wise
  # (the order keep-sorted kept the hand-written lists in).
  dns = {
    localData = sortStrings (builtins.concatMap (n:
      map (zone: ''"${n.name}.${zone}. A ${n.ip}"'') n.zones)
    names);
    localDataPtr = sortStrings (builtins.concatMap (n:
      map (zone: ''"${n.ip} ${n.name}.${zone}"'') n.ptr)
    names);

    # The same names for clients on the mozart409 overlay (unbound view
    # "overlay"): only hosts with an overlay address, in homelab.internal.
    overlayLocalZone =
      sortStrings (map (n: ''"${n.name}.homelab.internal." static'')
        overlayNames);
    overlayLocalData =
      sortStrings (map (n: ''"${n.name}.homelab.internal. A ${n.overlay}"'')
        overlayNames);
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
