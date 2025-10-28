{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: {
  imports = [
    ../../modules/home-manager/common-packages.nix
    # Add host-specific home-manager modules here
  ];
}
