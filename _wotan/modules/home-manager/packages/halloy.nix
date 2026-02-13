{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.halloy = {
    enable = true;
    settings = {
      "buffer.channel.topic" = {
        enabled = true;
      };
      "servers.liberachat" = {
        channels = [
          "#halloy"
        ];
        use_tls = true;
        port = 6697;
        nickname = "halloy-user-409";
        server = "irc.libera.chat";
      };
    };
  };
}
