import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Scope {
  id: root

  // Time singleton for clock
  SystemClock { id: clock }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData
      screen: modelData

      anchors {
        top: true
        left: true
        right: true
      }

      implicitHeight: 32
      color: "#1a1a1fdd"

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        // Left: Workspaces
        WorkspaceWidget {
          Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        }

        // Spacer
        Item { Layout.fillWidth: true }

        // Center: Clock
        ClockWidget {
          Layout.alignment: Qt.AlignCenter | Qt.AlignVCenter
          time: clock
        }

        // Spacer
        Item { Layout.fillWidth: true }

        // Right: System info
        RowLayout {
          Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
          spacing: 16

          SysInfoWidget {}
        }
      }
    }
  }
}
