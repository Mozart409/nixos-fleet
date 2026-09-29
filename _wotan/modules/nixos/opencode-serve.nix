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

    inaccessiblePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Paths hidden from the server and all tools/commands it runs.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.opencode-serve = {
      description = "opencode headless server";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      environment = {
        PATH = lib.mkForce (lib.concatStringsSep ":" cfg.path);
        EDITOR = "nvim";
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
