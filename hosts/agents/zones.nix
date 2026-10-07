{
  config,
  lib,
  pkgs,
  self,
  ...
}: let
  # The trust zones (knowledge-base/projects/agent-platform/Sandboxing.md): one
  # microVM each, running one Multica daemon whose runtime name is the zone
  # name. The zone decides what its agents can touch, so a zone only gets the
  # secrets, packages and volumes listed here.
  #
  # `index` is the guest's address (10.42.0.<index>) and MAC suffix; never
  # reuse one. 10.42.0.1 is the host end of every tap.
  zones = {
    coding = {
      index = 2;
      vcpu = 4;
      mem = 8192;
      # Task worktrees (MULTICA_WORKSPACES_ROOT) and the writable Nix store
      # that `nix develop` in a task realises devShells into.
      workSize = 49152;
      storeSize = 24576;
      packages = [pkgs.opencode];
      environment = {};
      hermes = null;
    };
    assistant = {
      index = 3;
      vcpu = 2;
      mem = 3072;
      workSize = 8192;
      storeSize = 8192;
      packages = [pkgs.opencode hermes];
      # Hermes memory is the assistant's long-term memory; Multica's GC would
      # delete it after 90 days untouched.
      environment.MULTICA_GC_HERMES_MEMORY_TTL = "0";
      # ~/.hermes/config.yaml. Multica runs Hermes against the daemon user's
      # own home (or a per-task overlay derived from it), and Hermes has no
      # env fallback for the model. The key is OPENCODE_ZEN_API_KEY from the
      # zone env, which the daemon passes down to every agent.
      hermes = {
        model = {
          default = "space-bunny-free";
          provider = "opencode-zen";
        };
        timezone = "Europe/Berlin";
        # Nix-pinned; the "N commits behind" check diffs against upstream main.
        updates.check = false;
      };
    };
  };

  hermes = self.inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;

  hostAddr = "10.42.0.1";
  guestAddr = zone: "10.42.0.${toString zone.index}";
  tap = name: "vm-${name}";
  mac = zone: "02:00:00:42:00:${lib.fixedWidthString 2 "0" (lib.toHexString zone.index)}";
  stateDir = name: "${config.microvm.stateDir}/${name}";
  hostStateVersion = config.system.stateVersion;

  # systemd system credentials inside the guest (qemu fw_cfg, see
  # microvm.credentialFiles). PID 1 reads them as root, which is all
  # LoadCredential and EnvironmentFile need.
  credential = name: "/run/credentials/@system/${name}";

  guest = name: zone: {
    imports = [
      ../../modules/multica-daemon.nix
      ../../modules/step-ca-trust.nix
    ];

    system.stateVersion = hostStateVersion;

    microvm = {
      hypervisor = "qemu";
      inherit (zone) vcpu mem;

      interfaces = [
        {
          type = "tap";
          id = tap name;
          mac = mac zone;
        }
      ];

      # The host's store, read-only, plus a writable overlay so agents can
      # build. The overlay's Nix database forgets everything on reboot
      # (microvm.nix docs, "Writable /nix/store overlay"), so the image is
      # deleted before every start and recreated empty.
      shares = [
        {
          proto = "virtiofs";
          tag = "ro-store";
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
        }
      ];
      writableStoreOverlay = "/nix/.rw-store";
      preStart = ''
        rm -f ${stateDir name}/nix-store-overlay.img
      '';

      volumes = [
        {
          # /var holds the daemon user's home (~/.multica: login, logs, Hermes
          # memory) and the guest's SSH host key.
          image = "${stateDir name}/var.img";
          mountPoint = "/var";
          size = 8192;
        }
        {
          image = "${stateDir name}/work.img";
          mountPoint = "/srv/work";
          size = zone.workSize;
        }
        {
          image = "${stateDir name}/nix-store-overlay.img";
          mountPoint = "/nix/.rw-store";
          size = zone.storeSize;
        }
      ];

      credentialFiles = {
        multica-token = config.age.secrets."multica-token-${name}".path;
        zone-env = config.age.secrets."multica-zone-${name}-env".path;
      };
    };

    # Routed, not bridged: each zone has its own tap and /32, so zones share
    # no Ethernet segment (microvm.nix docs, "Routed network setup").
    networking.useNetworkd = true;
    systemd.network.networks."10-eth" = {
      matchConfig.MACAddress = mac zone;
      address = ["${guestAddr zone}/32"];
      routes = [
        {
          Destination = "${hostAddr}/32";
          GatewayOnLink = true;
        }
        {
          Destination = "0.0.0.0/0";
          Gateway = hostAddr;
          GatewayOnLink = true;
        }
      ];
      networkConfig.DNS = ["192.168.2.145" "192.168.2.1"];
    };

    # Debug access from the agents host only (10.42.0.0/24 is not routed
    # anywhere else): `ssh -J agents.homelab.internal root@10.42.0.<index>`.
    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      hostKeys = [
        {
          path = "/var/lib/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];
    };
    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHv1USrKf6yIjg8dZolm37xGysGfj18ol1KUKqsVuQHa amadeus@wotan"
    ];

    nix.settings.experimental-features = ["nix-command" "flakes"];

    homelab.multica.daemon.zones.${name} = {
      tokenFile = credential "multica-token";
      environmentFile = credential "zone-env";
      workspacesRoot = "/srv/work/${name}";
      packages = zone.packages ++ [pkgs.nix];
      inherit (zone) environment;
    };

    # opencode keeps provider keys in auth.json, not its config; merge the Zen
    # key in from the zone env (same approach as modules/coding-harness.nix).
    systemd.services."opencode-auth-${name}" = {
      description = "Write the OpenCode Zen key into the ${name} zone's opencode auth.json";
      wantedBy = ["multica-daemon-${name}.service"];
      before = ["multica-daemon-${name}.service"];
      serviceConfig = {
        Type = "oneshot";
        User = "multica-${name}";
        EnvironmentFile = credential "zone-env";
      };
      script = ''
        if [ -z "''${OPENCODE_ZEN_API_KEY:-}" ]; then
          echo "zone-env has no OPENCODE_ZEN_API_KEY, skipping" >&2
          exit 0
        fi
        authfile="$HOME/.local/share/opencode/auth.json"
        mkdir -p "$(dirname "$authfile")"
        [ -f "$authfile" ] || (umask 077; echo '{}' > "$authfile")
        tmp="$(mktemp)"
        ${pkgs.jq}/bin/jq '.opencode = {type: "api", key: env.OPENCODE_ZEN_API_KEY}' "$authfile" > "$tmp"
        (umask 077; mv "$tmp" "$authfile")
      '';
      environment.HOME = "/var/lib/multica-${name}";
    };

    # Rewritten on every boot, so Nix stays the source of truth even if a
    # `hermes model` run in the zone edited it.
    systemd.services."hermes-config-${name}" = lib.mkIf (zone.hermes != null) {
      description = "Write the ${name} zone's Hermes config.yaml";
      wantedBy = ["multica-daemon-${name}.service"];
      before = ["multica-daemon-${name}.service"];
      serviceConfig = {
        Type = "oneshot";
        User = "multica-${name}";
      };
      script = ''
        install -D -m 0600 ${(pkgs.formats.yaml {}).generate "hermes-${name}-config.yaml" zone.hermes} \
          /var/lib/multica-${name}/.hermes/config.yaml
      '';
    };
  };
