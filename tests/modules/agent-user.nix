# nixosTest for modules/wotan/agent-user.nix and the agent side of
# opencode-serve.nix: the agent account sees only ~/code of the owner's home,
# gets its credentials, shares files with the owner through the ACLs, can use
# the signing agent but not read its key, and the owner can sudo to nothing
# but agent-run. `nix build .#nixosTests.x86_64-linux.agent-user`
{pkgs}: let
  # Stand-ins for the harnesses. `claude` runs its arguments, so the test can
  # probe the sandbox from inside an agent-run session.
  fakeClaude = pkgs.writeShellScriptBin "claude" ''exec "$@"'';
  # `opencode serve` records what the server's sandbox shows, then idles.
  fakeOpencode = pkgs.writeShellScriptBin "opencode" ''
    { id -un; ls -A /home/amadeus; } > "$HOME/serve-probe"
    exec sleep infinity
  '';
in
  pkgs.testers.runNixOSTest {
    name = "agent-user";

    nodes.machine = {
      imports = [
        ../../modules/wotan/agent-user.nix
        ../../modules/wotan/opencode-serve.nix
      ];

      users.users.amadeus.isNormalUser = true;
      environment.systemPackages = [fakeClaude pkgs.util-linux];
      environment.etc."agent-test-cred" = {
        text = "TEST_TOKEN=s3cret\n";
        mode = "0400";
      };

      # The bot signing key exists before the signing agents start, as on wotan.
      systemd.services.test-signing-key = {
        requiredBy = ["opencode-signing-agent.service" "claude-signing-agent.service"];
        before = ["opencode-signing-agent.service" "claude-signing-agent.service"];
        serviceConfig.Type = "oneshot";
        script = ''
          install -d -o amadeus -g users -m 0700 /home/amadeus/.ssh
          ${pkgs.util-linux}/bin/runuser -u amadeus -- \
            ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -f /home/amadeus/.ssh/id_ed25519_signing
        '';
      };

      wotan.agentUser = {
        enable = true;
        owner = "amadeus";
        credentials.test = "/etc/agent-test-cred";
      };

      services.opencode-serve = {
        enable = true;
        package = fakeOpencode;
        user = "agent";
        group = "agent";
        homeBindPaths = ["/home/amadeus/code" "/home/agent"];
        readWritePaths = ["/home/amadeus/code" "/home/agent"];
        signing = {
          keyFile = "/home/amadeus/.ssh/id_ed25519_signing";
          publicKey = "ssh-ed25519 unused";
          agents = ["opencode" "claude"];
        };
      };
    };

    testScript = ''
      import shlex

      def owner(cmd, check=True):
          full = f"su - amadeus -c {shlex.quote(cmd)}"
          return (machine.succeed if check else machine.fail)(full)

      # agent-run needs a terminal (systemd-run --pty); script(1) gives it one.
      def agent_cmd(cmd, cwd="/home/amadeus/code"):
          inner = f"sudo /run/current-system/sw/bin/agent-run claude {cmd}"
          return f"cd {cwd} && script -qec {shlex.quote(inner)} /dev/null"

      def agent(cmd, cwd="/home/amadeus/code"):
          return owner(agent_cmd(cmd, cwd)).replace("\r", "").strip()

      def agent_fails(cmd, cwd="/home/amadeus/code"):
          owner(agent_cmd(cmd, cwd), check=False)

      machine.wait_for_unit("multi-user.target")

      with subtest("owner's home: ~/code plus private files"):
          owner("mkdir -p ~/code ~/.config ~/.ssh && chmod 0755 ~/.config && chmod 0700 ~/.ssh")
          owner("echo leak > ~/.config/leak && chmod 0644 ~/.config/leak")
          # The ACL rule is applied by tmpfiles, as at boot.
          machine.succeed("systemd-tmpfiles --create --prefix=/home/amadeus/code")
          owner("echo owner > ~/code/from-owner")

      with subtest("runs as agent, without sudo"):
          assert agent("id -un") == "agent"
          assert "wheel" not in agent("id -nG")
          agent_fails("sudo -n true")

      with subtest("only ~/code of the owner's home is visible"):
          assert agent("ls -A /home/amadeus") == "code"
          agent_fails("cat /home/amadeus/.config/leak")
          assert agent("sh -c 'ls -A /run/user 2>/dev/null; true'") == ""
          # The real home is still closed by permissions outside the namespace.
          machine.fail("runuser -u agent -- cat /home/amadeus/.config/leak")

      with subtest("credentials reach the session"):
          assert agent("printenv TEST_TOKEN") == "s3cret"

      with subtest("both users can write each other's files in ~/code"):
          agent("sh -c 'echo agent >> /home/amadeus/code/from-owner'")
          agent("sh -c 'echo agent > /home/amadeus/code/from-agent'")
          agent("mkdir /home/amadeus/code/dir-agent")
          owner("echo owner >> ~/code/from-agent")
          owner("touch ~/code/dir-agent/file")
          machine.succeed("grep -qx agent /home/amadeus/code/from-owner")

      with subtest("agent-run refuses other programs and directories"):
          owner("script -qec 'sudo -n /run/current-system/sw/bin/agent-run bash -c true' /dev/null", check=False)
          agent_fails("true", cwd="/home/amadeus")
          agent_fails("true", cwd="/tmp")
          owner("sudo -n true", check=False)
          owner("sudo -n -u agent true", check=False)

      with subtest("signing agents: one per harness, usable, key unreadable"):
          pub = machine.succeed("cut -d' ' -f2 /home/amadeus/.ssh/id_ed25519_signing.pub").strip()
          for name in ["opencode", "claude"]:
              machine.wait_for_unit(f"{name}-signing-agent.service")
              sock = f"/run/{name}-signing/agent.sock"
              machine.wait_until_succeeds(
                  f"runuser -u agent -- env SSH_AUTH_SOCK={sock} ssh-add -L | grep -q {pub}"
              )
              keys = agent(f"env SSH_AUTH_SOCK={sock} ssh-add -L")
              assert pub in keys, keys
              agent_fails(f"ls /run/credentials/{name}-signing-agent.service")
          agent_fails("cat /home/amadeus/.ssh/id_ed25519_signing")
          # Other users cannot use them.
          machine.fail("runuser -u amadeus -- env SSH_AUTH_SOCK=/run/claude-signing/agent.sock ssh-add -L")

      with subtest("opencode-serve runs as agent in the same confinement"):
          machine.wait_for_unit("opencode-serve.service")
          machine.wait_for_file("/home/agent/serve-probe")
          assert machine.succeed("cat /home/agent/serve-probe").split() == ["agent", "code"]
    '';
  }
