{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab.multica.server;
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

    extraDomain = lib.mkOption {
      type = lib.types.str;
      default = "multica.homelab.local";
      description = "Legacy .local alias served alongside the canonical domain.";
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
      default = ["amadeus@mozart409.com"];
      description = "Exact email addresses allowed to sign up without an invitation.";
    };

    allowSignup = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether new accounts may self-register. Flip to false after the first login.";
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

    # App secrets, read by systemd as root before the backend container starts.
    # multica-env.age holds the auth signing key, the VCS signing key, and the
    # database connection string (DATABASE_URL, with sslmode=verify-full and
    # sslrootcert=/etc/ssl/certs/ca-certificates.crt). The database credential
    # is duplicated in multica-db-password.age, which the database host uses to
    # set the matching role; keep the two in sync.
    age.secrets.multica-env = {
      file = ../secrets/multica-env.age;
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
      environment = {
        APP_ENV = "production";
        PORT = "8080";
        FRONTEND_ORIGIN = "https://${cfg.domain}";
        MULTICA_APP_URL = "https://${cfg.domain}";
        # Both origins are reachable in a browser (tailnet split-DNS serves
        # .local, the LAN serves .internal), so both must be allowed for CORS
        # and WebSocket connections.
        CORS_ALLOWED_ORIGINS = "https://${cfg.domain},https://${cfg.extraDomain}";
        # Self-hosted Git provider integration (Forgejo). The signing key is in
        # multica-env.age.
        MULTICA_VCS_INTEGRATION_ENABLED = "true";
        # Local-only: no anonymous telemetry to telemetry.multica.ai.
        DO_NOT_TRACK = "true";
        ALLOW_SIGNUP =
          if cfg.allowSignup
          then "true"
          else "false";
        ALLOWED_EMAILS = lib.concatStringsSep "," cfg.allowedEmails;
      };
      # multica-env.age supplies DATABASE_URL plus the signing keys.
      environmentFiles = [config.age.secrets.multica-env.path];
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

    # A re-encrypted secret at the same /run/agenix path changes nothing in the
    # generated unit, so without this a rotated secret would leave the container
    # on the old values until something else restarted it. The .file is the
    # store path of the .age file.
    systemd.services.podman-multica-backend.restartTriggers = [config.age.secrets.multica-env.file];

    # Caddy vhost. /api/* and /ws* go to the backend (the daemon and the web UI
    # both use the /ws WebSocket), everything else to the web SPA.
    services.caddy.virtualHosts."${cfg.extraDomain} ${cfg.domain}" = {
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
