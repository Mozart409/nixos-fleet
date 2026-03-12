import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RowLayout {
  id: gitWidget
  spacing: 8

  // Configurable scan path
  property string scanPath: "/home/amadeus/code"
  
  // Internal state
  property bool available: false
  property int dirtyCount: -1

  // Check if zinc_oxide is available
  Process {
    id: checkProc
    command: ["which", "zinc_oxide"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        gitWidget.available = this.text.trim().length > 0
        if (gitWidget.available) {
          scanProc.running = true
        }
      }
    }
  }

  // Scan for dirty repos
  Process {
    id: scanProc
    command: ["zinc_oxide", "--compact", "--path", gitWidget.scanPath]
    running: false

    stdout: StdioCollector {
      onStreamFinished: {
        let output = this.text.trim()
        let count = parseInt(output)
        gitWidget.dirtyCount = isNaN(count) ? 0 : count
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        // On error, set count to -1 to hide widget
        if (this.text.trim().length > 0) {
          gitWidget.dirtyCount = -1
        }
      }
    }
  }

  // Refresh timer (60 seconds)
  Timer {
    interval: 60000
    running: gitWidget.available
    repeat: true
    onTriggered: scanProc.running = true
  }

  // Only show if available and has a valid count
  visible: gitWidget.available && gitWidget.dirtyCount >= 0

  Rectangle {
    width: gitRow.width + 16
    height: 24
    radius: 6
    color: gitWidget.dirtyCount > 0 ? "#2a2a2f" : "transparent"
    border.width: gitWidget.dirtyCount > 0 ? 1 : 0
    border.color: gitWidget.dirtyCount > 0 ? "#f38ba8" : "transparent"

    RowLayout {
      id: gitRow
      anchors.centerIn: parent
      spacing: 6

      Text {
        text: ""
        color: gitWidget.dirtyCount > 0 ? "#f38ba8" : "#a6adc8"
        font.family: "FiraCode Nerd Font"
        font.pixelSize: 14
      }

      Text {
        text: gitWidget.dirtyCount >= 0 ? gitWidget.dirtyCount.toString() : "---"
        color: gitWidget.dirtyCount > 0 ? "#f38ba8" : "#cfd6f4"
        font.family: "FiraCode Nerd Font"
        font.pixelSize: 12
        font.bold: gitWidget.dirtyCount > 0
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        // Open terminal with full zinc_oxide output
        openTerminalProc.running = true
      }
    }
  }

  // Process to open terminal with details
  Process {
    id: openTerminalProc
    command: ["kitty", "--hold", "-e", "zinc_oxide", "--path", gitWidget.scanPath]
    running: false
  }
}
