{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # keep-sorted start
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
    nerd-fonts.symbols-only
    # keep-sorted end
  ];
}
