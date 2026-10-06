{
  config,
  pkgs,
  lib,
  ...
}: let
  helium-browser = pkgs.appimageTools.wrapType2 {
    pname = "helium-browser";
    version = "0.8.4.1";
    src = pkgs.fetchurl {
      url = "https://github.com/imputnet/helium-linux/releases/download/0.8.4.1/helium-0.8.4.1-x86_64.AppImage";
      sha256 = "1wg6l0v4p5crv76m9vn1fjpgcjb3vny2x02ganr4n1b4x93v70nb";
    };
    extraBwrapArgs = [
      "--chdir"
      "/"
    ];
  };
  # Suppress unclean-exit "Restore pages?" bubble (no Chromium policy for this).
  braveWithFlags = pkgs.brave.override {
    commandLineArgs = "--hide-crash-restore-bubble";
  };
in {
  home.packages =
    [
      braveWithFlags
    ]
    ++ (with pkgs; [
      # keep-sorted start
      chromium
      tor-browser
      # keep-sorted end
    ]);
}
