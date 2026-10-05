import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// On-screen volume display. Appears on the focused monitor whenever the sink
// volume or mute state changes -- including from media keys and other apps,
// because it watches the PipeWire node rather than any keybind.
//
// `exclusionMode: Ignore` keeps it from reserving screen space and an empty
// input mask lets clicks fall through to whatever is underneath.
//
// Note for anyone editing this file: the layershell properties below
// (`layer`, `keyboardFocus`, `exclusionMode`) are read when the window is
// created, and a hot reload reuses the existing window rather than rebuilding
// it. Changes to them only take effect after `systemctl --user restart
// quickshell` -- if the OSD stops appearing, or appears under a fullscreen
// window, restart before assuming the code is wrong.
Scope {
  id: root

  // True from the moment a change arrives until the hide animation finishes;
  // the window stays mapped for that whole span so the fade-out is visible.
  property bool showing: false
  property bool mapped: false

  property real lastVolume: -1
  property bool lastMuted: false

  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real volume: sink?.audio?.volume ?? 0
  readonly property bool muted: sink?.audio?.mute ?? false

  onVolumeChanged: root.trigger()
  onMutedChanged: root.trigger()

  // The `lastVolume < 0` guard suppresses the popup on the first evaluation
  // after a config reload -- that is a change from "nothing known" rather than
  // something the user did.
  function trigger() {
    if (lastVolume < 0) {
      lastVolume = volume;
      lastMuted = muted;
      return;
    }
    if (volume === lastVolume && muted === lastMuted)
      return;
    lastVolume = volume;
    lastMuted = muted;

    mapped = true;
    showing = true;
    hideTimer.restart();
  }

  Timer {
    id: hideTimer
    interval: 1400
    onTriggered: root.showing = false
  }

  // Unmap only after the fade-out has finished playing.
  Timer {
    id: unmapTimer
    interval: Theme.animSlow + 60
    onTriggered: if (!root.showing)
      root.mapped = false
  }

  onShowingChanged: if (!showing)
    unmapTimer.restart()

  PanelWindow {
    id: osd
    visible: root.mapped

    // Follow the focused screen so the OSD shows up where you are looking.
    screen: {
      const focused = Hyprland.focusedMonitor?.name ?? "";
      for (const s of Quickshell.screens)
        if (s.name === focused)
          return s;
      return null;
    }

    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    margins.bottom: 140
    implicitWidth: 320
    implicitHeight: 64
    color: "transparent"

    Rectangle {
      anchors.fill: parent
      radius: 14
      color: Theme.surface
      border.width: 1
      border.color: Qt.alpha(Theme.accent, 0.25)

      // Driven off `showing`, not `visible`, so both directions animate.
      opacity: root.showing ? 1 : 0
      scale: root.showing ? 1 : 0.9

      Behavior on opacity {
        NumberAnimation {
          duration: Theme.animSlow
          easing.type: Easing.OutCubic
        }
      }
      Behavior on scale {
        NumberAnimation {
          duration: Theme.animSlow
          easing.type: Easing.OutBack
        }
      }

      Text {
        id: osdIcon
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        text: {
          if (root.muted || root.volume === 0)
            return "󰝟";
          if (root.volume < 0.34)
            return "󰕿";
          if (root.volume < 0.67)
            return "󰖀";
          return "󰕾";
        }
        color: root.muted ? Theme.muted : Theme.accent
        font.family: Theme.iconFont
        font.pixelSize: 24
      }

      Text {
        id: osdPct
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        text: root.muted ? "muted" : Math.round(root.volume * 100) + "%"
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 15
        font.bold: true
      }

      Rectangle {
        anchors.left: osdIcon.right
        anchors.leftMargin: 16
        anchors.right: osdPct.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: Theme.module

        Rectangle {
          width: parent.width * Math.min(1, root.volume)
          height: parent.height
          radius: 3
          color: root.muted ? Theme.muted : Theme.accent

          Behavior on width {
            NumberAnimation {
              duration: Theme.anim
              easing.type: Easing.OutCubic
            }
          }
        }
      }
    }
  }
}
