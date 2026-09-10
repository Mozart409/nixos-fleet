import Quickshell

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

  // Homelab status board, one per screen, sitting on the wallpaper.
  HomelabWidget {}

  // Desktop widgets, off by default -- the bar covers the same ground.
  // SystemMonitorWidget {}
  // WeatherWidget {}

  // App dock (bottom centre).
  // DockWidget {}
}
