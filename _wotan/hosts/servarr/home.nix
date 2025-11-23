{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: {
  # Home Manager configuration for amadeus
  home.username = "amadeus";
  home.homeDirectory = "/home/amadeus";

  # Basic packages
  home.packages = with pkgs; [
    git
    vim
    curl
    wget
  ];

  # Basic shell configuration
  programs.bash = {
    enable = true;
    enableCompletion = true;
  };

  # State version
  home.stateVersion = "25.11";
}