{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    ../../modules/home-manager/common-packages.nix
    ../../nixvim.nix
    ../../terminals.nix
    ../../tmux.nix
  ];

  # Host-specific home-manager packages can be added here
  # For example, if you want certain packages only on wotan:
  # home.packages = with pkgs; [
  #   host-specific-package
  # ];
}