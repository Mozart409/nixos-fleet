import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

// Focused window: app icon, class, and title. Only shows the window focused on
// *this* monitor, so the two bars don't both claim the same window.
BarModule {
  id: root

  required property var monitor

  // Compare by output name, not object identity: the toplevel's monitor and
  // the panel's monitor are looked up through different paths and are not
  // guaranteed to be the same wrapper object.
  readonly property var toplevel: {
    const active = Hyprland.activeToplevel;
    if (!active)
      return null;
    const here = monitor?.name ?? "";
    return (active.monitor?.name ?? "") === here ? active : null;
  }

  // `class` is only exposed through the raw IPC payload, not as a property.
  readonly property string appClass: toplevel?.lastIpcObject?.class ?? ""
  readonly property string title: toplevel?.title ?? ""

  visible: toplevel !== null
  filled: false

  // Middle-click closes, matching the usual taskbar convention. There is no
  // `hl.dsp.closewindow` -- that name silently resolves to nil and the
  // dispatch fails with "attempt to call a nil value". The real dispatcher is
  // `hl.dsp.window.close()`, which acts on the focused window; that is exactly
  // this widget's subject, so no address argument is needed.
  onClicked: mouse => {
    if (mouse.button === Qt.MiddleButton && toplevel)
      Hyprland.dispatch("hl.dsp.window.close()");
  }

  RowLayout {
    id: row
    spacing: 7

    IconImage {
      implicitSize: Theme.iconSize + 2
      // Guard the empty case: iconPath("") builds a request the icon loader
      // can't satisfy and logs a warning on every focus change.
      source: root.appClass === "" ? "" : Quickshell.iconPath(root.appClass.toLowerCase(), "application-x-executable")
      visible: status === Image.Ready
    }

    Text {
      text: root.appClass
      color: Theme.accent
      font.family: Theme.font
      font.pixelSize: Theme.smallSize
      font.bold: true
      visible: text !== ""
    }

    Text {
      Layout.maximumWidth: 320
      text: root.title
      color: Theme.subtext
      font.family: Theme.font
      font.pixelSize: Theme.smallSize
      elide: Text.ElideRight
      visible: text !== "" && text !== root.appClass
    }
  }
}
