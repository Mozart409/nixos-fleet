{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # keep-sorted start
    basalt
    comet-gog
    discord
    drawio
    haruna
    kdePackages.okular # fillable PDF forms
    lutris-unwrapped
    obsidian
    pavucontrol
    proton-pass
    signal-desktop
    xournalpp # annotate flat/scanned PDFs
    # keep-sorted end
  ];
}
