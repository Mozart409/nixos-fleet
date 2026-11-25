{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.wotan.agentUser;

  # Every agent process (interactive claude/opencode via agent-run, and
  # opencode-serve) runs in a mount namespace where /home and /run/user are
  # empty tmpfs mounts and only these two paths are bound back in, at their
  # real paths. The separate uid keeps the agent out of the owner's processes
  # and sockets; the namespace keeps it out of world-readable files under the
  # owner's home (~/.config and ~/.local/share are 0755).
  bindPaths = [cfg.codeDir cfg.home];

  # agenix output (owner-only secrets are unreadable anyway; this also hides
  # the world-readable ones and their names), and the commit-signing key that
  # the signing agents, running as the agent, get as a credential.
  inaccessiblePaths =
    ["/run/agenix" "/run/agenix.d"]
    ++ config.services.opencode-serve.signing.credentials;

  # Private networks are closed except network.allow; the internet stays
  # open (the model APIs, flake inputs). systemd checks Allow before Deny, so
  # an allowed address inside a denied range gets through. Loopback is always
  # allowed: the local Unbound at 127.0.0.1 and opencode-serve live there.
  ipAllow = ["127.0.0.0/8" "::1/128"] ++ cfg.network.allow;
  ipDeny = cfg.network.deny;

  # agent-proxy: the domain filter for sandboxed commands, Claude Code's
  # (sandbox.network.httpProxyPort, modules/home/packages/claude.nix) and
  # opencode's (opencodeShell). tinyproxy listens on loopback; opencodeShell's
  # commands have no network of their own and reach it through proxySocket.
  proxyPort = toString cfg.network.proxyPort;
  proxyUrl = "http://127.0.0.1:${proxyPort}";
  proxySocket = "/run/agent-proxy/proxy.sock";
  # One fnmatch pattern per line, matched against the host name only.
  proxyFilter = pkgs.writeText "agent-proxy-filter" (lib.concatLines cfg.network.allowedDomains);

  # No ProtectKernelTunables/ProtectKernelLogs: they overmount parts of /proc,
  # and the kernel then refuses the fresh /proc that Claude Code's sandbox and
  # opencodeShell mount (bwrap: "Can't mount proc on /proc"). Without a fresh
  # /proc, sandboxed commands would read the harness's environment, gateway
  # tokens included, through the host /proc. The agent has no root, so /proc/sys
  # and /sys stay read-only to it anyway; kernel.dmesg_restrict (security.nix)
  # keeps the kernel log (dmesg, syslog(), /dev/kmsg) closed.
  sandboxProperties =
    [
      "ProtectHome=tmpfs"
      "PrivateTmp=yes"
      "NoNewPrivileges=yes"
      "RestrictSUIDSGID=yes"
      "ProtectSystem=strict"
      "ProtectKernelModules=yes"
      "ProtectControlGroups=yes"
      "ProtectClock=yes"
      "LockPersonality=yes"
      "IPAddressAllow=${lib.concatStringsSep " " ipAllow}"
      "IPAddressDeny=${lib.concatStringsSep " " ipDeny}"
    ]
    ++ map (p: "BindPaths=${p}") bindPaths
    ++ map (p: "ReadWritePaths=${p}") bindPaths
    ++ map (p: "InaccessiblePaths=-${p}") inaccessiblePaths;

  # Runs as the agent inside the unit: export the gateway tokens from the
  # unit's credentials, load the directory's direnv environment (the dev shell
  # is not inherited across sudo) and exec the harness from a login shell, so
  # PATH has the agent's home-manager profile.
  # ~/.local/bin only silences Claude's PATH check (it takes the Nix package for a
  # native install); last, because the agent can write there.
  inner = pkgs.writeShellScript "agent-run-inner" ''
    for cred in "''${CREDENTIALS_DIRECTORY:-/nonexistent}"/*; do
      [ -f "$cred" ] || continue
      set -a
      . "$cred"
      set +a
    done
    # Autolith's MCP registration (modules/home/packages/autolith.nix) maps
    # the full Authorization header value from AUTOLITH_MCP_AUTHORIZATION:
    # mcparen adds no "Bearer " prefix the way Claude Code's
    # managed-mcp.json or opencode's {env:VAR} templating does, so derive it
    # from the raw AXON_GATEWAY_TOKEN credential sourced above. Autolith
    # sessions only.
    if [ "''${1:-}" = autolith ] && [ -n "''${AXON_GATEWAY_TOKEN:-}" ]; then
      export AUTOLITH_MCP_AUTHORIZATION="Bearer ''${AXON_GATEWAY_TOKEN}"
    fi
    # Autolith sends telemetry by default.
    export AUTOLITH_TELEMETRY=off
    exec ${pkgs.bashInteractive}/bin/bash -l -c '
      eval "$(direnv export bash 2>/dev/null)"
      export PATH="$PATH:$HOME/.local/bin"
      exec "$@"
    ' agent-run "$@"
  '';

  # Home-directory secrets opencode's shell commands must not read; mirrors the
  # home-directory Read(...) denies in modules/claude-deny-core.nix.
  hiddenPaths = map (p: "${cfg.home}/${p}") [
    ".ssh"
    ".gnupg"
    ".claude/.credentials.json"
    ".local/share/opencode/auth.json"
    ".config/sops/age"
    ".config/age"
  ];

  # Runs inside opencodeShell's sandbox: the proxy forward, then the command.
  # The wait keeps the command from racing the listener.
  opencodeShellInner = pkgs.writeShellScript "opencode-shell-inner" ''
    ${pkgs.socat}/bin/socat TCP-LISTEN:${proxyPort},bind=127.0.0.1,fork,reuseaddr UNIX-CONNECT:${proxySocket} &
    for _ in {1..100}; do
      (: </dev/tcp/127.0.0.1/${proxyPort}) 2>/dev/null && break
      ${pkgs.coreutils}/bin/sleep 0.01
    done
    exec ${pkgs.bashInteractive}/bin/bash "$@"
  '';

  # opencode runs every shell command as `$SHELL -c`, so this is its SHELL. It
  # confines shell commands only: opencode's read/edit tools and MCP stay in
  # the server process. Writes are limited to codeDir, ~/.cache, ~/.cargo
  # (cargo's registry cache, shared with Claude's sandbox) and /tmp, and
  # the secret files above are masked. Commands get their own PID namespace
  # and a fresh /proc, so the server's environment (its gateway tokens) is not
  # readable through /proc. Only paths that exist are masked, as bwrap would
  # create the missing ones in the real filesystem. Commands also get their own
  # network namespace with only loopback: opencodeShellInner forwards
  # 127.0.0.1:proxyPort in there to agent-proxy, so they reach the network
  # only through its domain filter, via HTTP(S)_PROXY. The server itself stays
  # outside and keeps reaching its model provider.
  # The one non-confining step is the direnv load below: it puts shell
  # commands into the repo's dev shell, as agent-run-inner does for the
  # interactive harnesses.
  opencodeShell = pkgs.writeShellScript "opencode-shell" ''
    set -eu
    mask=()
    for p in ${lib.escapeShellArgs hiddenPaths}; do
      if [ -d "$p" ]; then
        mask+=(--tmpfs "$p")
      elif [ -e "$p" ]; then
        mask+=(--ro-bind /dev/null "$p")
      fi
    done
    if [ -n "''${CREDENTIALS_DIRECTORY:-}" ]; then
      mask+=(--tmpfs "$CREDENTIALS_DIRECTORY")
    fi
    ${pkgs.coreutils}/bin/mkdir -p ${cfg.home}/.cache ${cfg.home}/.cargo
    # The one non-confining thing the wrapper does. Shell commands run in
    # the server's (or session's) environment, which otherwise never sees a
    # repo's dev shell -- so the repo hooks (lefthook: cog, keep-sorted,
    # gitleaks, alejandra) fail from every opencode session, and the agent
    # ends up working around them with `nix develop -c`. Same expression as
    # agent-run-inner. nix-direnv caches the export under ~/.cache/direnv,
    # so after the first load per repo (or flake.lock change) this costs a
    # few ms per command. Fails open: a blocked, missing or broken direnv
    # environment leaves the base PATH. bwrap passes the environment
    # through, so the exports reach the command inside the sandbox.
    eval "$(direnv export bash 2>/dev/null)" || true
    exec ${pkgs.bubblewrap}/bin/bwrap \
      --ro-bind / / \
      --dev /dev \
      --unshare-pid \
      --unshare-net \
      --proc /proc \
      --bind ${cfg.codeDir} ${cfg.codeDir} \
      --bind ${cfg.home}/.cache ${cfg.home}/.cache \
      --bind ${cfg.home}/.cargo ${cfg.home}/.cargo \
      --bind /tmp /tmp \
      "''${mask[@]}" \
      --setenv HTTP_PROXY ${proxyUrl} \
      --setenv HTTPS_PROXY ${proxyUrl} \
      --setenv http_proxy ${proxyUrl} \
      --setenv https_proxy ${proxyUrl} \
      --die-with-parent \
      -- ${opencodeShellInner} "$@"
  '';

  credentialArgs =
    lib.mapAttrsToList (name: path: "--property=LoadCredential=${name}:${path}") cfg.credentials;

  # herdr's claude/opencode integrations report the agent's state over
  # $HERDR_SOCKET_PATH, which the sandboxed agent can neither see (/run/user is
  # hidden) nor should open: herdr's real socket also takes pane.send_keys and
  # friends, which would let the agent type into the owner's unsandboxed panes.
  # So agent-run gives each session its own socket, and socat runs this filter
  # per connection as the owner. Only the two report methods pass, with
  # pane_id pinned to the session's pane and extra top-level keys dropped;
  # everything else, non-JSON included, is dropped. Replies flow back.
  # Env from agent-run: HERDR_FILTER_PANE, HERDR_FILTER_SOCKET (the real one).
  herdrFilter = pkgs.writeShellScript "herdr-filter" ''
    while IFS= read -r line; do
      printf '%s\n' "$line" | ${pkgs.jq}/bin/jq -c --arg pane "$HERDR_FILTER_PANE" '
        select(
          type == "object"
          and (.method == "pane.report_agent_session" or .method == "pane.report_agent")
          and (.params | type == "object")
        )
        | {id: .id, method: .method, params: (.params + {pane_id: $pane})}
      ' 2>/dev/null || true
    done | ${pkgs.socat}/bin/socat -t 1 - UNIX-CONNECT:"$HERDR_FILTER_SOCKET"
  '';

  # Root-owned launcher, the only command the owner may sudo to without a
  # password. Starts claude, opencode or autolith as the agent in a
  # transient unit with the sandbox above, in the caller's directory, which
  # must be under codeDir. Inside herdr it also runs the filtering socket
  # for the session (see herdrFilter) for the length of the run.
  agentRun = pkgs.writeShellScriptBin "agent-run" ''
    set -eu
    case "''${1:-}" in
      claude | opencode | autolith) ;;
      *)
        echo "usage: agent-run claude|opencode|autolith [args...]" >&2
        exit 64
        ;;
    esac
    dir="$(${pkgs.coreutils}/bin/realpath -e .)"
    case "$dir/" in
      ${cfg.codeDir}/*) ;;
      *)
        echo "agent-run: $dir is outside ${cfg.codeDir}" >&2
        exit 1
        ;;
    esac
    # opencode can't see Claude's login, as opencode-serve can't; only its TUI
    # client gets the server password.
    extra=()
    if [ "$1" = opencode ]; then
      extra+=(--property=InaccessiblePaths=-${cfg.home}/.claude/.credentials.json)
      extra+=(--setenv=SHELL=${opencodeShell})
      ${lib.optionalString (cfg.serverPasswordFile != null) ''
      if [ "''${2:-}" = --server ]; then
        extra+=(--property=LoadCredential=opencode-server-password:${cfg.serverPasswordFile})
      fi
    ''}
    fi
    # Its detached world server outlives the client and takes 60 s+ to die on SIGTERM.
    [ "$1" != autolith ] || extra+=(--property=TimeoutStopSec=5s)
    # Only for a real herdr pane whose socket is the owner's, so a forged
    # HERDR_SOCKET_PATH cannot make the root-run proxy connect elsewhere. The
    # dir is 0711 so the agent can reach the socket (mktemp makes it 0700).
    herdr_dir=""
    herdr_pid=""
    cleanup() {
      if [ -n "$herdr_pid" ]; then
        kill "$herdr_pid" 2>/dev/null || true
      fi
      if [ -n "$herdr_dir" ]; then
        ${pkgs.coreutils}/bin/rm -rf "$herdr_dir"
      fi
    }
    trap cleanup EXIT
    trap 'exit 1' INT TERM HUP
    if [ "''${HERDR_ENV:-}" = 1 ] && [ -n "''${HERDR_PANE_ID:-}" ] && [ -n "''${HERDR_SOCKET_PATH:-}" ] \
      && [ -S "$HERDR_SOCKET_PATH" ] \
      && [ "$(${pkgs.coreutils}/bin/stat -c %U "$HERDR_SOCKET_PATH")" = ${cfg.owner} ]; then
      herdr_dir="$(${pkgs.coreutils}/bin/mktemp -d /run/agent-herdr/XXXXXXXX)"
      ${pkgs.coreutils}/bin/chmod 711 "$herdr_dir"
      HERDR_FILTER_PANE="$HERDR_PANE_ID" HERDR_FILTER_SOCKET="$HERDR_SOCKET_PATH" \
        ${pkgs.socat}/bin/socat \
        "UNIX-LISTEN:$herdr_dir/herdr.sock,fork,unlink-early,max-children=4,user=${cfg.user},group=${cfg.user},mode=600" \
        EXEC:${herdrFilter},su=${cfg.owner} &
      herdr_pid=$!
      for _ in {1..100}; do
        [ -S "$herdr_dir/herdr.sock" ] && break
        ${pkgs.coreutils}/bin/sleep 0.01
      done
      extra+=(--setenv=HERDR_ENV=1)
      extra+=(--setenv=HERDR_PANE_ID="$HERDR_PANE_ID")
      extra+=(--setenv=HERDR_SOCKET_PATH="$herdr_dir/herdr.sock")
    fi
    rc=0
    ${config.systemd.package}/bin/systemd-run \
      --quiet --pty --wait --collect --service-type=exec \
      --uid=${cfg.user} --gid=${cfg.user} \
      --working-directory="$dir" \
      --setenv=TERM="''${TERM:-xterm-256color}" \
      ''${COLORTERM:+--setenv=COLORTERM="$COLORTERM"} \
      ${lib.escapeShellArgs (map (p: "--property=${p}") sandboxProperties ++ credentialArgs)} \
      "''${extra[@]}" \
      ${inner} "$@" || rc=$?
    exit "$rc"
  '';
in {
  options.wotan.agentUser = {
    enable = lib.mkEnableOption "a separate no-sudo account for the coding agents, confined to codeDir";

    user = lib.mkOption {
      type = lib.types.str;
      default = "agent";
      description = "The agents' account (also its group).";
    };

    home = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.user}";
      defaultText = lib.literalExpression ''"/home/''${config.wotan.agentUser.user}"'';
      description = "The agents' home: ~/.claude, ~/.config/opencode, ~/.config/autolith and their state.";
    };

    owner = lib.mkOption {
      type = lib.types.str;
      description = "The human login that starts the agents and owns codeDir.";
    };

    codeDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.owner}/code";
      defaultText = lib.literalExpression ''"/home/''${config.wotan.agentUser.owner}/code"'';
      description = "The only part of the owner's home the agents can see.";
    };

    credentials = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {axon = "/run/agenix/axon-token-wotan";};
      description = ''
        KEY=value env files read by systemd (as root) and exported into every
        agent-run session, for the MCP gateway tokens.
      '';
    };

    serverPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/agenix/opencode-server-password";
      description = ''
        KEY=value env file with OPENCODE_SERVER_PASSWORD, read by systemd (as
        root) and exported only into opencode TUI sessions (`agent-run opencode
        --server ...`). Claude sessions never get it, so they cannot use
        the server to get around their own sandbox.
      '';
    };

    network = {
      allow = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["192.168.2.178"];
        description = ''
          Addresses or prefixes inside network.deny the agents may still
          reach (the git forge, the MCP gateway). Loopback is always allowed.
        '';
      };

      deny = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "10.0.0.0/8"
          "172.16.0.0/12"
          "192.168.0.0/16"
          "100.64.0.0/10" # CGNAT (was the tailnet; stays denied)
          "fc00::/7" # ULA
          # Link-local and multicast as prefixes: systemd-run's transient
          # properties reject the symbolic names unit files accept.
          "169.254.0.0/16"
          "fe80::/10"
          "224.0.0.0/4"
          "ff00::/8"
        ];
        description = ''
          What every agent unit (agent-run sessions and opencode-serve) may
          not connect to, as systemd IPAddressDeny= entries. Anything not
          listed, i.e. the internet, stays reachable for the harness
          processes; their sandboxed commands are limited further by
          network.allowedDomains.
        '';
      };

      proxyPort = lib.mkOption {
        type = lib.types.port;
        default = 8899;
        description = "Loopback port of agent-proxy, the domain filter for sandboxed agent commands.";
      };

      allowedDomains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "localhost"
          "127.0.0.1"
          "*.homelab.internal"
          # Rust
          "crates.io"
          "index.crates.io"
          "static.crates.io"
          "static.rust-lang.org"
          "docs.rs"
          # GitHub (git over https, API, release assets, raw files)
          "github.com"
          "*.github.com"
          "*.githubusercontent.com"
          # Nix
          "cache.nixos.org"
          "channels.nixos.org"
          "nixos.org"
          "search.nixos.org"
          # Other package registries
          "registry.npmjs.org"
          "pypi.org"
          "files.pythonhosted.org"
          "proxy.golang.org"
          "sum.golang.org"
          "hex.pm"
          "repo.hex.pm"
          "builds.hex.pm"
        ];
        description = ''
          Hosts that sandboxed agent commands (Claude Code's Bash tool,
          opencode's shell) may reach, through agent-proxy. tinyproxy fnmatch
          patterns matched against the host name: `*.example.com` does not
          match `example.com` itself. Claude Code's sandbox gets the same
          list. network.deny still applies to what the proxy connects to.
        '';
      };
    };

    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = agentRun;
      description = "The agent-run launcher.";
    };

    opencodeShell = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${opencodeShell}";
      description = "The bubblewrap shell wrapper; use it as services.opencode-serve.shell.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.user} = {};
    users.users.${cfg.user} = {
      isNormalUser = true;
      inherit (cfg) home;
      group = cfg.user;
      description = "Coding agents (Claude Code, opencode, Autolith)";
      shell = pkgs.bashInteractive;
    };

    environment.systemPackages = [agentRun pkgs.acl];

    # Only this exact path, so the rule cannot be pointed at anything else.
    security.sudo.extraRules = [
      {
        users = [cfg.owner];
        commands = [
          {
            command = "/run/current-system/sw/bin/agent-run";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];
    # HERDR_* tell agent-run which herdr pane and socket to proxy.
    security.sudo.extraConfig = ''
      Defaults!/run/current-system/sw/bin/agent-run env_keep += "COLORTERM HERDR_ENV HERDR_PANE_ID HERDR_SOCKET_PATH"
    '';

    # Both users get rwx on codeDir, and the default ACLs make everything
    # created in it inherit that. This is non-recursive; the first time,
    # `just agent-acl` applies it to what already exists.
    # /run/agent-herdr holds agent-run's per-session herdr sockets.
    systemd.tmpfiles.rules = [
      "a+ ${cfg.codeDir} - - - - u:${cfg.user}:rwx,d:u:${cfg.user}:rwx,d:u:${cfg.owner}:rwx"
      "d /run/agent-herdr 0711 root root -"
    ];

    # Repos in codeDir belong to whichever user created them; without this git
    # refuses to work in the other user's ("dubious ownership"). nix's libgit2
    # ignores this wildcard, so the agent's home-manager config trusts `*`
    # (hosts/wotan/agent-home.nix).
    programs.git = {
      enable = true;
      config.safe.directory = "${cfg.codeDir}/*";
    };

    # opencode-serve is the other agent process; it gets the same network.
    systemd.services.opencode-serve.serviceConfig = lib.mkIf (config.services.opencode-serve.enable && config.services.opencode-serve.user == cfg.user) {
      IPAddressAllow = ipAllow;
      IPAddressDeny = ipDeny;
    };

    # agent-proxy (see proxyFilter). Default-deny: only network.allowedDomains
    # get through, for plain HTTP and CONNECT alike.
    services.tinyproxy = {
      enable = true;
      settings = {
        Listen = "127.0.0.1";
        Port = cfg.network.proxyPort;
        Allow = "127.0.0.1";
        Filter = proxyFilter;
        FilterType = "fnmatch";
        FilterURLs = false;
        FilterDefaultDeny = true;
      };
    };
    systemd.services.tinyproxy.serviceConfig = {
      # It connects on the agents' behalf, so it gets their network limits;
      # otherwise it would open the private ranges they are kept out of.
      IPAddressAllow = ipAllow;
      IPAddressDeny = ipDeny;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };

    # The way into agent-proxy for opencodeShell, whose commands have no
    # network: a unix socket only the agent can open, forwarded to the
    # proxy's loopback port.
    systemd.services.agent-proxy-bridge = {
      description = "Unix-socket entry to agent-proxy for network-less agent sandboxes";
      wantedBy = ["multi-user.target"];
      after = ["tinyproxy.service"];
      serviceConfig = {
        ExecStart = "${pkgs.socat}/bin/socat UNIX-LISTEN:${proxySocket},fork,unlink-early,mode=600 TCP:127.0.0.1:${proxyPort}";
        Restart = "on-failure";
        User = cfg.user;
        Group = cfg.user;
        RuntimeDirectory = "agent-proxy";
        RuntimeDirectoryMode = "0700";
        IPAddressAllow = ["127.0.0.0/8"];
        IPAddressDeny = "any";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };
  };
}
