{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.wotan.agentUser;

  # Every agent process (interactive claude/opencode/pi via agent-run, and
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
  # allowed: resolved's stub at 127.0.0.53 and opencode-serve live there.
  ipAllow = ["127.0.0.0/8" "::1/128"] ++ cfg.network.allow;
  ipDeny = cfg.network.deny;

  sandboxProperties =
    [
      "ProtectHome=tmpfs"
      "PrivateTmp=yes"
      "NoNewPrivileges=yes"
      "RestrictSUIDSGID=yes"
      "ProtectSystem=strict"
      "ProtectKernelTunables=yes"
      "ProtectKernelModules=yes"
      "ProtectKernelLogs=yes"
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
  inner = pkgs.writeShellScript "agent-run-inner" ''
    for cred in "''${CREDENTIALS_DIRECTORY:-/nonexistent}"/*; do
      [ -f "$cred" ] || continue
      set -a
      . "$cred"
      set +a
    done
    # autolith's mcp.sexp takes a header value from one variable and wants the
    # complete value ("Bearer <token>"), where the credential files hold the
    # bare token for opencode's {env:} and pi's ''${VAR} interpolation.
    if [ -n "''${AXON_GATEWAY_TOKEN:-}" ]; then
      export AUTOLITH_MCP_AXON="Bearer $AXON_GATEWAY_TOKEN"
    fi
    if [ -n "''${VENTARA_GATEWAY_TOKEN:-}" ]; then
      export AUTOLITH_MCP_VENTARA="Bearer $VENTARA_GATEWAY_TOKEN"
    fi
    exec ${pkgs.bashInteractive}/bin/bash -l -c '
      eval "$(direnv export bash 2>/dev/null)"
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

  # opencode runs every shell command as `$SHELL -c`, so this is its SHELL. It
  # confines shell commands only: opencode's read/edit tools and MCP stay in
  # the server process. Writes are limited to codeDir, ~/.cache and /tmp, and
  # the secret files above are masked. There is no fresh /proc, as
  # ProtectKernelTunables masks it, so no PID namespace: the server's
  # environment stays readable through /proc. Only paths that exist are
  # masked, as bwrap would create the missing ones in the real filesystem.
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
    ${pkgs.coreutils}/bin/mkdir -p ${cfg.home}/.cache
    exec ${pkgs.bubblewrap}/bin/bwrap \
      --ro-bind / / \
      --dev /dev \
      --ro-bind /proc /proc \
      --bind ${cfg.codeDir} ${cfg.codeDir} \
      --bind ${cfg.home}/.cache ${cfg.home}/.cache \
      --bind /tmp /tmp \
      "''${mask[@]}" \
      --setenv CARGO_HOME ${cfg.home}/.cache/cargo \
      --die-with-parent \
      -- ${pkgs.bashInteractive}/bin/bash "$@"
  '';

  credentialArgs =
    lib.mapAttrsToList (name: path: "--property=LoadCredential=${name}:${path}") cfg.credentials;

  # Commit signing for autolith, the same way claude.nix gets it: its own
  # ssh-agent socket plus GIT_CONFIG_* instead of the owner's ~/.gitconfig.
  # agent-run sets these for autolith sessions only, so each harness keeps its
  # own agent (signing.agents in hosts/wotan/default.nix).
  autolithSigning = let
    signing = config.services.opencode-serve.signing;
  in
    lib.optionalAttrs (signing.keyFile != null && signing.sockets ? autolith && signing.publicKey != null) {
      SSH_AUTH_SOCK = signing.sockets.autolith;
      GIT_CONFIG_COUNT = "3";
      GIT_CONFIG_KEY_0 = "user.signingkey";
      GIT_CONFIG_VALUE_0 = "key::${signing.publicKey}";
      GIT_CONFIG_KEY_1 = "gpg.format";
      GIT_CONFIG_VALUE_1 = "ssh";
      GIT_CONFIG_KEY_2 = "commit.gpgsign";
      GIT_CONFIG_VALUE_2 = "true";
    };

  autolithSigningArgs =
    map (name: "--setenv=${name}=${autolithSigning.${name}}") (lib.attrNames autolithSigning);

  # Root-owned launcher, the only command the owner may sudo to without a
  # password. Starts claude, opencode, pi or autolith as the agent in a
  # transient unit with the sandbox above, in the caller's directory, which
  # must be under codeDir.
  agentRun = pkgs.writeShellScriptBin "agent-run" ''
    set -eu
    case "''${1:-}" in
      claude | opencode | pi | autolith) ;;
      *)
        echo "usage: agent-run claude|opencode|pi|autolith [args...]" >&2
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
    # autolith signs its commits with its own agent (claude.nix does the same
    # for claude); the other harnesses keep theirs.
    if [ "$1" = autolith ]; then
      extra+=(${lib.escapeShellArgs autolithSigningArgs})
    fi
    exec ${config.systemd.package}/bin/systemd-run \
      --quiet --pty --wait --collect --service-type=exec \
      --uid=${cfg.user} --gid=${cfg.user} \
      --working-directory="$dir" \
      --setenv=TERM="''${TERM:-xterm-256color}" \
      ''${COLORTERM:+--setenv=COLORTERM="$COLORTERM"} \
      ${lib.escapeShellArgs (map (p: "--property=${p}") sandboxProperties ++ credentialArgs)} \
      "''${extra[@]}" \
      ${inner} "$@"
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
      description = "The agents' home: ~/.claude, ~/.config/opencode and their state.";
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
      example = {axon = "/run/agenix/axon-gateway-env";};
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
        --server ...`). Claude and pi sessions never get it, so they cannot use
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
          "100.64.0.0/10" # tailnet (CGNAT)
          "fc00::/7" # ULA, tailnet IPv6 included
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
          listed, i.e. the internet, stays reachable.
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
      description = "Coding agents (Claude Code, opencode, pi, autolith)";
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
    security.sudo.extraConfig = ''
      Defaults!/run/current-system/sw/bin/agent-run env_keep += "COLORTERM"
    '';

    # Both users get rwx on codeDir, and the default ACLs make everything
    # created in it inherit that. This is non-recursive; the first time,
    # `just agent-acl` applies it to what already exists.
    systemd.tmpfiles.rules = [
      "a+ ${cfg.codeDir} - - - - u:${cfg.user}:rwx,d:u:${cfg.user}:rwx,d:u:${cfg.owner}:rwx"
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
  };
}
