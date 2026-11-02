import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Generated

// If SystemTrayWidget is ever re-enabled in Bar.qml, `//@ pragma
// UseQApplication` has to go back as the very first line of this file. Tray
// menus are Qt platform menus and need QApplication mode; without it every
// tray click fails with "Cannot display PlatformMenuEntry", logged to the
// service journal and invisible on screen. It is left off here because
// QApplication mode pulls in QtWidgets for no other benefit.
ShellRoot {
  // Top status bar, one per screen.
  Bar {}

  // Floating volume display, follows the focused monitor.
  VolumeOsd {}

  // Notification daemon. Only built when nix selected this backend --
  // desktop.notifications.backend = "quickshell". With dunst selected, the
  // component is never instantiated and never touches the bus.
  LazyLoader {
    active: Features.notifications

    NotificationDaemon {}
  }

  // Homelab status board, one per screen, sitting on the wallpaper.
  HomelabWidget {}

  // Home Assistant light toggles, top-left on the primary screen. Gated like
  // the notification daemon: without desktop.quickshell.homeAssistant the
  // quickshell-ha script does not exist.
  LazyLoader {
    active: Features.homeAssistant

    HomeAssistantWidget {}
  }

  // System unit toggles (wotan: the on-demand AI services), bottom-left on
  // the primary screen. Gated the same way: without
  // desktop.quickshell.serviceToggles there is no quickshell-units script.
  LazyLoader {
    active: Features.serviceToggles

    ServiceTogglesWidget {}
  }

  // Flake input drift, bottom-right so it cannot collide with the homelab
  // board above however tall that grows.
  DepsWidget {}

  // `qs ipc call hyprland refresh`: re-read monitors, workspaces and windows
  // from Hyprland. hyprland.lua's monitor-swap bind relabels workspaces with
  // change_id, which sends no event quickshell handles, so the bar would keep
  // counting windows on their pre-swap buttons until told.
  IpcHandler {
    target: "hyprland"

    function refresh(): void {
      Hyprland.refreshMonitors();
      Hyprland.refreshWorkspaces();
      Hyprland.refreshToplevels();
    }
  }
}
