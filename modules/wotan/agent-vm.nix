{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.wotan.agentVm;

  hostAddr = "10.200.0.1";
  guestAddr = vm: "10.200.0.${toString vm.index}";
  tap = name: "avm-${name}";
  mac = vm: "02:00:00:c8:00:${lib.fixedWidthString 2 "0" (lib.toHexString vm.index)}";
  stateDir = name: "${config.microvm.stateDir}/${name}";
  # The guest's own `config` shadows the host's inside `guest`, so read what
  # it needs from the host here.
  hostStateVersion = config.system.stateVersion;
  hostTimeZone = config.time.timeZone;

  # -F skips ~/.ssh/config and /etc/ssh/ssh_config, whose `Host *`
  # settings would otherwise win over ours.
  avmSsh = pkgs.writeShellScriptBin "avm-ssh" ''
    exec ${pkgs.openssh}/bin/ssh -F /etc/avm/ssh_config "$@"
  '';

  guest = name: vm: {
    system.stateVersion = hostStateVersion;
    time.timeZone = hostTimeZone;

    microvm = {
      hypervisor = "qemu";
      inherit (vm) vcpu mem;

      interfaces = [
        {
          type = "tap";
          id = tap name;
          mac = mac vm;
        }
      ];

      # The guest's closure as a disk image of its own: sharing the host's
      # /nix/store would expose every path ever built on wotan. No shares at
      # all in this phase.
      storeOnDisk = true;
      shares = [];

      # Writable overlay so the agent can build. Its Nix database forgets
      # everything on reboot (microvm.nix docs, "Writable /nix/store
      # overlay"), so the image is deleted before every start and recreated
      # empty.
      writableStoreOverlay = "/nix/.rw-store";
      preStart = ''
        rm -f ${stateDir name}/nix-store-overlay.img
      '';

      volumes = [
        {
          image = "${stateDir name}/state.img";
          mountPoint = "/home/agent";
          size = vm.stateSize;
        }
        {
          image = "${stateDir name}/work.img";
          mountPoint = "/srv/work";
          size = vm.workSize;
        }
        {
          image = "${stateDir name}/nix-store-overlay.img";
          mountPoint = "/nix/.rw-store";
          size = vm.storeSize;
        }
      ];

      # Read by qemu (user microvm) at start and handed to the guest as a
      # systemd credential; the key never enters the Nix store.
      credentialFiles.ssh-host-key = vm.hostKeyFile;
    };

    # The root is a tmpfs (RAM), so builds go to the store overlay's disk.
    # `build` does not collide with the overlay's own `store` and `work`
    # subdirs.
    nix.settings = {
      build-dir = "/nix/.rw-store/build";
      experimental-features = ["nix-command" "flakes"];
      trusted-users = lib.mkForce ["root"];
    };

    # Routed, not bridged: one tap and one /32 per VM, and no default route,
    # so the guest reaches the host's address and nothing else.
    networking.useNetworkd = true;
    networking.useDHCP = false;
    systemd.network.networks."10-eth" = {
      matchConfig.MACAddress = mac vm;
      address = ["${guestAddr vm}/32"];
      routes = [
        {
          # Not GatewayOnLink (microvm.nix's docs): the kernel rejects onlink
          # on a route without a gateway.
          Destination = "${hostAddr}/32";
          Scope = "link";
        }
      ];
      linkConfig.RequiredForOnline = "no";
      networkConfig = {
        LinkLocalAddressing = "no";
        IPv6AcceptRA = false;
      };
    };
    systemd.network.wait-online.enable = false;
    services.resolved.enable = false;
    networking.firewall.enable = true;

    # No password, no keys for root; the only way in is the agent's SSH key.
    # The assertion that someone can log in counts root and wheel only.
    users.mutableUsers = false;
    users.allowNoPasswordLogin = true;
    users.users.root.hashedPassword = "!";
    users.users.agent = {
      isNormalUser = true;
      uid = 1000;
      home = "/home/agent";
      extraGroups = [];
      openssh.authorizedKeys.keys = [vm.clientPublicKey];
    };
    security.sudo.enable = false;
    security.polkit.enable = false;

    # Both are volume mountpoints, owned by root on first boot.
    systemd.tmpfiles.rules = [
      "d /home/agent 0700 agent users -"
      "d /srv/work 0755 agent users -"
      "d /nix/.rw-store/build 0755 root root -"
    ];

    services.openssh = {
      enable = true;
      openFirewall = true;
      hostKeys = [];
      # authorized_keys only from /etc (the Nix config), never ~/.ssh, so the
      # agent cannot add keys of its own.
      authorizedKeysInHomedir = false;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        AuthenticationMethods = "publickey";
        # Only wotan, whose address is the one the tap's route gives it.
        AllowUsers = ["agent@${hostAddr}"];
        AllowAgentForwarding = false;
        AllowTcpForwarding = false;
        AllowStreamLocalForwarding = false;
        X11Forwarding = false;
        PermitTunnel = false;
      };
      extraConfig = ''
        HostKey /run/credentials/@system/ssh-host-key
      '';
    };

    environment.systemPackages = [pkgs.git pkgs.ripgrep];
    documentation.enable = false;
  };

  vmOptions = {
    options = {
      index = lib.mkOption {
        type = lib.types.ints.between 2 254;
        description = ''
          Last octet of the guest's address (10.200.0.<index>) and of its MAC.
          Never reuse one, even after the VM is gone.
        '';
      };
      vcpu = lib.mkOption {
        type = lib.types.int;
        description = "Number of virtual CPUs.";
      };
      mem = lib.mkOption {
        type = lib.types.int;
        description = "Guest RAM in MiB.";
      };
      stateSize = lib.mkOption {
        type = lib.types.int;
        description = "Size of the /home/agent image in MiB.";
      };
      workSize = lib.mkOption {
        type = lib.types.int;
        description = "Size of the /srv/work image in MiB.";
      };
      storeSize = lib.mkOption {
        type = lib.types.int;
        description = "Size of the writable Nix store overlay image in MiB.";
      };
      hostKeyFile = lib.mkOption {
        type = lib.types.str;
        description = ''
          Path on the host of the guest's SSH host private key (ed25519),
          readable by the user microvm. A string, never a Nix path: the key
          must not enter the store.
        '';
      };
      hostPublicKey = lib.mkOption {
        type = lib.types.str;
        description = "The guest's SSH host public key (ssh-ed25519 AAAA...).";
      };
      clientPublicKey = lib.mkOption {
        type = lib.types.str;
        description = "The public key wotan's user logs in to the guest with.";
      };
    };
  };

  # inet, so IPv6 is dropped as well. Hooks run at -10, before the iptables
  # backend's chains at 0: an nft drop is final whichever backend runs, and
  # trustedInterfaces cannot override it.
  #
  # Established replies are accepted only for the pinned address pair.
  # conntrack matches a packet's 5-tuple without the interface, so an
  # unpinned `established` rule would let a guest inject packets into any of
  # wotan's other connections. `related` is left out on purpose.
  ruleset = pkgs.writeText "agent-vm.nft" ''
    table inet agent-vm {}
    delete table inet agent-vm
    table inet agent-vm {
      chain input {
        type filter hook input priority -10; policy accept;
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: vm: "    iifname \"${tap name}\" ip saddr ${guestAddr vm} ip daddr ${hostAddr} ct state established accept") cfg)}
        iifname "avm-*" drop
      }
      chain forward {
        type filter hook forward priority -10; policy accept;
        iifname "avm-*" drop
        oifname "avm-*" drop
      }
    }
  '';

  assertsFor = name: vm: let
    guestCfg = config.microvm.vms.${name}.config.config;
  in [
    {
      assertion = lib.stringLength (tap name) <= 15;
      message = "wotan.agentVm.${name}: tap name ${tap name} is longer than 15 characters";
    }
    {
      assertion = guestCfg.microvm.shares == [];
      message = "wotan.agentVm.${name}: the guest must not have microvm.shares";
    }
    {
      assertion = guestCfg.microvm.storeOnDisk;
      message = "wotan.agentVm.${name}: the guest must use its own store disk (microvm.storeOnDisk)";
    }
  ];

  indexes = lib.mapAttrsToList (_: vm: vm.index) cfg;
  totalMiB = lib.foldl' (acc: vm: acc + vm.stateSize + vm.workSize + vm.storeSize) 0 (lib.attrValues cfg);
