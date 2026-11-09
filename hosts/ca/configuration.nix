{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    # Static ens18 address + gateway from the host registry.
    ((import ../../lib/hosts.nix).staticNetwork "ca")
    ../../modules/common.nix
    # XFS, not btrfs: `ca` ran btrfs on a zvol (CoW on CoW) and reached 89 % of a
    # 19 G root, the same state that wedged `dns`. Swapped 2026-09-09 alongside
    # the move to ssd_pool -- see todo/dns-cache-ssd-xfs-migration.md Part C.
    ../../modules/disko-xfs.nix
    ../../modules/nebula.nix
    ../../modules/step-ca-trust.nix
  ];

  networking.hostName = "homelab-ca";

  # mozart409 overlay; plan in todo/tailscale-to-nebula.md. The host joins once its cert and key exist (module warns until then).
  homelab.nebula = {
    enable = true;
    node = "ca";
    allowedTCPPorts = [22 8443];
  };

  # step-ca Certificate Authority
  # Password for the intermediate CA key (created via agenix)
  age.secrets.step-ca-password = {
    file = ../../secrets/step-ca-password.age;
    owner = "step-ca";
    group = "step-ca";
    mode = "0400";
  };

  services.step-ca = {
    enable = true;
    openFirewall = true; # Opens port 443 by default
    address = "0.0.0.0";
    port = 8443;
    intermediatePasswordFile = config.age.secrets.step-ca-password.path;

    settings = {
      root = "/var/lib/step-ca/certs/root_ca.crt";
      crt = "/var/lib/step-ca/certs/intermediate_ca.crt";
      key = "/var/lib/step-ca/secrets/intermediate_ca_key";
      dnsNames = [
        "ca.homelab.internal"
        "ca.homelab.local"
        "homelab-ca"
        "192.168.2.160"
        "localhost"
      ];

      db = {
        type = "badgerv2";
        dataSource = "/var/lib/step-ca/db";
      };

      # Per-request logging to the journal. Without a logger block step-ca logs
      # only its startup banner, so an ACME failure is visible solely from the
      # client side -- on 2026-09-11 Caddy on mcp reported badNonce on every
      # challenge POST for alertmanager-mcp while step-ca's journal had no
      # entries at all for the same seconds. Each request now logs its method,
      # path, status and duration.
      logger = {
        format = "json";
      };

      authority = {
        provisioners = [
          # ACME provisioner for automatic certificate issuance (like Let's Encrypt)
          {
            type = "ACME";
            name = "acme";
            claims = {
              # PVE/PBS only renew ACME certs when they expire within 30 days.
              # The authority default (720h = 30 days) sits inside that window,
              # so both would re-issue and mail every daily check; anything
              # above 30 days makes renewal fire once, ~60 days out.
              defaultTLSCertDuration = "2160h"; # 90 days
            };
          }
        ];

        claims = {
          # Certificate validity periods
          minTLSCertDuration = "5m";
          maxTLSCertDuration = "2160h"; # 90 days
          defaultTLSCertDuration = "720h"; # 30 days
        };
      };

      tls = {
        cipherSuites = [
          "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256"
          "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
        ];
        minVersion = 1.2;
        maxVersion = 1.3;
      };
    };
  };

  # Ensure step-ca starts after agenix decrypts secrets
  systemd.services.step-ca = {
    after = ["agenix.service"];
    wants = ["agenix.service"];
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # SSH
      8443 # step-ca ACME endpoint (also opened by openFirewall)
      9100 # Node exporter
    ];
  };

  environment.systemPackages = with pkgs; [
    step-cli # step CLI for interacting with step-ca
  ];
}
