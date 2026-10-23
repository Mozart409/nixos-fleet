{
  config,
  lib,
  pkgs,
  self,
  ...
}: let
  # rust/countdown-rs, built by the root flake (packages.<system>.countdown).
  package = self.packages.${pkgs.stdenv.hostPlatform.system}.countdown;
  port = 3000;
  host = "countdown.homelab.internal";

  # Pocket ID, the same issuer as forgejo / grafana / romm. The app discovers
  # its endpoints from <issuer>/.well-known/openid-configuration at startup.
  oidcIssuer = "https://pocketid.dropbear-butterfly.ts.net";

  # Postgres is the `countdown` database on the database host. It is addressed
  # by name because the server cert is issued for database.homelab.internal and
  # verify-full checks the hostname. The password is alphanumeric (`pwgen -s`, URL-safe)
  # and is spliced into DATABASE_URL at start, so it never reaches the store.
  start = pkgs.writeShellScript "countdown-start" ''
    set -eu
    pw=$(cat "$CREDENTIALS_DIRECTORY/db-password")
    export DATABASE_URL="postgres://countdown:$pw@database.homelab.internal:5432/countdown?sslmode=verify-full&sslrootcert=/etc/ssl/certs/ca-certificates.crt"
    exec ${lib.getExe package}
  '';
in {
  # Raw role password, shared with the database host.
  age.secrets.countdown-db-password = {
    file = ../../../secrets/countdown-db-password.age;
    mode = "0400";
  };

  # OIDC_CLIENT_ID, OIDC_CLIENT_SECRET and VAPID_PRIVATE_KEY, as an env file.
  age.secrets.countdown-env = {
    file = ../../../secrets/countdown-env.age;
    mode = "0400";
  };

  # Binds 127.0.0.1:3000; Caddy (see ../configuration.nix) is the only way in,
  # terminating step-ca TLS at countdown.homelab.internal. The app runs its
  # sqlx migrations on start.
  systemd.services.countdown = {
    description = "countdown (offline-first countdown PWA)";
    wantedBy = ["multi-user.target"];
    # OIDC discovery runs at startup and exits if it fails, so wait for the
    # network and the tailnet name of the issuer, and retry if it still loses.
    wants = ["network-online.target"];
    after = ["network-online.target" "tailscaled.service"];
    # A re-encrypted secret lands at the same /run/agenix path and changes
    # nothing in this unit; the .file store paths do.
    restartTriggers = [
      config.age.secrets.countdown-db-password.file
      config.age.secrets.countdown-env.file
    ];
    environment = {
      BIND_ADDR = "127.0.0.1:${toString port}";
      PUBLIC_URL = "https://${host}";
      OIDC_ISSUER_URL = oidcIssuer;
      # Must match the callback registered in Pocket ID.
      OIDC_REDIRECT_URL = "https://${host}/auth/callback";
      VAPID_SUBJECT = "https://${host}";
      RUST_LOG = "countdown=info,tower_http=info";
    };
    serviceConfig = {
      ExecStart = start;
      EnvironmentFile = config.age.secrets.countdown-env.path;
      LoadCredential = "db-password:${config.age.secrets.countdown-db-password.path}";
      DynamicUser = true;
      Restart = "on-failure";
      RestartSec = "10s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };
}
