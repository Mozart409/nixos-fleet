pragma Singleton

import QtQuick
import Quickshell.Hyprland
import Generated

// Whether the desktop panels (HomelabWidget, HomeAssistantWidget, ...) can be
// seen at all. They sit on WlrLayer.Bottom, under every window, so they only
// show on a workspace with no windows. Their refresh timers run only while
// that is true, and each panel refreshes the moment it is revealed, so the
// data is current when you look and nothing polls while you can't.
//
// A workspace with a single small floating window counts as covered: the
// panel is paused until that window closes or you switch to an empty one.
QtObject {
  function isEmpty(monitor) {
    return (monitor?.activeWorkspace?.toplevels?.values?.length ?? 1) === 0;
  }

  // Some monitor shows an empty workspace (panels that live on every screen).
  readonly property bool anyVisible: Hyprland.monitors.values.some(m => isEmpty(m))

  // The primary monitor shows an empty workspace (primary-only panels).
  readonly property bool primaryVisible: Hyprland.monitors.values.some(m => m.name === WorkspaceLayout.primary && isEmpty(m))
}
