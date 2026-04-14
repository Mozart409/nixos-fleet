{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    haruna
    obsidian
    basalt
    signal-desktop
    comet-gog
    discord
    lutris-unwrapped
    pavucontrol
    # Security
    proton-pass
    bitwarden-desktop
    bitwarden-cli
  ];
}
