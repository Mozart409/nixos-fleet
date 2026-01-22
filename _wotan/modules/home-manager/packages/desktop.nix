{
  config,
  pkgs,
  lib,
  ...
}: let
  helium-browser = pkgs.appimageTools.wrapType2 {
    pname = "helium-browser";
    version = "0.8.2.1";
    src = pkgs.fetchurl {
      url = "https://github.com/imputnet/helium-linux/releases/download/0.8.2.1/helium-0.8.2.1-x86_64.AppImage";
      sha256 = "0vvmk8ljhql10mlx8mhlyza534155cqxkf6ii4m66iwshnklgcv9";
    };
  };
in {
  home.packages = with pkgs; [
    krita
    anytype
    haruna
    chromium
    teamspeak6-client
    signal-desktop-bin
    comet-gog
    discord
    lutris-unwrapped
    mate.pluma
    pavucontrol
    speedcrunch
    # Browser
    helium-browser
  ];
}
