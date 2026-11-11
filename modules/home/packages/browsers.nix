{
  config,
  pkgs,
  lib,
  ...
}: let
  # Suppress unclean-exit "Restore pages?" bubble (no Chromium policy for this).
  helium = pkgs.callPackage ../../../pkgs/helium.nix {
    commandLineArgs = "--hide-crash-restore-bubble";
  };
in {
  home.packages =
    [
      helium
    ]
    ++ (with pkgs; [
      # keep-sorted start
      chromium
      ladybird
      tor-browser
      # keep-sorted end
    ]);
}