in {
  imports = [inputs.microvm.nixosModules.host];

  options.wotan.agentVm = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule vmOptions);
    default = {};
    description = ''
      MicroVMs for coding agents. Each attribute is one VM: the guest is
      reachable by SSH from this host only, shares nothing with it and has no
      other network.
    '';
  };

  config = lib.mkMerge [
    {microvm.host.enable = cfg != {};}

    (lib.mkIf (cfg != {}) {
      microvm.vms =
        lib.mapAttrs (name: vm: {
          autostart = false;
          restartIfChanged = false;
          config = guest name vm;
        })
        cfg;

      # What the microvm host module brings in that no VM here uses: the
      # cap_net_admin bridge helper (no VM has a bridge interface) and KSM
      # (memory dedup is a side channel between trust levels).
      security.wrappers.qemu-bridge-helper.enable = false;
      environment.etc."qemu/bridge.conf".text = "deny all\n";
      hardware.ksm.enable = false;

      networking.networkmanager.unmanaged = ["interface-name:avm-*"];

      assertions =
        lib.concatLists (lib.mapAttrsToList assertsFor cfg)
        ++ [
          {
            assertion = lib.length (lib.unique indexes) == lib.length indexes;
            message = "wotan.agentVm: every VM needs a unique index";
          }
          {
            assertion = totalMiB < 120 * 1024;
            message = "wotan.agentVm: state, work and store images add up to ${toString totalMiB} MiB, the limit is ${toString (120 * 1024)}";
          }
          {
            assertion = !(lib.any (lib.hasPrefix "avm-") config.networking.firewall.trustedInterfaces);
            message = "networking.firewall.trustedInterfaces must not contain avm-* interfaces: it would open wotan to the agent VMs";
          }
        ];

      systemd.services =
        lib.mapAttrs' (name: vm:
          lib.nameValuePair "microvm-net-${name}" {
            description = "Address and route for the agent VM ${name}'s tap";
            after = ["microvm-tap-interfaces@${name}.service"];
            requires = ["microvm-tap-interfaces@${name}.service"];
            before = ["microvm@${name}.service"];
            requiredBy = ["microvm@${name}.service"];
            partOf = ["microvm@${name}.service"];
            # requiredBy microvm@: restarting this unit would restart the VM.
            restartIfChanged = false;
            path = [pkgs.iproute2];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            # IPv6 off first, so the tap never gets a link-local address.
            script = ''
              if [ -e /proc/sys/net/ipv6/conf/${tap name}/disable_ipv6 ]; then
                echo 1 > /proc/sys/net/ipv6/conf/${tap name}/disable_ipv6
              fi
              ip link set ${tap name} up
              ip addr replace ${hostAddr}/32 dev ${tap name}
              ip route replace ${guestAddr vm}/32 dev ${tap name} src ${hostAddr}
            '';
          })
        cfg
        // {
          # Own nft table, loaded atomically before any tap exists. No
          # ExecStop: the rules stay when the unit stops (fail closed).
          # Reload, never restart, on change: it is requiredBy the taps, so a
          # restart would take the VMs down.
          agent-vm-firewall = {
            description = "Firewall for the agent VM taps";
            wantedBy = ["multi-user.target"];
            before = map (name: "microvm-tap-interfaces@${name}.service") (lib.attrNames cfg);
            requiredBy = map (name: "microvm-tap-interfaces@${name}.service") (lib.attrNames cfg);
            reloadIfChanged = true;
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${pkgs.nftables}/bin/nft -f ${ruleset}";
              ExecReload = "${pkgs.nftables}/bin/nft -f ${ruleset}";
            };
          };
        };

      # ssh looks only at the first value of each setting, so the per-VM
      # blocks come first and `Host *` pins everything else.
      environment.etc."avm/ssh_config".text =
        lib.concatStrings (lib.mapAttrsToList (name: vm: ''
            Host avm-${name}
              HostName ${guestAddr vm}
              User agent
              HostKeyAlias avm-${name}

          '')
          cfg)
        + ''
          Host *
            IdentityFile ~/.ssh/id_agent_vm
            IdentitiesOnly yes
            IdentityAgent none
            StrictHostKeyChecking yes
            UserKnownHostsFile /dev/null
            GlobalKnownHostsFile /etc/avm/known_hosts
            UpdateHostKeys no
            HostKeyAlgorithms ssh-ed25519
            PreferredAuthentications publickey
            ForwardAgent no
            ForwardX11 no
            PermitLocalCommand no
            ControlMaster no
            ControlPath none
            Tunnel no
            ConnectTimeout 5
        '';
      environment.etc."avm/known_hosts".text =
        lib.concatStrings (lib.mapAttrsToList (name: vm: "avm-${name} ${vm.hostPublicKey}\n") cfg);

      # The repo-to-VM mapping stays in the user's ~/.config/avm/repos, not
      # here: infra/ is public and business repo names must not land in it.
      environment.systemPackages = [
        avmSsh
        (pkgs.callPackage ./avm/package.nix {inherit avmSsh;})
      ];
    })
  ];
}
