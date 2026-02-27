{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # krita # TODO: re-enable when lager/boost cmake issue is fixed upstream
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
