import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

RowLayout {
  spacing: 4

  Repeater {
    // Show workspaces 1-9
    model: 9

    Rectangle {
      id: wsButton
      required property int index

      property int wsId: index + 1
      property bool isActive: Hyprland.focusedMonitor?.activeWorkspace?.id === wsId
      property bool hasWindows: {
        for (let ws of Hyprland.workspaces) {
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
