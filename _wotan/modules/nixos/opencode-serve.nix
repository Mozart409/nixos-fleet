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
  };

  config = lib.mkIf cfg.enable {
    systemd.services.opencode-serve = {
      description = "opencode headless server";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      serviceConfig = {
        ExecStart = "${lib.getExe opencodePkg} ${lib.escapeShellArgs serveArgs}";
        Restart = "on-failure";
        RestartSec = 5;
        User = cfg.user;
        Group = "users";
        WorkingDirectory = "/home/${cfg.user}";
        EnvironmentFile = lib.mkIf (cfg.password != "") envFile;
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