in {
  imports = [self.inputs.microvm.nixosModules.host];

  # The guests are KVM guests of this (already virtualised) host: PVE exposes
  # nested virtualisation through CPU type `host` (iac/main.tf, agents_vm).
  boot.kernelModules = ["kvm-amd"];

  microvm.vms = lib.mapAttrs (name: zone: {config = guest name zone;}) zones;

  # Per-zone secrets, decrypted on this host and handed to the guest as
  # systemd credentials. qemu reads them, and it runs as `microvm`.
  age.secrets = lib.mkMerge (lib.mapAttrsToList (name: _: {
      "multica-token-${name}" = {
        file = ../../secrets/multica-token-${name}.age;
        owner = "microvm";
        mode = "0400";
      };
      "multica-zone-${name}-env" = {
        file = ../../secrets/multica-zone-${name}-env.age;
        owner = "microvm";
        mode = "0400";
      };
    })
    zones);

  systemd.services = lib.mkMerge (lib.mapAttrsToList (name: zone: {
      # Credentials are read at VM start, so a rotated secret needs a restart.
      "microvm@${name}".restartTriggers = [
        config.age.secrets."multica-token-${name}".file
        config.age.secrets."multica-zone-${name}-env".file
      ];

      # Host end of the zone's tap: 10.42.0.1/32 plus a host route to the
      # guest. Runs after microvm.nix creates the tap, and again whenever the
      # VM (and so the tap) restarts.
      "microvm-net-${name}" = {
        description = "Address and route for the ${name} zone's tap";
        after = ["microvm-tap-interfaces@${name}.service"];
        requires = ["microvm-tap-interfaces@${name}.service"];
        before = ["microvm@${name}.service"];
        requiredBy = ["microvm@${name}.service"];
        partOf = ["microvm@${name}.service"];
        path = [pkgs.iproute2];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ip link set ${tap name} up
          ip addr replace ${hostAddr}/32 dev ${tap name}
          ip route replace ${guestAddr zone}/32 dev ${tap name}
        '';
      };
    })
    zones);

  # Zones reach the LAN and the internet through NAT on ens18. Per-zone egress
  # allowlists (Sandboxing.md, "Network egress per zone") are not in place yet;
  # for now zones only can't reach each other.
  networking.nat = {
    enable = true;
    internalIPs = ["10.42.0.0/24"];
    externalInterface = "ens18";
  };
  networking.firewall.extraCommands = ''
    iptables -C FORWARD -s 10.42.0.0/24 -d 10.42.0.0/24 -j DROP 2>/dev/null \
      || iptables -I FORWARD -s 10.42.0.0/24 -d 10.42.0.0/24 -j DROP
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D FORWARD -s 10.42.0.0/24 -d 10.42.0.0/24 -j DROP || true
  '';
}
