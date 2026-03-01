import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// App launcher dock - bottom center
PanelWindow {
  id: dock

  anchors {
    bottom: true
  }

  // Center horizontally
  margins {
    bottom: 10
  }

  implicitWidth: dockRow.implicitWidth + 24
  implicitHeight: 56
  color: "#1a1a1fdd"

  // Place above windows but allow click-through when not hovered
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.namespace: "quickshell-dock"

  // App definitions - customize these!
  property var apps: [
    { name: "Files", icon: "", command: "nemo" },
    { name: "Browser", icon: "", command: "brave" },
    { name: "Terminal", icon: "", command: "kitty" },
    { name: "Code", icon: "", command: "code" },
    { name: "Discord", icon: "󰙯", command: "discord" },
    { name: "Spotify", icon: "", command: "spotify" },
    { name: "Settings", icon: "", command: "gnome-control-center" }
  ]

  RowLayout {
    id: dockRow
    anchors.centerIn: parent
    spacing: 4

    Repeater {
      model: dock.apps

      Rectangle {
        id: appButton
        required property var modelData
        required property int index

        width: 44
        height: 44
        radius: 10
        color: mouseArea.containsMouse ? "#33ccff33" : "transparent"

        Behavior on color {
          ColorAnimation { duration: 150 }
        }

        Text {
          anchors.centerIn: parent
          text: appButton.modelData.icon
          color: mouseArea.containsMouse ? "#33ccff" : "#cfd6f4"
          font.family: "FiraCode Nerd Font"
          font.pixelSize: 24

          Behavior on color {
            ColorAnimation { duration: 150 }
          }
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onClicked: {
            Quickshell.execDetached(["sh", "-c", appButton.modelData.command])
          }
        }

        // Tooltip
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.top
          anchors.bottomMargin: 8
          width: tooltipText.implicitWidth + 16
          height: tooltipText.implicitHeight + 8
          radius: 6
          color: "#1a1a1fee"
          visible: mouseArea.containsMouse
          opacity: mouseArea.containsMouse ? 1 : 0

          Behavior on opacity {
            NumberAnimation { duration: 150 }
          }

          Text {
            id: tooltipText
            anchors.centerIn: parent
            text: appButton.modelData.name
            color: "#cfd6f4"
            font.family: "FiraCode Nerd Font"
            font.pixelSize: 11
          }
        }
      }
    }
  }
}
