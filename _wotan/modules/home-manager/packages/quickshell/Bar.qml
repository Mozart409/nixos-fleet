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

      // Get the Hyprland monitor for this screen
      property var hyprMonitor: Hyprland.monitorFor(modelData)
      
      // Workspace ranges per monitor (customize as needed)
      // Monitor index 0: workspaces 6-9
      // Monitor index 1: workspaces 1-5
      property int monitorIndex: hyprMonitor?.id ?? 0
      property int wsStart: monitorIndex === 0 ? 6 : 1
      property int wsEnd: monitorIndex === 0 ? 9 : 5

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

        // Left: Workspaces (per-monitor range)
        WorkspaceWidget {
          Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
          startWorkspace: panel.wsStart
          endWorkspace: panel.wsEnd
          monitor: panel.hyprMonitor
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

        // Right: System info + Volume
        RowLayout {
          Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
          spacing: 16

          SysInfoWidget {}

          // Separator
          Rectangle {
            width: 1
            height: 16
            color: "#595959"
          }

          VolumeWidget {}
        }
      }
    }
  }
}
