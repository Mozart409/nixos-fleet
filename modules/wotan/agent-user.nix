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
    exec ${pkgs.bashInteractive}/bin/bash -l -c '
      eval "$(direnv export bash 2>/dev/null)"
      exec "$@"
    ' agent-run "$@"
  '';

  credentialArgs =
    lib.mapAttrsToList (name: path: "--property=LoadCredential=${name}:${path}") cfg.credentials;

  # Root-owned launcher, the only command the owner may sudo to without a
  # password. Starts claude or opencode as the agent in a transient unit with
  # the sandbox above, in the caller's directory, which must be under codeDir.
  agentRun = pkgs.writeShellScriptBin "agent-run" ''
    set -eu
    case "''${1:-}" in
      claude | opencode) ;;
      *)
        echo "usage: agent-run claude|opencode [args...]" >&2
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
    exec ${config.systemd.package}/bin/systemd-run \
      --quiet --pty --wait --collect --service-type=exec \
      --uid=${cfg.user} --gid=${cfg.user} \
      --working-directory="$dir" \
      --setenv=TERM="''${TERM:-xterm-256color}" \
      ''${COLORTERM:+--setenv=COLORTERM="$COLORTERM"} \
      ${lib.escapeShellArgs (map (p: "--property=${p}") sandboxProperties ++ credentialArgs)} \
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

    flakeRepos = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["/home/amadeus/code/yggdrasil"];
      description = ''
        Repos in codeDir the agents evaluate as flakes. nix's libgit2 ignores
        the `codeDir/*` safe.directory wildcard that git honors, so each one
        needs its exact path or `nix eval` refuses it as not owned by the
        agent.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = agentRun;
      description = "The agent-run launcher.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.user} = {};
    users.users.${cfg.user} = {
      isNormalUser = true;
      inherit (cfg) home;
      group = cfg.user;
      description = "Coding agents (Claude Code, opencode)";
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
    # refuses to work in the other user's ("dubious ownership").
    programs.git = {
      enable = true;
      config.safe.directory = ["${cfg.codeDir}/*"] ++ cfg.flakeRepos;
    };

    # opencode-serve is the other agent process; it gets the same network.
    systemd.services.opencode-serve.serviceConfig = lib.mkIf (config.services.opencode-serve.enable && config.services.opencode-serve.user == cfg.user) {
      IPAddressAllow = ipAllow;
      IPAddressDeny = ipDeny;
    };
  };
}
