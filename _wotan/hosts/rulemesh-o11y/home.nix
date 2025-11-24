{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: {
  imports = [
    ../../kickstart.nixvim/nixvim.nix
    ../../modules/home-manager/packages/tmux.nix
    ../../modules/home-manager/packages/terminals.nix
    ../../modules/home-manager/configs/shell.nix
    ../../modules/home-manager/configs/shell.nix
  ];
  # Home Manager configuration for amadeus
  home.username = "amadeus";
  home.homeDirectory = "/home/amadeus";

  # Basic packages
  home.packages = with pkgs; [
    git
    vim
    curl
    wget
    zsh
    ripgrep
    fzf
    busybox
  ];

  # State version
  home.stateVersion = "25.11";
}
