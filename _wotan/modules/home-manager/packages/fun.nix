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
    # handbrake  # TODO: re-enable — broken upstream, bundled ffmpeg mov patch fails to apply to ffmpeg 8.1.2
    kdePackages.kwallet-pam
    llmfit
    mesen
    mpv
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    # keep-sorted end
  ];
}
