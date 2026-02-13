{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.halloy = {
    enable = true;
    settings = {
      theme = "kanagawa";
      servers = {
        "liberachat" = {
          channels = [
            "#halloy"
          ];
          use_tls = true;
          port = 6697;
          nickname = "mozart409";
          server = "irc.libera.chat";
        };
      };
    };
  };
}
