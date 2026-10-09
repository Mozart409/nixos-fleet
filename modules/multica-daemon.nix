{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab.multica.daemon;

  # Mirrors healthPortForProfile in server/cmd/multica/cmd_daemon.go (v0.6.1):
  # a named profile's health port is 19514 + 1 + (sum of its bytes mod 1000).
  # Two zones on one host must not land on the same port.
  healthPort = name:
    19515 + lib.mod (lib.foldl' (acc: c: acc + lib.strings.charToInt c) 0 (lib.stringToCharacters name)) 1000;

  zoneModule = {name, ...}: {
    options = {
      user = lib.mkOption {
        type = lib.types.str;
        default = "multica-${name}";
        description = "Unix user the zone's daemon and its agents run as.";
      };

      home = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/multica-${name}";
        description = ''
          The user's home. Holds ~/.multica (login, logs, Hermes memory) and the
          agent CLIs' own state, so it must be on a persistent volume.
        '';
      };

      workspacesRoot = lib.mkOption {
        type = lib.types.str;
        default = "/srv/work/${name}";
        description = "MULTICA_WORKSPACES_ROOT: bare clones in .repos/ plus one git worktree per task.";
      };

      maxConcurrentTasks = lib.mkOption {
        type = lib.types.ints.positive;
        default = 3;
        description = "MULTICA_DAEMON_MAX_CONCURRENT_TASKS (upstream default: 20).";
      };

      tokenFile = lib.mkOption {
        type = lib.types.path;
        description = ''
          File holding the zone's Multica personal access token (mul_…),
          typically an agenix secret path. Passed to `multica login` on stdin,
          never on the command line.
        '';
      };

      restartTriggers = lib.mkOption {
        type = lib.types.listOf lib.types.unspecified;
        default = [];
        example = lib.literalExpression "[config.age.secrets.multica-token-coding.file]";
        description = ''
          Restart the daemon when these change. Pass the agenix secrets' .file
          (their store path changes on every re-encryption; the /run/agenix
          path does not), so a rotated token logs in again on the next deploy.
        '';
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Extra env file for the agent CLIs (e.g. CLAUDE_CODE_OAUTH_TOKEN), typically agenix.";
      };

      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
        example = lib.literalExpression "[pkgs.claude-code pkgs.opencode]";
        description = ''
          Agent CLIs and tools on the daemon's PATH. The daemon detects the
          runtimes it offers (claude, opencode, hermes, …) from PATH.
        '';
      };

      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        example = {MULTICA_GC_HERMES_MEMORY_TTL = "0";};
        description = "Extra MULTICA_* settings, e.g. GC TTLs or watchdogs. Overrides the module's defaults.";
      };
    };
  };

  login = name: zone:
    pkgs.writeShellScript "multica-${name}-login" ''
      set -eu
      multica --profile ${name} config set server_url ${cfg.serverUrl}
      multica --profile ${name} config set app_url ${cfg.appUrl}
      # `--token` with no value reads the token from stdin.
      multica --profile ${name} login --token < "$CREDENTIALS_DIRECTORY/token"
    '';
in {
  options.homelab.multica.daemon = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../pkgs/multica.nix {};
      description = "The multica CLI/daemon.";
    };

    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://multica.homelab.internal";
      description = "Backend URL the daemons connect to (Caddy routes /api and /ws to it).";
    };

    appUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://multica.homelab.internal";
      description = "Web UI URL, used for links the CLI prints.";
    };

    zones = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule zoneModule);
      default = {};
      description = ''
        One daemon per zone. The attribute name is the runtime name shown in
        Multica (coding, assistant, web) and the CLI profile, which isolates
        config, state and health port when several zones share a host.
      '';
    };
  };

  config = lib.mkIf (cfg.zones != {}) {
    assertions = [
      {
        assertion = let
          ports = lib.mapAttrsToList (name: _: healthPort name) cfg.zones;
        in
          lib.length ports == lib.length (lib.unique ports);
        message = "homelab.multica.daemon.zones: two zone names hash to the same daemon health port; rename one.";
      }
    ];

    users.groups = lib.mapAttrs' (_: zone: lib.nameValuePair zone.user {}) cfg.zones;
    users.users = lib.mapAttrs' (_: zone:
      lib.nameValuePair zone.user {
        isSystemUser = true;
        group = zone.user;
        inherit (zone) home;
        createHome = true;
        # Agents run git, nix and shells under this account.
        shell = pkgs.bashInteractive;
      })
    cfg.zones;

    systemd.tmpfiles.rules =
      lib.mapAttrsToList (_: zone: "d ${zone.workspacesRoot} 0750 ${zone.user} ${zone.user} -") cfg.zones;

    systemd.services = lib.mapAttrs' (name: zone:
      lib.nameValuePair "multica-daemon-${name}" {
        description = "Multica daemon (zone ${name})";
        wantedBy = ["multi-user.target"];
        wants = ["network-online.target"];
        after = ["network-online.target"];
        path = [cfg.package pkgs.git pkgs.openssh] ++ zone.packages;
        environment =
          {
            HOME = zone.home;
            MULTICA_WORKSPACES_ROOT = zone.workspacesRoot;
            MULTICA_DAEMON_MAX_CONCURRENT_TASKS = toString zone.maxConcurrentTasks;
            MULTICA_AGENT_RUNTIME_NAME = name;
            MULTICA_DAEMON_DEVICE_NAME = "${config.networking.hostName}-${name}";
            # Nix owns the binary: no self-update from GitHub releases, and no
            # restart-on-binary-change (a deploy restarts the unit anyway).
            MULTICA_DAEMON_AUTO_UPDATE = "false";
            MULTICA_DAEMON_AUTO_RELOAD = "false";
            # Upstream defaults (server/internal/daemon/config.go, v0.6.1) suit
            # a laptop with 20 slots; these suit a VM with a few. Days are
            # written as hours so plain time.ParseDuration accepts them too.
            # Absolute per-run cap (upstream 0 = none): a hung run otherwise
            # holds its slot indefinitely.
            MULTICA_AGENT_TIMEOUT = "2h";
            # Silent backend + empty queue for this long ends the run (upstream 2h).
            MULTICA_AGENT_IDLE_WATCHDOG = "30m";
            # Self-host default is 0, so finished task worktrees were never
            # removed and only filled the work volume.
            MULTICA_GC_COMPLETED_TASK_TTL = "168h";
            # Upstream prunes only JS build output; add Rust target/ and .direnv.
            MULTICA_GC_ARTIFACT_PATTERNS = "node_modules,.next,.turbo,target,.direnv";
          }
          // zone.environment;
        inherit (zone) restartTriggers;
        serviceConfig = {
          User = zone.user;
          Group = zone.user;
          WorkingDirectory = zone.home;
          LoadCredential = ["token:${zone.tokenFile}"];
          EnvironmentFile = lib.optional (zone.environmentFile != null) zone.environmentFile;
          # Logs in on every start: idempotent, and picks up a rotated token.
          ExecStartPre = login name zone;
          ExecStart = "${lib.getExe cfg.package} --profile ${name} daemon start --foreground";
          Restart = "always";
          RestartSec = "10s";
        };
      })
    cfg.zones;
  };
}
