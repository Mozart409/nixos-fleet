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
    handbrake
    # makemkv # TODO: re-enable when expat header issue is fixed upstream
    anki-bin
    mpv
    llmfit
  ];
}
