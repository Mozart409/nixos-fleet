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
    ../../modules/home-manager/packages/browsers.nix
    ../../modules/home-manager/packages/security.nix
    ../../modules/home-manager/packages/fun.nix
    ../../modules/home-manager/packages/ironbar.nix
    ../../modules/home-manager/packages/waybar.nix
    ../../kickstart.nixvim/nixvim.nix
    ../../modules/home-manager/packages/tmux.nix
    ../../modules/home-manager/packages/terminals.nix
    ../../modules/home-manager/packages/yazi.nix
    ../../modules/home-manager/packages/opencode.nix
    ../../modules/home-manager/packages/hyprland-configs.nix
    ../../modules/home-manager/packages/rofi.nix
    ../../modules/home-manager/packages/podman.nix
    ../../modules/home-manager/packages/gtk.nix
    ../../modules/home-manager/packages/halloy.nix
    ../../modules/home-manager/packages/quickshell.nix
  ];

  desktop.waybar.enable = false;
  desktop.ironbar.enable = true;
  desktop.hyprland-configs.enable = true;
  desktop.rofi.enable = true;
  desktop.gtk.enable = true;
  desktop.quickshell.enable = false; # TODO: re-enable when lager/boost cmake issue is fixed upstream

  # Enable opencode custom commands
  opencode.enable = true;

  # Load CONTEXT7 API key from agenix secret file
  home.sessionVariablesExtra = ''
    if [ -n "$CONTEXT7_API_KEY_FILE" ] && [ -f "$CONTEXT7_API_KEY_FILE" ]; then
      export CONTEXT7_API_KEY=$(cat "$CONTEXT7_API_KEY_FILE")
    fi
  '';

  # Automatic Nix garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-generations +5";
  };

  # Host-specific home-manager packages can be added here
  # For example, if you want certain packages only on wotan:
  # home.packages = with pkgs; [
  #   host-specific-package
  # ];
}
