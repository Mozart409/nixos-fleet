{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    charasay
    fortune
    dwt1-shell-color-scripts
    cowsay
    nerd-fonts.jetbrains-mono
    kdePackages.kwallet-pam
    openrgb-with-all-plugins
  ];
}
