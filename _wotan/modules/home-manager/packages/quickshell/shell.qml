//@ pragma UseQApplication

import Quickshell

// UseQApplication is required for system tray menus. Tray items expose their
// menus as Qt platform menus, and without QApplication mode every click on a
// tray icon fails with "Cannot display PlatformMenuEntry as quickshell was not
// started in QApplication mode" -- which looks exactly like the icon being
// dead. Changing this pragma needs a full `systemctl --user restart
// quickshell`; a hot reload will not pick it up.
ShellRoot {
  // Top status bar, one per screen.
  Bar {}

  // Floating volume display, follows the focused monitor.
  VolumeOsd {}

  // Desktop widgets, off by default -- the bar covers the same ground.
  // SystemMonitorWidget {}
  // WeatherWidget {}

  // App dock (bottom centre).
  // DockWidget {}
}
