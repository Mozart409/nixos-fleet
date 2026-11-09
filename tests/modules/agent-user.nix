# nixosTest for modules/wotan/agent-user.nix and the agent side of
# opencode-serve.nix: the agent account sees only ~/code of the owner's home,
# gets its credentials, shares files with the owner through the ACLs, can use
# the signing agent but not read its key, and the owner can sudo to nothing
# but agent-run. `nix build .#nixosTests.x86_64-linux.agent-user`
{pkgs}: let
  # Stand-ins for the harnesses. `claude` runs its arguments, so the test can
  # probe the sandbox from inside an agent-run session.
  fakeClaude = pkgs.writeShellScriptBin "claude" ''exec "$@"'';
  # autolith prints what agent-run gives it; claude (which runs its arguments)
  # must not see the autolith signing environment.
  fakeAutolith = pkgs.writeShellScriptBin "autolith" ''
    echo "user=$(id -un)"
    echo "sign=''${SSH_AUTH_SOCK:-none}"
    echo "signkey=''${GIT_CONFIG_VALUE_0:-none}"
    echo "sign-on=''${GIT_CONFIG_VALUE_2:-none}"
    echo "mcp-axon=''${AUTOLITH_MCP_AXON:-unset}"
  '';
  # Run through opencode's $SHELL (the bubblewrap wrapper): one labelled
  # `name=value` line per check, so a failing command does not stop the rest.
  # $1 tags the files it writes.
  shellProbe = pkgs.writeShellScript "shell-probe" ''
    tag="$1"
    if echo wrapped > "/home/amadeus/code/probe-$tag" 2>/dev/null; then echo code-write=ok; else echo code-write=fail; fi
    if echo wrapped > "/tmp/probe-$tag" 2>/dev/null; then echo tmp-write=ok; else echo tmp-write=fail; fi
    if echo wrapped > "/home/agent/.cache/probe-$tag" 2>/dev/null; then echo cache-write=ok; else echo cache-write=fail; fi
    if echo wrapped > "/home/agent/probe-$tag" 2>/dev/null; then echo home-write=ok; else echo home-write=fail; fi
    echo "ssh-cat=$(${pkgs.coreutils}/bin/cat /home/agent/.ssh/id_probe 2>&1 || true)"
    echo "auth-cat=$(${pkgs.coreutils}/bin/cat /home/agent/.local/share/opencode/auth.json 2>&1 || true)"
    echo "sign-keys=$(SSH_AUTH_SOCK=/run/opencode-signing/agent.sock ${pkgs.openssh}/bin/ssh-add -L 2>&1 || true)"
    if ${pkgs.nix}/bin/nix-store -q --hash /run/current-system >/dev/null 2>&1; then echo nix-daemon=ok; else echo nix-daemon=fail; fi
    echo "cargo-home=$CARGO_HOME"
    echo "cred=$(${pkgs.coreutils}/bin/cat "''${CREDENTIALS_DIRECTORY:-/nonexistent}"/test 2>&1 || true)"
  '';
  # `opencode serve` records what the server's sandbox shows, then idles; once
  # ~/run-shell-probe exists (~/code is only set up later by the test) it also
  # runs the probe through $SHELL. Any other call runs in an agent-run session
  # and prints what that session gets; `shell-probe` runs its arguments through
  # $SHELL, as opencode's shell tool does.
  fakeOpencode = pkgs.writeShellScriptBin "opencode" ''
    if [ "''${1:-}" = serve ]; then
      { id -un; ls -A /home/amadeus; } > "$HOME/serve-probe"
      (
        while [ ! -e "$HOME/run-shell-probe" ]; do sleep 1; done
        "$SHELL" -c "${shellProbe} serve" > "$HOME/serve-shell-probe.tmp" 2>&1
        mv "$HOME/serve-shell-probe.tmp" "$HOME/serve-shell-probe"
      ) &
      exec sleep infinity
    fi
    if [ "''${1:-}" = shell-probe ]; then
      shift
      exec "$SHELL" -c "$*"
    fi
    echo "user=$(id -un) password=''${OPENCODE_SERVER_PASSWORD:-none}"
    # InaccessiblePaths leaves an unreadable file in place, so test for -r.
    [ -r "$HOME/.claude/.credentials.json" ] && echo claude-login-visible
    exit 0
  '';
