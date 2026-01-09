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
    mate.pluma
    pavucontrol
    galculator
  ];
}
