import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Floating system monitor widget - bottom right corner
PanelWindow {
  id: sysMonitor

  // Position in bottom-right corner
  anchors {
    bottom: true
    right: true
  }

  margins {
    bottom: 60
    right: 20
  }

  implicitWidth: 200
  implicitHeight: 120
  color: "transparent"

  // White border container
  Rectangle {
    anchors.fill: parent
    color: "#1a1a1fcc"
    radius: 8
    border.width: 1
    border.color: "#ffffff44"
  }

  // Place below normal windows (desktop widget)
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "quickshell-sysmonitor"

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 12
    spacing: 8

    // Header
    Text {
      text: "System Monitor"
      color: "#33ccff"
      font.family: "FiraCode Nerd Font"
      font.pixelSize: 12
      font.bold: true
    }

    // CPU Bar
    ColumnLayout {
      spacing: 2
      Layout.fillWidth: true

      RowLayout {
        Text {
          text: " CPU"
          color: "#cfd6f4"
          font.family: "FiraCode Nerd Font"
          font.pixelSize: 11
        }
        Item { Layout.fillWidth: true }
        Text {
          id: cpuPercent
          text: "--%"
          color: "#cfd6f4"
          font.family: "FiraCode Nerd Font"
          font.pixelSize: 11
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 6
        radius: 3
        color: "#2a2a2f"

        Rectangle {
          id: cpuBar
          width: 0
          height: parent.height
          radius: 3
          color: "#33ccff"
        }
      }

      Process {
        id: cpuProc
        command: ["sh", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print 100 - $8}'"]
        running: true

        stdout: StdioCollector {
          onStreamFinished: {
            let val = parseFloat(this.text.trim())
            cpuPercent.text = val.toFixed(0).padStart(3, ' ') + "%"
            cpuBar.width = (val / 100) * cpuBar.parent.width
          }
        }
      }

      Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: cpuProc.running = true
      }
    }

    // RAM Bar
    ColumnLayout {
      spacing: 2
      Layout.fillWidth: true

      RowLayout {
        Text {
          text: " RAM"
          color: "#cfd6f4"
          font.family: "FiraCode Nerd Font"
          font.pixelSize: 11
        }
        Item { Layout.fillWidth: true }
        Text {
          id: ramPercent
          text: "--%"
          color: "#cfd6f4"
          font.family: "FiraCode Nerd Font"
          font.pixelSize: 11
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 6
        radius: 3
        color: "#2a2a2f"

        Rectangle {
          id: ramBar
          width: 0
          height: parent.height
          radius: 3
          color: "#00ff99"
        }
      }

      Process {
        id: ramProc
        command: ["sh", "-c", "free | awk '/Mem:/ {printf \"%.0f\", $3/$2 * 100}'"]
        running: true

        stdout: StdioCollector {
          onStreamFinished: {
            let val = parseFloat(this.text.trim())
            ramPercent.text = val.toFixed(0).padStart(3, ' ') + "%"
            ramBar.width = (val / 100) * ramBar.parent.width
          }
        }
      }

      Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: ramProc.running = true
      }
    }
  }
}
