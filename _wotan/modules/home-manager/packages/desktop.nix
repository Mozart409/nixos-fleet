{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    krita
    haruna
    signal-desktop-bin
    comet-gog
    discord
    lutris-unwrapped
    pluma
    pavucontrol
    # Security
    proton-pass
    bitwarden-desktop
    bitwarden-cli
  ];
}
