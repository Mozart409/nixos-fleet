{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: {
  imports = [
    ../../modules/home-manager/common-packages.nix
    ../../modules/home-manager/packages/development.nix
    ../../modules/home-manager/packages/kubernetes.nix
    ../../modules/home-manager/packages/database.nix
    ../../modules/home-manager/packages/system.nix
    ../../modules/home-manager/packages/desktop.nix
    ../../modules/home-manager/packages/security.nix
    ../../modules/home-manager/packages/fun.nix
    ../../kickstart.nixvim/nixvim.nix
    ../../modules/home-manager/packages/tmux.nix
    ../../modules/home-manager/packages/terminals.nix
  ];

  # Host-specific home-manager packages can be added here
  # For example, if you want certain packages only on wotan:
  # home.packages = with pkgs; [
  #   host-specific-package
  # ];
}
