{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    en-croissant
    lc0
  ];
}
