import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

RowLayout {
  id: workspaceWidget
  spacing: 4

  // Which workspaces to show (configurable per-monitor)
  property int startWorkspace: 1
  property int endWorkspace: 9

  // Reference to the monitor this widget is on
  property var monitor: null

  Repeater {
    model: workspaceWidget.endWorkspace - workspaceWidget.startWorkspace + 1

    Rectangle {
      id: wsButton
      required property int index

      property int wsId: workspaceWidget.startWorkspace + index
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
        font.family: "FiraCode Nerd Font"
        font.pixelSize: 12
        font.bold: wsButton.isActive
      }

      MouseArea {
        anchors.fill: parent
        onClicked: Hyprland.dispatch("workspace " + wsButton.wsId)
      }
    }
  }
}
