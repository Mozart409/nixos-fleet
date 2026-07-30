import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Scope {
  id: root

  // Time singleton for clock
  SystemClock { id: clock }

  // Generated from desktop.hyprland-configs.workspaces by quickshell.nix.
  WorkspaceLayout { id: wsLayout }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData
      screen: modelData

      // Get the Hyprland monitor for this screen
      property var hyprMonitor: Hyprland.monitorFor(modelData)
      
      // Which workspaces belong on this bar. Resolved by output name (DP-3,
      // DP-2, ...), never by Hyprland's monitor id: the ids are assigned in
      // output-enable order and swap between sessions, which silently put the
      // wrong workspace set on each bar. modelData.name is the connector name
      // and is available before Hyprland reports the monitor, so it is the key.
      property string outputName: modelData.name
      property var workspaceIds: wsLayout.byMonitor[outputName] ?? wsLayout.fallback

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
          workspaceIds: panel.workspaceIds
          monitor: panel.hyprMonitor
        }

        // Git status widget (only on primary monitor)
        Loader {
          Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
          active: panel.outputName === wsLayout.primary
          sourceComponent: GitStatusWidget {
            scanPath: "/home/amadeus/code"
          }
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