in
  pkgs.testers.runNixOSTest {
    name = "agent-user";

    nodes.machine = {config, ...}: {
      imports = [
        ../../modules/wotan/agent-user.nix
        ../../modules/wotan/opencode-serve.nix
      ];

      users.users.amadeus.isNormalUser = true;
      environment.systemPackages = [fakeAutolith fakeClaude fakeOpencode pkgs.util-linux];
      environment.etc."agent-test-cred" = {
        text = "TEST_TOKEN=s3cret\nAXON_GATEWAY_TOKEN=s3cret-tok\n";
        mode = "0400";
      };
      environment.etc."agent-test-server-password" = {
        text = "OPENCODE_SERVER_PASSWORD=serverpw\n";
        mode = "0400";
      };

      # The bot signing key exists before the signing agents start, as on wotan.
      systemd.services.test-signing-key = {
        requiredBy = ["opencode-signing-agent.service" "claude-signing-agent.service" "autolith-signing-agent.service"];
        before = ["opencode-signing-agent.service" "claude-signing-agent.service" "autolith-signing-agent.service"];
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
        serverPasswordFile = "/etc/agent-test-server-password";
      };

      services.opencode-serve = {
        enable = true;
        package = fakeOpencode;
        user = "agent";
        group = "agent";
        homeBindPaths = ["/home/amadeus/code" "/home/agent"];
        readWritePaths = ["/home/amadeus/code" "/home/agent"];
        shell = config.wotan.agentUser.opencodeShell;
        signing = {
          keyFile = "/home/amadeus/.ssh/id_ed25519_signing";
          publicKey = "ssh-ed25519 unused";
          agents = ["opencode" "claude" "autolith"];
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
          for name in ["opencode", "claude", "autolith"]:
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

      with subtest("the server password reaches only the opencode TUI"):
          machine.succeed("install -d -o agent -g agent /home/agent/.claude")
          machine.succeed("install -o agent -g agent -m 0600 /dev/null /home/agent/.claude/.credentials.json")
          def run(args):
              inner = f"sudo /run/current-system/sw/bin/agent-run {args}"
              return owner(f"cd /home/amadeus/code && script -qec {shlex.quote(inner)} /dev/null").replace("\r", "").strip()
          assert run("opencode --server http://127.0.0.1:4096") == "user=agent password=serverpw"
          assert run("opencode run hello") == "user=agent password=none"
          assert agent("sh -c 'echo ''${OPENCODE_SERVER_PASSWORD:-none}'") == "none"
          # Claude's login stays visible to claude sessions, not to opencode's.
          agent("test -r /home/agent/.claude/.credentials.json")

      with subtest("opencode's shell commands run in bubblewrap"):
          machine.succeed("install -d -o agent -g agent /home/agent/.ssh /home/agent/.local /home/agent/.local/share /home/agent/.local/share/opencode")
          machine.succeed("install -o agent -g agent -m 0600 /dev/null /home/agent/.ssh/id_probe")
          machine.succeed("install -o agent -g agent -m 0600 /dev/null /home/agent/.local/share/opencode/auth.json")
          machine.succeed("echo probe-secret | tee /home/agent/.ssh/id_probe /home/agent/.local/share/opencode/auth.json")
          machine.wait_for_unit("opencode-serve.service")
          machine.succeed("runuser -u agent -- touch /home/agent/run-shell-probe")
          machine.wait_for_file("/home/agent/serve-shell-probe")
          serve_out = machine.succeed("cat /home/agent/serve-shell-probe")
          run_out = run("opencode shell-probe ${shellProbe} run")

          def parse(out):
              return dict(l.split("=", 1) for l in out.splitlines() if "=" in l)

          for tag, out in [("run", run_out), ("serve", serve_out)]:
              res = parse(out)
              assert res.get("code-write") == "ok", (tag, out)
              machine.succeed(f"grep -qx wrapped /home/amadeus/code/probe-{tag}")
              assert res.get("tmp-write") == "ok", (tag, out)
              assert res.get("cache-write") == "ok", (tag, out)
              assert res.get("home-write") == "fail", (tag, out)
              machine.fail(f"test -e /home/agent/probe-{tag}")
              assert "probe-secret" not in res.get("ssh-cat", "probe-secret"), (tag, out)
              assert "probe-secret" not in res.get("auth-cat", "probe-secret"), (tag, out)
              assert pub in res.get("sign-keys", ""), (tag, out)
              assert res.get("nix-daemon") == "ok", (tag, out)
              assert res.get("cargo-home") == "/home/agent/.cache/cargo", (tag, out)
          assert "s3cret" not in parse(run_out).get("cred", "s3cret"), run_out
          # The masks are per command: the real files are untouched.
          machine.succeed("grep -qx probe-secret /home/agent/.ssh/id_probe")
          machine.succeed("grep -qx probe-secret /home/agent/.local/share/opencode/auth.json")
          # Claude and pi sessions keep their own shell.
          assert "opencode-shell" not in agent("sh -c 'echo shell=$SHELL'")

      with subtest("autolith gets its own signing agent and gateway header"):
          out = parse(run("autolith"))
          assert out.get("user") == "agent", out
          assert out.get("sign") == "/run/autolith-signing/agent.sock", out
          assert out.get("sign-on") == "true", out
          assert out.get("signkey", "").startswith("key::ssh-ed25519"), out
          # The MCP header variable carries the whole value, not just the token.
          assert out.get("mcp-axon") == "Bearer s3cret-tok", out
          sock = "/run/autolith-signing/agent.sock"
          assert pub in agent(f"env SSH_AUTH_SOCK={sock} ssh-add -L")
          # claude keeps its own session: no autolith signing environment.
          assert agent("sh -c 'echo ''${GIT_CONFIG_COUNT:-none}'") == "none"

      with subtest("private networks are closed, loopback is open"):
          machine.succeed("systemd-run --unit=tcp-probe ${pkgs.socat}/bin/socat TCP-LISTEN:7777,fork,reuseaddr SYSTEM:true")
          machine.wait_for_open_port(7777)
          lan = machine.succeed("ip -4 -o addr show eth1 | awk '{print $4}' | cut -d/ -f1").strip()
          agent("bash -c 'exec 3<>/dev/tcp/127.0.0.1/7777'")
          agent_fails(f"bash -c 'exec 3<>/dev/tcp/{lan}/7777'")
          machine.succeed(f"runuser -u agent -- bash -c 'exec 3<>/dev/tcp/{lan}/7777'")
          assert "192.168.0.0/16" in machine.succeed("systemctl show -p IPAddressDeny opencode-serve.service")
    '';
  }
