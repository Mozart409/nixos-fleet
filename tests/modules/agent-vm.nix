# nixosTest for modules/wotan/agent-vm.nix: the microVM for coding agents is
# reachable from the host over SSH only, shows the guest nothing of the host
# (no virtiofs/9p, read-only erofs store), gives the agent no privileges, and
# the host's nft table keeps the guest away from the host and the LAN even
# with forwarding on. Every probe has a positive control.
# `nix build .#nixosTests.x86_64-linux.agent-vm`
{
  pkgs,
  microvm,
}: let
  snakeoil = import "${pkgs.path}/nixos/tests/ssh-keys.nix" pkgs;

  # Plain HTTP listener on all addresses: the target of the network probes.
  listener = {
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 -m http.server 8080 --bind 0.0.0.0 --directory /var/empty";
      DynamicUser = true;
    };
  };
in
  pkgs.testers.runNixOSTest {
    name = "agent-vm";

    # The module imports inputs.microvm.nixosModules.host itself.
    node.specialArgs.inputs = {inherit microvm;};

    nodes.machine = {...}: {
      imports = [../../modules/wotan/agent-vm.nix];

      users.users.amadeus.isNormalUser = true;

      # Nested KVM: the guest runs in qemu inside this test VM.
      virtualisation = {
        memorySize = 4096;
        cores = 4;
        diskSize = 8192;
        qemu.options = ["-cpu host"];
      };

      # Forwarding is on, so only the module's rules can stop the guest.
      boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

      systemd.services.listener = listener;
      networking.firewall.allowedTCPPorts = [8080];
      environment.systemPackages = [pkgs.nftables];

      # Host key readable by the microvm user, client key as on wotan.
      environment.etc."avm-test/ssh-host-key" = {
        source = snakeoil.snakeOilEd25519PrivateKey;
        user = "microvm";
        mode = "0400";
      };
      systemd.tmpfiles.rules = [
        "d /home/amadeus/.ssh 0700 amadeus users -"
        "C+ /home/amadeus/.ssh/id_agent_vm 0600 amadeus users - ${snakeoil.snakeOilPrivateKey}"
      ];

      wotan.agentVm.home = {
        index = 2;
        vcpu = 2;
        mem = 1024;
        stateSize = 256;
        workSize = 256;
        storeSize = 1024;
        hostKeyFile = "/etc/avm-test/ssh-host-key";
        hostPublicKey = snakeoil.snakeOilEd25519PublicKey;
        clientPublicKey = snakeoil.snakeOilPublicKey;
      };

      # A second definition, merged with the module's: root may log in with
      # the client key, so the probes can run privileged inside the guest.
      microvm.vms.home.config = {
        lib,
        pkgs,
        ...
      }: {
        services.openssh.settings = {
          PermitRootLogin = lib.mkForce "prohibit-password";
          AllowUsers = lib.mkForce ["agent@10.200.0.1" "root@10.200.0.1"];
        };
        users.users.root.openssh.authorizedKeys.keys = [snakeoil.snakeOilPublicKey];
        environment.systemPackages = [pkgs.curl pkgs.iproute2];
      };
    };

    # Another host on the LAN, with a route back to the guest network so a
    # blocked connection is the filter and not a missing return path.
    nodes.lan = {nodes, ...}: {
      systemd.services.listener = listener;
      networking.firewall.allowedTCPPorts = [8080];
      networking.interfaces.eth1.ipv4.routes = [
        {
          address = "10.200.0.0";
          prefixLength = 24;
          via = nodes.machine.networking.primaryIPAddress;
        }
      ];
    };

    testScript = {nodes, ...}: let
      guestConfig = nodes.machine.microvm.vms.home.config.config;
      # What the store image must hold: the guest toplevel, microvm's
      # registration info and their closure, nothing else.
      closure = pkgs.closureInfo {
        rootPaths = [
          guestConfig.system.build.toplevel
          guestConfig.microvm.storeDisk.passthru.regInfo
        ];
      };
    in ''
      import os
      import shlex

      machine_ip = "${nodes.machine.networking.primaryIPAddress}"
      lan_ip = "${nodes.lan.networking.primaryIPAddress}"

      def owner(cmd):
          return machine.succeed(f"su - amadeus -c {shlex.quote(cmd)}").strip()

      # Commands in the guest, over the same path the agent tooling uses.
      def guest(user, cmd):
          opts = "-o BatchMode=yes -o ConnectTimeout=10"
          return owner(f"avm-ssh {opts} -l {user} avm-home {shlex.quote(cmd)}")

      def agent(cmd):
          return guest("agent", cmd)

      def root(cmd):
          return guest("root", cmd)

      def agent_ok(cmd):
          return agent(f"{cmd} >/dev/null 2>&1 && echo yes || echo no") == "yes"

      def root_ok(cmd):
          return root(f"{cmd} >/dev/null 2>&1 && echo yes || echo no") == "yes"

      def wait_for_guest():
          machine.wait_until_succeeds(
              "su - amadeus -c 'avm-ssh -o BatchMode=yes -o ConnectTimeout=5 avm-home true'",
              timeout=600,
          )

      start_all()
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("listener.service")
      lan.wait_for_unit("listener.service")

      with subtest("the VM does not start by itself and is not restarted on switch"):
          machine.require_unit_state("microvm@home.service", "inactive")
          machine.wait_for_unit("agent-vm-firewall.service")
          machine.succeed("systemctl cat microvm@home.service | grep -qx 'X-RestartIfChanged=false'")
          machine.succeed("systemctl cat microvm-net-home.service | grep -qx 'X-RestartIfChanged=false'")

      with subtest("starting it brings up a guest the owner can reach over SSH"):
          machine.succeed("systemctl start microvm@home.service")
          wait_for_guest()
          assert agent("id -un") == "agent"

      with subtest("T-ISO-3: qemu runs as the microvm user"):
          procs = machine.succeed("ps -eo user=,args= | grep '[q]emu-system'").splitlines()
          assert procs, "no qemu process"
          assert all(p.split()[0] == "microvm" for p in procs), procs

      with subtest("T-ISO-2: no host filesystem shared in, store is a read-only erofs"):
          mounts = [line.split() for line in root("cat /proc/mounts").splitlines()]
          assert not [m for m in mounts if m[2] in ("virtiofs", "9p")], mounts
          # Positive control: the volumes and the store are in the table.
          points = {m[1]: m for m in mounts}
          for volume in ["/home/agent", "/srv/work", "/nix/.rw-store"]:
              assert volume in points, volume
          ro = points["/nix/.ro-store"]
          assert ro[2] == "erofs" and "ro" in ro[3].split(","), ro
          expected = sorted(os.path.basename(p) for p in machine.succeed("cat ${closure}/store-paths").split())
          assert sorted(root("ls -A /nix/.ro-store").split()) == expected

      with subtest("T-ISO-5: the owner's ssh config cannot loosen the client"):
          owner('mkdir -p ~/.ssh && printf "Host *\\n  ForwardAgent yes\\n  ForwardX11 yes\\n  PermitLocalCommand yes\\n  LocalCommand true\\n  StrictHostKeyChecking no\\n" > ~/.ssh/config && chmod 0600 ~/.ssh/config')
          # Positive control: that config would turn the options on.
          loose = owner("ssh -F ~/.ssh/config -G avm-home").splitlines()
          assert "forwardagent yes" in loose and "forwardx11 yes" in loose
          tight = owner("ssh -F /etc/avm/ssh_config -G avm-home").splitlines()
          for line in ["forwardagent no", "forwardx11 no", "permitlocalcommand no", "stricthostkeychecking true"]:
              assert line in tight, (line, tight)
          # A different host key for avm-home is refused, not accepted.
          owner('ssh-keygen -q -t ed25519 -N "" -f ~/other')
          owner('echo "avm-home $(cut -d" " -f1,2 ~/other.pub)" > ~/other_known_hosts')
          owner("sed 's|^\\(\\s*GlobalKnownHostsFile\\).*|\\1 /home/amadeus/other_known_hosts|I' /etc/avm/ssh_config > ~/cfg-other-host")
          owner("grep -q other_known_hosts ~/cfg-other-host")
          out = owner("ssh -F ~/cfg-other-host -o BatchMode=yes avm-home true 2>&1 || true")
          assert "REMOTE HOST IDENTIFICATION HAS CHANGED" in out or "Host key verification failed" in out, out

      with subtest("T-ISO-6: the agent has no privileges and cannot reach the host key"):
          assert agent("id -u") == "1000"
          assert "wheel" not in agent("id -nG")
          assert "rc=0" not in agent("sudo -n true 2>&1; echo rc=$?")
          trusted = agent("nix --extra-experimental-features nix-command config show trusted-users")
          assert "agent" not in trusted, trusted
          for path in [
              "/run/credentials/@system/ssh-host-key",
              "/sys/firmware/qemu_fw_cfg/by_name/opt/io.systemd.credentials/ssh-host-key/raw",
          ]:
              assert not agent_ok(f"cat {path}"), path
              # Positive control: root reads both, so they exist.
              assert root_ok(f"cat {path}"), path

      with subtest("T-ISO-6: authorized_keys in the agent's home grants nothing"):
          pub = owner("cat ~/other.pub")
          agent(f"mkdir -p ~/.ssh && echo {shlex.quote(pub)} >> ~/.ssh/authorized_keys && chmod 0600 ~/.ssh/authorized_keys")
          assert agent("grep -c ssh-ed25519 ~/.ssh/authorized_keys") == "1"
          # A config without the module's IdentityFile, so only -i is offered.
          owner("grep -vi IdentityFile /etc/avm/ssh_config > ~/cfg-no-key")
          try_key = "ssh -F ~/cfg-no-key -o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=10 -i {key} avm-home id -un 2>&1 || true"
          assert owner(try_key.format(key="~/.ssh/id_agent_vm")) == "agent"
          assert "Permission denied" in owner(try_key.format(key="~/other"))

      with subtest("T-ISO-4/T-NET-1: no route out, and the filter holds with one"):
          assert not [l for l in root("ip route").splitlines() if l.startswith("default")]
          dev = root("ip -4 -o route show to 10.200.0.0/24").split()[2]
          targets = {"host (tap end)": "10.200.0.1", "host (LAN address)": machine_ip, "lan": lan_ip}

          def reachable():
              return {
                  name: root_ok(f"curl -s --max-time 3 -o /dev/null http://{ip}:8080/")
                  for name, ip in targets.items()
              }

          # The listeners really are up for anyone who gets through.
          machine.succeed(f"curl -s --max-time 3 -o /dev/null http://{lan_ip}:8080/")
          lan.succeed("ip route get 10.200.0.2 | grep -q 'via ${nodes.machine.networking.primaryIPAddress}'")
          assert reachable() == dict.fromkeys(targets, False)

          root(f"ip route add default via 10.200.0.1 dev {dev} onlink")
          assert reachable() == dict.fromkeys(targets, False)

          # Positive control: without the table the same default route works.
          machine.succeed("nft delete table inet agent-vm")
          assert reachable() == dict.fromkeys(targets, True)

          machine.succeed("systemctl reload agent-vm-firewall.service")
          machine.succeed("nft list table inet agent-vm")
          assert reachable() == dict.fromkeys(targets, False)
          root(f"ip route del default dev {dev}")

          machine.succeed("ip link show avm-home")
          assert machine.succeed("ip -6 addr show dev avm-home").strip() == ""

      with subtest("the owner still reaches the guest"):
          assert owner("avm-ssh avm-home id -un") == "agent"

      with subtest("state and work survive a restart, the store overlay does not"):
          agent("echo kept > ~/keep && echo kept > /srv/work/keep")
          root("echo gone > /nix/.rw-store/gone")
          assert root_ok("test -e /nix/.rw-store/gone")
          machine.succeed("systemctl restart microvm@home.service")
          wait_for_guest()
          assert agent("cat ~/keep /srv/work/keep") == "kept\nkept"
          assert not root_ok("test -e /nix/.rw-store/gone")
    '';
  }
