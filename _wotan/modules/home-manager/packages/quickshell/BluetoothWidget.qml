import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

// Bluetooth state, and the battery level of whatever is connected when the
// device reports one. Hidden entirely when there is no adapter, so this costs
// nothing on machines without a radio.
//
// Left click toggles the adapter, right click opens bluetoothctl.
BarModule {
  id: root

  // blueman-manager is not installed on this host; bluetoothctl is, and it
  // can do everything the tray applet could.
  property string terminal: "kitty"

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)
  readonly property var primary: connected.length > 0 ? connected[0] : null
  readonly property bool enabled: adapter?.enabled ?? false

  visible: adapter !== null

  icon: {
    if (!enabled)
      return "󰂲";
    return connected.length > 0 ? "󰂱" : "󰂯";
  }
  accent: {
    if (!enabled)
      return Theme.muted;
    return connected.length > 0 ? Theme.accent : Theme.subtext;
  }

  onClicked: mouse => {
    if (mouse.button === Qt.LeftButton && adapter)
      adapter.enabled = !adapter.enabled;
    else if (mouse.button === Qt.RightButton)
      Quickshell.execDetached([terminal, "-e", "bluetoothctl"]);
  }

  Text {
    // One connected device gets named; several just get counted.
    text: {
      if (!root.enabled)
        return "off";
      if (root.connected.length === 0)
        return "";
      if (root.connected.length === 1)
        return root.primary.deviceName ?? root.primary.name ?? "";
      return root.connected.length + " devices";
    }
    color: Theme.subtext
    font.family: Theme.font
    font.pixelSize: Theme.smallSize
    elide: Text.ElideRight
    Layout.maximumWidth: 130
    visible: text !== ""
  }

  Text {
    // BlueZ reports battery as 0-100 only for devices that implement the
    // battery interface; most mice and headsets do, most speakers don't.
    readonly property int level: Math.round((root.primary?.battery ?? 0) * 100)

    text: `󰁹 ${level}%`
    color: level <= 20 ? Theme.crit : Theme.muted
    font.family: Theme.iconFont
    font.pixelSize: Theme.smallSize - 1
    visible: (root.primary?.batteryAvailable ?? false) && level > 0
  }
}
