{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    tor
    torsocks
    tor-browser
  ];
}