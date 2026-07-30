import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

RowLayout {
  id: workspaceWidget
  spacing: 4

  // Workspace numbers to show, in order. Comes from WorkspaceLayout.qml, which
  // quickshell.nix generates from the same option that writes Hyprland's
  // workspace rules, so the bar cannot disagree with the compositor.
  property var workspaceIds: []

  // Reference to the monitor this widget is on
  property var monitor: null

  Repeater {
    model: workspaceWidget.workspaceIds

    Rectangle {
      id: wsButton
      required property int modelData

      property int wsId: modelData
      property bool isActive: workspaceWidget.monitor?.activeWorkspace?.id === wsId
      property bool hasWindows: {
        for (let ws of Hyprland.workspaces.values) {
          if (ws.id === wsId && ws.windows > 0) return true
        }
        return false
      }

      width: 24
      height: 24
      radius: 6
      color: isActive ? "#33ccff" : (hasWindows ? "#2a2a2f" : "transparent")
      border.width: hasWindows && !isActive ? 1 : 0
      border.color: "#595959"

      Text {
        anchors.centerIn: parent
        text: wsButton.wsId
        color: wsButton.isActive ? "#1a1a1f" : "#cfd6f4"
        font.family: "Berkeley Mono"
        font.pixelSize: 12
        font.bold: wsButton.isActive
      }

      MouseArea {
        anchors.fill: parent
        // Hyprland 0.56 evaluates IPC dispatch as Lua (`return hl.dispatch(<arg>)`),
        // so the old hyprlang "workspace N" string is a syntax error. Pass the Lua
        // dispatcher object instead, matching hl.dsp.focus in hyprland.lua.
        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsButton.wsId + " })")
      }
    }
  }
}
