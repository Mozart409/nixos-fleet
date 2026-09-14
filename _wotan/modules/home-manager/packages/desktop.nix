{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # keep-sorted start
    anytype
    basalt
    comet-gog
    discord
    haruna
    jellyfin-mpv-shim
    lutris-unwrapped
    obsidian
    pavucontrol
    proton-pass
    signal-desktop
    # keep-sorted end
  ];
}
