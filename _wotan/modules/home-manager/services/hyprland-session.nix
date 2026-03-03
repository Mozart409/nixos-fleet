{
  config,
  lib,
  ...
}: {
  # Shared Hyprland systemd session target
  # This target is used by multiple home-manager modules (ironbar, quickshell, etc.)
  # to coordinate service startup after Hyprland is ready
  systemd.user.targets.hyprland-session = lib.mkIf (config.desktop.ironbar.enable || config.desktop.quickshell.enable) {
    Unit = {
      Description = "Hyprland compositor session";
      Documentation = "man:systemd.special(7)";
      BindsTo = ["graphical-session.target"];
      Wants = ["graphical-session-pre.target"];
      After = ["graphical-session-pre.target"];
    };
  };
}
