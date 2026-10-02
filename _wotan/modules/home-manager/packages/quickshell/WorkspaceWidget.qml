import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

// Workspace pills for one monitor.
//
// The active workspace is drawn as a single sliding highlight behind the row
// rather than by recolouring each button, which is what gives the indicator
// its travel animation when you switch.
Item {
  id: root

  // Workspace numbers to show, in order. Comes from the generated
  // Generated.WorkspaceLayout singleton, which quickshell.nix renders from the
  // same option that writes Hyprland's workspace rules -- so the bar cannot
  // disagree with the compositor.
  property var workspaceIds: []
  // HyprlandMonitor this widget is drawn on.
  property var monitor: null

  readonly property int dotSize: 26

  implicitWidth: row.implicitWidth + 8
  implicitHeight: Theme.moduleHeight + 4

  Rectangle {
    anchors.fill: parent
    radius: Theme.radius
    color: Theme.module
  }

  // Sliding active indicator. Positioned against the button the compositor
  // currently reports as active; `Behavior` turns every switch into a glide.
  Rectangle {
    id: indicator

    property Item target: null

    visible: target !== null
    x: target ? row.x + target.x : 0
    y: (root.height - height) / 2
    width: target ? target.width : 0
    height: root.dotSize
    radius: Theme.radius - 1
    color: Theme.accent

    Behavior on x {
      NumberAnimation {
        duration: Theme.animSlow
        easing.type: Easing.OutBack
        easing.overshoot: 0.9
      }
    }
    Behavior on width {
      NumberAnimation {
        duration: Theme.animSlow
        easing.type: Easing.OutCubic
      }
    }
  }

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 2

    Repeater {
      model: root.workspaceIds

      Item {
        id: wsButton
        required property int modelData

        readonly property int wsId: modelData

        // Hyprland's workspace list only contains workspaces that exist, so a
        // never-used workspace has no entry at all -- absence means empty.
        readonly property var ws: {
          for (const w of Hyprland.workspaces.values)
            if (w.id === wsId)
              return w;
          return null;
        }
        // HyprlandWorkspace has no `windows` count; the toplevel model is the
        // supported way to ask whether anything lives here.
        // A fullscreen window also counts, in case the toplevel model lags the
        // fullscreen event.
        readonly property bool fullscreen: ws?.hasFullscreen ?? false
        readonly property bool occupied: fullscreen || (ws?.toplevels?.values?.length ?? 0) > 0
        readonly property bool urgent: ws?.urgent ?? false
        readonly property bool isActive: root.monitor?.activeWorkspace?.id === wsId

        // The active pill widens to fit the label; the rest stay square dots.
        implicitWidth: isActive ? label.implicitWidth + 16 : root.dotSize
        implicitHeight: root.dotSize

        Behavior on implicitWidth {
          NumberAnimation {
            duration: Theme.animSlow
            easing.type: Easing.OutCubic
          }
        }

        onIsActiveChanged: if (isActive)
          indicator.target = wsButton
        Component.onCompleted: if (isActive)
          indicator.target = wsButton

        // Urgency ring -- drawn behind the label, pulses until you look at it.
        Rectangle {
          anchors.fill: parent
          radius: Theme.radius - 1
          color: "transparent"
          border.width: 1
          border.color: Theme.crit
          visible: wsButton.urgent && !wsButton.isActive

          SequentialAnimation on opacity {
            running: wsButton.urgent && !wsButton.isActive
            loops: Animation.Infinite
            NumberAnimation {
              to: 0.25
              duration: 700
              easing.type: Easing.InOutQuad
            }
            NumberAnimation {
              to: 1.0
              duration: 700
              easing.type: Easing.InOutQuad
            }
          }
        }

        Text {
          id: label
          anchors.centerIn: parent
          text: wsButton.wsId
          color: {
            if (wsButton.isActive)
              return Theme.inverse;
            if (wsButton.urgent)
              return Theme.crit;
            return wsButton.occupied ? Theme.text : Theme.muted;
          }
          font.family: Theme.font
          font.pixelSize: Theme.smallSize
          font.bold: wsButton.isActive || wsButton.occupied

          Behavior on color {
            ColorAnimation {
              duration: Theme.anim
            }
          }
        }

        // Occupancy dot under an inactive workspace that has windows on it.
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 3
          // Fullscreen (video, game) gets a larger peach bar.
          width: wsButton.fullscreen ? 10 : 4
          height: wsButton.fullscreen ? 3 : 2
          radius: height / 2
          color: wsButton.fullscreen ? Theme.peach : Theme.accent
          visible: wsButton.occupied && !wsButton.isActive
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          // Hyprland 0.56 evaluates IPC dispatch as Lua (`return hl.dispatch(<arg>)`),
          // so the old hyprlang "workspace N" string is a syntax error. Pass the
          // Lua dispatcher object instead, matching hl.dsp.focus in hyprland.lua.
          onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${wsButton.wsId} })`)
        }
      }
    }
  }

  // Scrolling anywhere on the group steps through this monitor's workspaces.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    onWheel: wheel => {
      const ids = root.workspaceIds;
      const current = ids.indexOf(root.monitor?.activeWorkspace?.id ?? -1);
      if (current < 0 || ids.length === 0)
        return;
      const next = wheel.angleDelta.y < 0 ? Math.min(ids.length - 1, current + 1) : Math.max(0, current - 1);
      if (next !== current)
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${ids[next]} })`);
    }
  }
}
