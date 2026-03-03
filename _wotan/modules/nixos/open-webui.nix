{
  config,
  pkgs,
  lib,
  ...
}: {
  services.open-webui = {
    enable = true;
    openFirewall = true;
    host = "127.0.0.1";
    environment = ''
      # Disable authentication
      WEBUI_AUTH = "False";
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      AIOHTTP_CLIENT_TIMEOUT_MODEL_LIST=30
    '';
  };
}
