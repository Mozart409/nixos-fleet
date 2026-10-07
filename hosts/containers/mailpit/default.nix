{config, ...}: let
  smtpPort = 1025;
  uiPort = 8025;
in {
  # Mailpit: a catch-all SMTP sink with a web UI. It never relays anything, so
  # mail sent here stays here -- which is the point: Multica's login codes
  # land in mailpit.homelab.internal instead of the backend's stdout, without
  # a real mail server or any outbound delivery.
  #
  # Anyone who reads a login code can log in as me, so the UI is behind basic
  # auth (Mailpit's own --ui-auth-file; an htpasswd line from agenix).
  services.mailpit.instances.default = {
    # The Multica backend runs in a podman container, so it reaches the host
    # through the podman bridge, not loopback. The firewall opens the port on
    # podman0 only (below); ens18 and tailscale stay closed to it.
    smtp = "0.0.0.0:${toString smtpPort}";
    listen = "127.0.0.1:${toString uiPort}";
    # Login codes expire after 10 minutes; nothing here is worth keeping.
    max = 100;
    ui-auth-file = "%d/ui-auth";
  };

  # The module runs Mailpit with DynamicUser, which can't read a root-owned
  # agenix file; LoadCredential hands it a copy.
  systemd.services.mailpit-default = {
    serviceConfig.LoadCredential = ["ui-auth:${config.age.secrets.mailpit-ui-auth.path}"];
    restartTriggers = [config.age.secrets.mailpit-ui-auth.file];
  };

  # htpasswd format: `amadeus:$2y$...` (bcrypt, `htpasswd -nB amadeus`).
  age.secrets.mailpit-ui-auth = {
    file = ../../../secrets/mailpit-ui-auth.age;
    mode = "0400";
  };

  networking.firewall.interfaces.podman0.allowedTCPPorts = [smtpPort];

  homelab.multica.server.smtp = {
    host = "host.containers.internal";
    port = smtpPort;
  };

  services.caddy.virtualHosts."mailpit.homelab.internal" = {
    extraConfig = ''
      tls {
        ca https://ca.homelab.local:8443/acme/acme/directory
      }

      reverse_proxy localhost:${toString uiPort}
    '';
  };
}
