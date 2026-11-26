{
  config,
  inputs,
  lib,
  options,
  pkgs,
  ...
}: let
  cfg = config.wotan.agentVm;
  domains = import ./agent-domains.nix;
  inherit (import ./agent-vm-net.nix) hostAddr guestAddr tap;

  pkg = config.wotan.agentEgress.package;

  allowFor = vm: lib.concatMap (g: domains.groups.${g}.allow) vm.egress.groups;
  internalFor = vm: lib.concatMap (g: domains.groups.${g}.internal) vm.egress.groups;

  configFile = name: vm:
    (pkgs.formats.toml {}).generate "avm-egress-${name}.toml" {
      vm = name;
      listen = hostAddr;
      interface = tap name;
      allow = allowFor vm;
      internal = internalFor vm;
    };
in {
  options.wotan.agentEgress.package = lib.mkOption {
    type = lib.types.package;
    default = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.avm-egress;
    defaultText = lib.literalExpression "inputs.self.packages.\${system}.avm-egress";
    description = "The avm-egress package (rust/avm-egress).";
  };

  config = lib.mkIf (cfg != {}) ({
      # One plain instance-named unit per VM, no template: it keeps
      # `systemctl status avm-egress@home` working and makes a config change
      # restart only the daemon.
      systemd.services = lib.mapAttrs' (name: vm:
        lib.nameValuePair "avm-egress@${name}" {
          description = "Allowlist DNS and TLS SNI egress filter for the agent VM ${name}";
          # Started with the VM and before it, bound to the tap's lifetime (the
          # device binding dies with the tap, which is partOf microvm@). Not
          # requiredBy the VM: a restart must not restart the VM, and with the
          # daemon down the guest has no network, which is the safe state.
          wantedBy = ["microvm@${name}.service"];
          before = ["microvm@${name}.service"];
          after = ["microvm-net-${name}.service" "microvm-tap-interfaces@${name}.service"];
          bindsTo = ["microvm-tap-interfaces@${name}.service"];
          serviceConfig = {
            Type = "exec";
            ExecStart = "${pkg}/bin/avm-egress ${configFile name vm}";
            Restart = "on-failure";
            RestartSec = "2s";
            DynamicUser = true;
            AmbientCapabilities = ["CAP_NET_BIND_SERVICE"];
            CapabilityBoundingSet = ["CAP_NET_BIND_SERVICE"];
            NoNewPrivileges = true;
            RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectKernelLogs = true;
            ProtectControlGroups = true;
            ProtectClock = true;
            ProtectHostname = true;
            ProtectProc = "invisible";
            ProcSubset = "pid";
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            SystemCallArchitectures = "native";
            SystemCallFilter = ["@system-service" "~@privileged @resources"];
            UMask = "0077";
            # The daemon enforces R-NET-3 (no private addresses) itself; this
            # backs it up. Allow wins over deny in systemd.
            IPAddressDeny = [
              "10.0.0.0/8"
              "172.16.0.0/12"
              "192.168.0.0/16"
              "100.64.0.0/10"
              "169.254.0.0/16"
              "fc00::/7"
              "fe80::/10"
              "224.0.0.0/4"
              "ff00::/8"
            ];
            IPAddressAllow =
              ["127.0.0.0/8" "::1/128" "${guestAddr vm}/32"]
              ++ lib.concatMap (i: i.cidrs) (internalFor vm);
          };
        })
      cfg;
    }
    # The Loki shipper (modules/fluent-bit.nix) is imported by wotan's host
    # config, not here, so the agent-vm nixosTest needs no agenix. job is the
    # fluent-bit tag and cursor DB name, so it is unique per unit.
    // lib.optionalAttrs (options.services ? loki-logs) {
      services.loki-logs = {
        enable = true;
        units =
          map (name: {
            unit = "avm-egress@${name}.service";
            job = "avm-egress-${name}";
          })
          (lib.attrNames cfg);
      };
    });
}
