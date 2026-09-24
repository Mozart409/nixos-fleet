{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # keep-sorted start
    anytype
    basalt
    comet-gog
    discord
    haruna
    jellyfin-mpv-shim
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
