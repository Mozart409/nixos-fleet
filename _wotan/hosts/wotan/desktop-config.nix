{
  pkgs,
  inputs,
  ...
}: {
  desktop.environment = "hyprland";

  # Host-specific monitor configuration
  desktop.hyprland.monitors = [
    "DP-3,2560x1440@144,0x0,1"
    "DP-2,2560x1440@144,2560x0,1"
  ];
}
