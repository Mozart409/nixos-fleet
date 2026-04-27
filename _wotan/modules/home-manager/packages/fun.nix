{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # keep-sorted start
    # makemkv # TODO: re-enable when expat header issue is fixed upstream
    anki-bin
    charasay
    cowsay
    dwt1-shell-color-scripts
    fortune
    handbrake
    kdePackages.kwallet-pam
    llmfit
    mesen
    mpv
    nerd-fonts.jetbrains-mono
    openrgb-with-all-plugins
    # keep-sorted end
  ];
}
