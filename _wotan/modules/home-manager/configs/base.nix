{
  config,
  pkgs,
  lib,
  ...
}: {
  # Home Manager needs basic information
  home.username = "amadeus";
  home.homeDirectory = "/home/amadeus";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Common session variables
  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.sessionPath = [];

  # GPG agent configuration - uses system pinentry (pinentry-gnome3)
  services.gpg-agent.enable = true;

  # Home Manager state version
  home.stateVersion = "24.11";
}
