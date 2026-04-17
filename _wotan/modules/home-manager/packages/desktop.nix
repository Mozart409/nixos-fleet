{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # keep-sorted start
    basalt
    bitwarden-cli
    bitwarden-desktop
    comet-gog
    discord
    haruna
    lutris-unwrapped
    obsidian
    pavucontrol
    # Security
    proton-pass
    signal-desktop
    # keep-sorted end
  ];
}
