{
  config,
  lib,
  pkgs,
  ...
}: let
  hosts = import ../../lib/hosts.nix;
in {
  imports = [
    # Static ens18 address + gateway from the host registry.
    (hosts.staticNetwork "dns")
    ../../modules/common.nix
    # XFS root on ssd_pool, not the old btrfs-on-zfs_pool layout
    # (modules/disko-config.nix). Two reasons, both covered in disko-xfs.nix:
    # the guest disk is a zvol, so btrfs stacked a second CoW+compression layer
    # on ZFS's; and this root is the resolver every other host depends on, so it
    # has no business sharing the ~78 IOPS 2-HDD zfs_pool. Switching the format
    # needs a nixos-anywhere reinstall -- disko never runs during `colmena
    # apply`. See todo/dns-ssd-xfs-migration.md.
    ../../modules/disko-xfs.nix
    ../../modules/tailscale.nix
    ../../modules/step-ca-trust.nix
    ../../modules/caddy-http3.nix
  ];

  networking.hostName = "homelab-dns";

  networking.nameservers = ["127.0.0.1" "192.168.2.1"]; # Override: DNS server uses localhost

  # Unbound DNS resolver with systemd integration
  services.unbound = {
    enable = true;
    settings = {
      server = {
        # Listen on all interfaces for local network DNS
        interface = ["0.0.0.0" "::0"];
        port = 53;

        # Access control - allow local network
        access-control = [
          "127.0.0.0/8 allow"
          "192.168.2.0/24 allow"
          "::1/128 allow"
          # Tailnet clients query this node's own LAN IP (192.168.2.145) via the
          # subnet router. Traffic terminating on the router itself is NOT
          # SNATed, so unbound sees the client's raw Tailscale CGNAT source
          # address rather than a 192.168.2.x one. Allow the tailnet ranges so
          # split-DNS lookups from remote clients aren't silently dropped.
          "100.64.0.0/10 allow"
          "fd7a:115c:a1e0::/48 allow"
        ];

        # Performance and caching settings
        num-threads = 2;
        msg-cache-slabs = 4;
        rrset-cache-slabs = 4;
        infra-cache-slabs = 4;
        key-cache-slabs = 4;
        rrset-cache-size = "100m";
        msg-cache-size = "50m";

        # Prefetch popular entries before they expire
        prefetch = true;
        prefetch-key = true;

        # Security hardening
        harden-glue = true;
        harden-dnssec-stripped = true;
        harden-referral-path = true;
        use-caps-for-id = false;

        # Privacy settings
        hide-identity = true;
        hide-version = true;
        qname-minimisation = true;

        # Buffer size for EDNS
        edns-buffer-size = 1232;

        # Root hints for recursive resolution
        root-hints = "${pkgs.dns-root-data}/root.hints";

        # DNSSEC validation is handled automatically by NixOS via enableRootTrustAnchor (default true)
        # which uses a writable state directory for auto-trust-anchor-file

        # Logging
        verbosity = 1;
        log-queries = false;
        log-replies = false;
        log-servfail = true;

        # Static local DNS records
        local-zone = [
          "local. static"
          "homelab.local. static"
          # Parallel private zone. Apple clients force *.local to mDNS/Bonjour and
          # never send it to a unicast resolver, so homelab.local is unreachable
          # from macOS/iOS over Tailscale split DNS. homelab.internal (ICANN-
          # reserved private TLD) resolves normally. Both zones are served.
          "homelab.internal. static"
        ];
        # A and PTR records for every name in the host registry
        # (lib/hosts.nix): one place to add or re-address a host.
        local-data = hosts.dns.localData;
        local-data-ptr = hosts.dns.localDataPtr;
      };

      # Forward zone for upstream DNS (using DNS over TLS)
      forward-zone = [
        {
          name = ".";
          forward-addr = [
            "1.1.1.1@853#cloudflare-dns.com"
            "1.0.0.1@853#cloudflare-dns.com"
            "9.9.9.9@853#dns.quad9.net"
            "149.112.112.112@853#dns.quad9.net"
          ];
          forward-tls-upstream = true;
        }
      ];
    };
  };

  # Ensure unbound starts after network is ready
  systemd.services.unbound = {
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Restart = "on-failure";
    };
  };

  # Caddy reverse proxy with Tailscale TLS for management interface
  services.caddy = {
    enable = true;

    # Tailscale hostname
    virtualHosts."homelab-dns.dropbear-butterfly.ts.net" = {
      extraConfig = ''
        tls {
          get_certificate tailscale
        }

        handle {
          respond "DNS Server OK" 200
        }
      '';
    };

    # Local network hostname with step-ca certificate
    virtualHosts."dns.homelab.local dns.homelab.internal" = {
      extraConfig = ''
        tls {
          ca https://ca.homelab.local:8443/acme/acme/directory
        }

        handle {
          respond "DNS Server OK" 200
        }
      '';
    };
  };

  # Subnet router: advertise the LAN so tailnet clients (e.g. a laptop while
  # away) can reach *.homelab.local by their real 192.168.2.x addresses and hit
  # the internal Caddy vhosts with genuine step-ca certs. "server" enables
  # net.ipv4.ip_forward. Pair with a split-DNS entry (homelab.local ->
  # 192.168.2.145) in the Tailscale admin console.
  # NOTE: tailscaled-autoconnect only runs `tailscale up` when not already
  # connected, so on an already-authed node apply the route once by hand:
  #   sudo tailscale set --advertise-routes=192.168.2.0/24
  services.tailscale.useRoutingFeatures = "server";
  services.tailscale.extraUpFlags = ["--advertise-routes=192.168.2.0/24"];

  # Allow Caddy to get Tailscale certs
  services.tailscale.permitCertUid = "caddy";

  # Give Caddy access to Tailscale socket for cert fetching
  systemd.services.caddy.serviceConfig.BindPaths = "/var/run/tailscale/tailscaled.sock";

  networking.firewall = {
    enable = true;
    trustedInterfaces = ["tailscale0"];
    allowedTCPPorts = [
      22 # SSH
      53 # DNS
      443 # HTTPS (Caddy)
      9100 # Node exporter
    ];
    allowedUDPPorts = [
      53 # DNS
    ];
  };

  environment.systemPackages = with pkgs; [
    bind # For dig/nslookup utilities
    ldns # For drill DNS tool
  ];
}
