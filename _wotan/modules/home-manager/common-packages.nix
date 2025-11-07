{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: {
  imports = [
    ./configs/base.nix
    ./configs/shell.nix
    ./configs/programs.nix
  ];

  # Import package categories as needed
  # home.packages = [];
}