{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    krita
    anytype
    haruna
    chromium
    teamspeak6-client
    signal-desktop-bin
    comet-gog
    discord
    lutris-unwrapped
  ];

  xdg.configFile."hypr/hyprpaper.conf".text = ''
    preload = /home/amadeus/Pictures/Wallpapers/nier.jpeg
    wallpaper = DP-3,/home/amadeus/Pictures/Wallpapers/nier.jpeg
    wallpaper = DP-2,/home/amadeus/Pictures/Wallpapers/nier.jpeg
  '';
}
