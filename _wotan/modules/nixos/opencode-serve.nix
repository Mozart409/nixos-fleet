{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.opencode-serve;

  opencodePkg = cfg.package;

  # Build the argument list passed to opencode serve.
  serveArgs =
    [
      "serve"
      "--hostname"
      cfg.hostname
      "--port"
      (toString cfg.port)
    ]
    ++ lib.optionals cfg.mdns [
      "--mdns"
    ]
    ++ lib.optionals (cfg.mdnsDomain != null) [
      "--mdns-domain"
      cfg.mdnsDomain
    ]
    ++ lib.optionals (cfg.logLevel != null) [
      "--log-level"
      cfg.logLevel
    ]
    ++ cfg.extraArgs;

  envFile = pkgs.writeText "opencode-serve.env" ''
    OPENCODE_SERVER_PASSWORD=${cfg.password}
  '';

  # Export raw-value secrets (files holding just the value, not KEY=value)
  # from systemd credentials, then exec the server.
  startScript = pkgs.writeShellScript "opencode-serve-start" ''
    ${lib.concatStrings (lib.mapAttrsToList (name: _: ''
        export ${name}="$(< "$CREDENTIALS_DIRECTORY/${name}")"
      '')
      cfg.credentialEnvironment)}
    exec ${lib.getExe opencodePkg} ${lib.escapeShellArgs serveArgs}
  '';

  home = "/home/${cfg.user}";

  signingEnabled = cfg.signing.keyFile != null;
  signingSocket = "/run/opencode-signing/agent.sock";

  # Dedicated agent holding ONLY the signing key. It runs outside the opencode
  # sandbox (which hides ~/.ssh), so opencode can sign commits without ever
  # reading the key, and without access to the user's login keys.
  signingAgentScript = pkgs.writeShellScript "opencode-signing-agent" ''
    rm -f ${signingSocket}
    ${pkgs.openssh}/bin/ssh-agent -D -a ${signingSocket} &
    pid=$!
    for _ in {1..50}; do
      [ -S ${signingSocket} ] && break
      ${pkgs.coreutils}/bin/sleep 0.1
    done
    SSH_AUTH_SOCK=${signingSocket} ${pkgs.openssh}/bin/ssh-add -q ${lib.escapeShellArg cfg.signing.keyFile}
    wait "$pid"
  '';
in {
  options.services.opencode-serve = {
    enable = lib.mkEnableOption "opencode headless server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.opencode;
      description = "opencode package to use.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Hostname to bind the server to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4096;
      description = "Port to listen on.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "amadeus";
      description = "User to run the service as.";
    };

    password = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Basic-auth password for the server (empty = no auth).";
    };

    mdns = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable mDNS service discovery (sets hostname to 0.0.0.0).";
    };

    mdnsDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Custom domain name for mDNS service.";
    };

    logLevel = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["DEBUG" "INFO" "WARN" "ERROR"]);
      default = null;
      description = "Log level for the server.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra arguments to pass to opencode serve.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
      description = ''
        Extra EnvironmentFile entries for the service (KEY=value format).
        Use this to inject secrets (e.g. agenix paths) so the server process
        can expand {env:VAR} placeholders in opencode.json MCP headers —
        attached clients' shell environments are NOT visible to the server.
      '';
    };

    credentialEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = {};
      example = {CONTEXT7_API_KEY = "/run/agenix/context7-api-key";};
      description = ''
        Environment variables whose value is the whole content of a file
        (raw secret, not KEY=value). Loaded via systemd LoadCredential, so the
        source path can stay inaccessible to the sandboxed service.
      '';
    };

    path = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "${home}/.nix-profile/bin"
        "/etc/profiles/per-user/${cfg.user}/bin"
        "/run/current-system/sw/bin"
      ];
      description = ''
        PATH for the server and every shell command it runs. /run/wrappers/bin
        (sudo & other setuid wrappers) is deliberately absent; NoNewPrivileges
        would make them fail anyway.
      '';
    };

    readWritePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [home];
      description = "Writable paths; the rest of the filesystem is read-only (ProtectSystem=strict).";
    };

    signing = {
      keyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Private SSH key (passphrase-less, used ONLY for commit signing, not
          registered for login anywhere) loaded into a dedicated agent. Keep it
          under an inaccessiblePaths entry so opencode can't read it.
        '';
      };
      publicKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "ssh-ed25519 AAAA... opencode-signing";
        description = "Public half of signing.keyFile; git signs via the agent with it.";
      };
    };

    inaccessiblePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Paths hidden from the server and all tools/commands it runs.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = signingEnabled -> cfg.signing.publicKey != null;
        message = "services.opencode-serve.signing.publicKey must be set with signing.keyFile.";
      }
    ];

    systemd.services.opencode-signing-agent = lib.mkIf signingEnabled {
      description = "ssh-agent holding only the AI-agent (opencode, Claude Code) commit-signing key";
      serviceConfig = {
        ExecStart = signingAgentScript;
        Restart = "on-failure";
        User = cfg.user;
        Group = "users";
        RuntimeDirectory = "opencode-signing";
        RuntimeDirectoryMode = "0700";
      };
    };

    systemd.services.opencode-serve = {
      description = "opencode headless server";
      wantedBy = ["multi-user.target"];
      after = ["network.target"] ++ lib.optional signingEnabled "opencode-signing-agent.service";
      requires = lib.optional signingEnabled "opencode-signing-agent.service";

      environment =
        {
          PATH = lib.mkForce (lib.concatStringsSep ":" cfg.path);
          EDITOR = "nvim";
        }
        // lib.optionalAttrs signingEnabled {
          # Only the signing agent: no login keys, so no SSH push either.
          SSH_AUTH_SOCK = signingSocket;
          # Env-level git config overrides ~/.config/git/config for every git
          # run by opencode: sign with the dedicated key through the agent.
          GIT_CONFIG_COUNT = "3";
          GIT_CONFIG_KEY_0 = "user.signingkey";
          GIT_CONFIG_VALUE_0 = "key::${cfg.signing.publicKey}";
          GIT_CONFIG_KEY_1 = "gpg.format";
          GIT_CONFIG_VALUE_1 = "ssh";
          GIT_CONFIG_KEY_2 = "commit.gpgsign";
          GIT_CONFIG_VALUE_2 = "true";
        };

      # Every opencode tool call (shell, read, edit, MCP) runs inside this
      # process tree, so the unit sandbox is the OS-level boundary for all of
      # them — not just bash like Claude Code's sandbox.
      serviceConfig = {
        ExecStart = startScript;
        Restart = "on-failure";
        RestartSec = 5;
        User = cfg.user;
        Group = "users";
        WorkingDirectory = home;
        EnvironmentFile = lib.optional (cfg.password != "") envFile ++ cfg.environmentFiles;
        LoadCredential = lib.mapAttrsToList (name: file: "${name}:${file}") cfg.credentialEnvironment;

        # No root: sudo/setuid can't escalate, so nothing can switch the
        # system (nixos-rebuild/nh os switch need root).
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
        CapabilityBoundingSet = "";

        ProtectSystem = "strict";
        ReadWritePaths = cfg.readWritePaths;
        # "-": don't fail the unit if a path doesn't exist.
        InaccessiblePaths = map (p: "-${p}") cfg.inaccessiblePaths;
        PrivateTmp = true;

        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        LockPersonality = true;
        RestrictRealtime = true;
        # No MemoryDenyWriteExecute: bun's JIT needs W+X pages.
      };
    };

    # Expose the server URL as an environment variable for clients.
    environment.sessionVariables =
      {
        OPENCODE_SERVER_URL = "http://${cfg.hostname}:${toString cfg.port}";
        OPENCODE_SERVER_PORT = toString cfg.port;
      }
      // lib.optionalAttrs (cfg.password != "") {
        OPENCODE_SERVER_PASSWORD = cfg.password;
      };
  };
}
