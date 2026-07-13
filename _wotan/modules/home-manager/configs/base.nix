{
  config,
  pkgs,
  lib,
  username,
  ...
}: {
  # Home Manager needs basic information
  home.username = username;
  home.homeDirectory = "/home/${username}";

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
