{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab.multica.server;

  # DATABASE_URL is built at runtime from multica-db-password.age, the same
  # secret the database host sets the role password from, so the password has
  # one source. URL-encoded, because a generated password may contain URL
  # metacharacters.
  generateDbEnv = pkgs.writeShellScript "generate-multica-db-env" ''
    mkdir -p /run/multica
    umask 077
    pw=$(${pkgs.jq}/bin/jq -Rr @uri < ${config.age.secrets.multica-db-password.path})
    printf 'DATABASE_URL=postgres://multica:%s@${cfg.databaseHost}:5432/multica?sslmode=verify-full&sslrootcert=/etc/ssl/certs/ca-certificates.crt\n' "$pw" > /run/multica/db.env
  '';
in {
  options.homelab.multica.server = {
    enable = lib.mkEnableOption "Multica server (backend + web as OCI containers)";

    imageTag = lib.mkOption {
      type = lib.types.str;
      default = "v0.6.1";
      description = "Multica release tag for the backend and web images.";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "multica.homelab.internal";
      description = "Canonical public origin (FRONTEND_ORIGIN / MULTICA_APP_URL).";
    };

    databaseHost = lib.mkOption {
      type = lib.types.str;
      default = "database.homelab.internal";
      description = "PostgreSQL host; must match a SAN of its step-ca cert (sslmode=verify-full).";
    };

    backendPort = lib.mkOption {
      type = lib.types.port;
      default = 8390;
      description = "Loopback port the backend container publishes on.";
    };

    webPort = lib.mkOption {
      type = lib.types.port;
      default = 8391;
      description = "Loopback port the web container publishes on.";
    };

    allowedEmails = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Exact email addresses allowed to sign up without an invitation. Empty
        leaves ALLOWED_EMAILS to multica-env.age, which keeps the address out of
        this public repo.
      '';
    };

    allowSignup = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether anyone may self-register. Off by default: ALLOWED_EMAILS is
        checked first and lets its addresses sign up regardless, so the first
        login works without opening signup.
      '';
    };

    uploadsDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/multica/uploads";
      description = "Host path for backend uploads (LOCAL_UPLOAD_DIR).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.uploadsDir} 0755 root root -"
    ];

    # App secrets, read by systemd as root before the backend container starts:
    # JWT_SECRET, MULTICA_VCS_SECRET_KEY and ALLOWED_EMAILS.
    age.secrets.multica-env = {
      file = ../secrets/multica-env.age;
      mode = "0400";
    };

    # DB password (shared with the database host). Root reads it in
    # ExecStartPre to generate /run/multica/db.env.
    age.secrets.multica-db-password = {
      file = ../secrets/multica-db-password.age;
      mode = "0400";
    };

    # Backend. Binds 127.0.0.1:8390 -> 8080; Caddy is the only thing that
    # proxies to it (see the vhost below), terminating step-ca TLS at
    # multica.homelab.internal.
    virtualisation.oci-containers.containers.multica-backend = {
      image = "ghcr.io/multica-ai/multica-backend:${cfg.imageTag}";
      autoStart = true;
      ports = ["127.0.0.1:${toString cfg.backendPort}:8080"];
      volumes = [
        "${cfg.uploadsDir}:/app/data/uploads"
        # Host CA bundle (step-ca root) so the sslrootcert in DATABASE_URL can
        # verify the postgres leaf; the image ships no trust store entry for it.
        "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro"
      ];
      environment =
        {
          APP_ENV = "production";
          PORT = "8080";
          FRONTEND_ORIGIN = "https://${cfg.domain}";
          MULTICA_APP_URL = "https://${cfg.domain}";
          CORS_ALLOWED_ORIGINS = "https://${cfg.domain}";
          # Self-hosted Git provider integration (Forgejo). The signing key is in
          # multica-env.age.
          MULTICA_VCS_INTEGRATION_ENABLED = "true";
          # Local-only: no anonymous telemetry to telemetry.multica.ai.
          DO_NOT_TRACK = "true";
          ALLOW_SIGNUP =
            if cfg.allowSignup
            then "true"
            else "false";
        }
        // lib.optionalAttrs (cfg.allowedEmails != []) {
          ALLOWED_EMAILS = lib.concatStringsSep "," cfg.allowedEmails;
        };
      # multica-env.age (signing keys, ALLOWED_EMAILS) + db.env (DATABASE_URL,
      # generated at runtime). db.env is last so it wins over a stale
      # DATABASE_URL left in the agenix file.
      environmentFiles = [
        config.age.secrets.multica-env.path
        "/run/multica/db.env"
      ];
    };

    # Web (Next.js). Binds 127.0.0.1:8391 -> 3000. Caddy routes /api/* and /ws*
    # to the backend directly, so the web container only serves the SPA and
    # makes same-origin client calls; REMOTE_API_URL stays unset.
    virtualisation.oci-containers.containers.multica-web = {
      image = "ghcr.io/multica-ai/multica-web:${cfg.imageTag}";
      autoStart = true;
      ports = ["127.0.0.1:${toString cfg.webPort}:3000"];
      environment = {
        HOSTNAME = "0.0.0.0";
      };
    };

    systemd.services.podman-multica-backend = {
      serviceConfig = {
        ExecStartPre = ["${generateDbEnv}"];
        # The backend runs its migrations on start, and the first one needs the
        # `vector` extension that the database host creates in its own oneshot
        # (postgresql-multica-extension). Nothing orders units across hosts, so
        # if the backend wins that race it exits and retries. 10s keeps the
        # retries under systemd's default start limit (5 in 10s).
        RestartSec = "10s";
      };
      # A re-encrypted secret at the same /run/agenix path changes nothing in
      # the generated unit, so without this a rotated secret would leave the
      # container on the old values until something else restarted it. The
      # .file is the store path of the .age file.
      restartTriggers = [
        config.age.secrets.multica-env.file
        config.age.secrets.multica-db-password.file
      ];
    };

    # Caddy vhost. /api/* and /ws* go to the backend (the daemon and the web UI
    # both use the /ws WebSocket), everything else to the web SPA. The ACME URL
    # stays on ca.homelab.local: step-ca's cert has no .internal SAN.
    services.caddy.virtualHosts.${cfg.domain} = {
      extraConfig = ''
        tls {
          ca https://ca.homelab.local:8443/acme/acme/directory
        }

        handle /api/* {
          reverse_proxy localhost:${toString cfg.backendPort}
        }
        handle /ws* {
          reverse_proxy localhost:${toString cfg.backendPort}
        }
        handle {
          reverse_proxy localhost:${toString cfg.webPort}
        }
      '';
    };
  };
}
