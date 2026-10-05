import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Generated

// Top bar, one instance per connected screen.
//
// Layout is three groups: workspaces and the focused window on the left, the
// clock dead centre, and the status cluster on the right. The centre group is
// positioned against the panel rather than placed between two stretchy
// spacers, so the clock stays put when the window title changes length.
Scope {
  id: root

  SystemClock {
    id: clock
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData
      screen: modelData

      // Which workspaces belong on this bar. Resolved by output name (DP-3,
      // DP-2, ...), never by Hyprland's monitor id: the ids are assigned in
      // output-enable order and swap between sessions, which silently puts the
      // wrong workspace set on each bar. modelData.name is the connector name
      // and is available before Hyprland reports the monitor, so it is the key.
      readonly property string outputName: modelData.name
      readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
      readonly property var workspaceIds: WorkspaceLayout.byMonitor[outputName] ?? WorkspaceLayout.fallback
      // Widgets that should exist exactly once across all screens live here.
      readonly property bool isPrimary: outputName === WorkspaceLayout.primary

      anchors {
        top: true
        left: true
        right: true
      }

      implicitHeight: Theme.barHeight
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Top

      Rectangle {
        anchors.fill: parent
        color: Theme.bar

        // Hairline under the bar to separate it from whatever is behind.
        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: 1
          color: Qt.alpha(Theme.accent, 0.12)
        }
      }

      // Left ------------------------------------------------------------
      RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: Theme.groupGap
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        WorkspaceWidget {
          workspaceIds: panel.workspaceIds
          monitor: panel.hyprMonitor
        }

        GitStatusWidget {
          visible: panel.isPrimary
          scanPath: "/home/amadeus/code"
        }

        // Focused window title. Available but not wired up -- see
        // ActiveWindowWidget.qml.
        // ActiveWindowWidget { monitor: panel.hyprMonitor }
      }

      // Centre ----------------------------------------------------------
      ClockWidget {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        time: clock
      }

      // Right -----------------------------------------------------------
      RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: Theme.groupGap
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        MediaWidget {
          // Keep the right-hand cluster clear of the centred clock: the title
          // is the only elastic thing here, so it is what gives way on a
          // narrow screen.
          maxLabelWidth: Math.max(70, Math.min(210, panel.width * 0.09))
        }

        // System tray. Disabled -- the only items on this machine are
        // nm-applet and Steam, and their dropdown menus are not wanted.
        // Re-enabling it also needs `//@ pragma UseQApplication` back in
        // shell.qml, or every tray click fails silently.
        // SystemTrayWidget {}

        // Bluetooth and audio share a pill so the bar doesn't read as a row of
        // disconnected numbers. Nothing in the bar reports network state now
        // -- NetworkWidget.qml is still here if that turns out to be missed.
        ModuleGroup {
          BluetoothWidget {
            filled: false
          }

          VolumeWidget {
            filled: false
          }
        }

        // Resource cluster. Each entry polls its own command on its own
        // cadence -- disk barely moves, GPU does.
        ModuleGroup {
          itemSpacing: 6

          ResourceWidget {
            icon: "󰻠"
            interval: 2000
            counterMode: true
            command: "awk '/^cpu /{idle=$5+$6; total=0; for (i=2; i<=NF; i++) total+=$i; print idle, total; exit}' /proc/stat"
            // hwmon numbers are handed out in probe order and move between
            // boots, so find the AMD CPU sensor by name rather than by index.
            subCommand: "for h in /sys/class/hwmon/*; do [ \"$(cat $h/name 2>/dev/null)\" = k10temp ] && awk '{printf \"%d\", $1/1000}' \"$h/temp1_input\" && break; done"
            subUnit: "°"
          }

          ResourceWidget {
            icon: ""
            interval: 5000
            command: "free | awk '/Mem:/ {printf \"%.0f\", $3/$2 * 100}'"
          }

          ResourceWidget {
            icon: "󰢮"
            interval: 2000
            command: "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1"
            subCommand: "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -1"
            subUnit: "°"
          }

          ResourceWidget {
            icon: "󰋊"
            interval: 60000
            graph: false
            higherIsWorse: false
            command: "df -P / | awk 'NR==2 {gsub(/%/, \"\", $5); printf \"%d\", 100 - $5}'"
          }
        }

        PowerMenu {}
      }
    }
  }
}
