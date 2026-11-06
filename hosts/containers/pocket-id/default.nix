{
  config,
  lib,
  ...
}: let
  port = 1411;
  host = "pocketid.homelab.internal";
in {
  # ENCRYPTION_KEY and DB_CONNECTION_STRING, as an env file.
  #
  # ENCRYPTION_KEY must be the key the old LXC used: the signing keys are
  # stored encrypted with it in the database, so a new key makes them
  # unreadable. DB_CONNECTION_STRING is the `pocketid` role on the database
  # host; its password is the same as pocketid-db-password.age there, so
  # rotating it means re-encrypting both files. The server cert is issued for
  # database.homelab.internal, hence the name and verify-full.
  age.secrets.pocketid-env = {
    file = ../../../secrets/pocketid-env.age;
    mode = "0400";
  };

  services.pocket-id = {
    enable = true;
    environmentFile = config.age.secrets.pocketid-env.path;
    settings = {
      # Sets the passkey domain, so changing it invalidates every passkey.
      APP_URL = "https://${host}";
      TRUST_PROXY = true;
      ANALYTICS_DISABLED = true;
      # Loopback only; Caddy is the way in.
      HOST = "127.0.0.1";
      PORT = toString port;
    };
  };

  # The CLI (export/import, recovery commands) for the cutover and for recovery.
  environment.systemPackages = [config.services.pocket-id.package];

  # Postgres lives on another VM, so wait for the network. A boot or database
  # outage must keep retrying rather than trip the start limit and park the
  # unit in `failed` (same failure as oauth2-proxy on 2026-10-17, see
  # ../hindsight).
  systemd.services.pocket-id = {
    wants = ["network-online.target"];
    after = ["network-online.target"];
    # The module's own trigger is the stable /run/agenix path; a re-encrypted
    # secret keeps it, so add the .file store path to restart on rotation.
    restartTriggers = [config.age.secrets.pocketid-env.file];
    unitConfig.StartLimitIntervalSec = 0;
    # The module sets RestartSec = 1 as a plain value.
    serviceConfig.RestartSec = lib.mkForce 5;
  };

  services.caddy.virtualHosts.${host} = {
    # 127.0.0.1, never `localhost`: see ../hindsight.
    extraConfig = ''
      tls {
        ca https://ca.homelab.internal:8443/acme/acme/directory
      }

      reverse_proxy 127.0.0.1:${toString port}
    '';
  };
}
