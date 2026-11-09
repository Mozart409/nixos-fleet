{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: let
  # Suppress unclean-exit "Restore pages?" bubble (no Chromium policy for this).
  helium = pkgs.callPackage ../../../pkgs/helium.nix {
    commandLineArgs = "--hide-crash-restore-bubble";
  };
  # Temporary, until the move to Helium is done: Brave is gone from nixpkgs, so
  # it comes from the pinned pre-removal rev (no more security updates).
  brave = inputs.nixpkgs-brave.legacyPackages.${pkgs.stdenv.hostPlatform.system}.brave.override {
    commandLineArgs = "--hide-crash-restore-bubble";
  };
in {
  home.packages =
    [
      brave
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
