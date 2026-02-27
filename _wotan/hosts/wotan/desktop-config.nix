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

  # Host-specific workspace configuration (bind workspaces to monitors)
  programs.hyprland.settings.workspace = [
    # Left monitor (DP-3) - workspaces 1-5
    "1, monitor:DP-3, default:true"
    "2, monitor:DP-3"
    "3, monitor:DP-3"
    "4, monitor:DP-3"
    "5, monitor:DP-3"
    # Right monitor (DP-2) - workspaces 6-10
    "6, monitor:DP-2, default:true"
    "7, monitor:DP-2"
    "8, monitor:DP-2"
    "9, monitor:DP-2"
    "10, monitor:DP-2"
  ];
}
