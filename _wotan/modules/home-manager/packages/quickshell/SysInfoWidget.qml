import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RowLayout {
  spacing: 12

  // CPU usage
  Text {
    id: cpuText
    color: "#cfd6f4"
    font.family: "FiraCode Nerd Font"
    font.pixelSize: 13
    text: " ---%"

    Process {
      id: cpuProc
      command: ["sh", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print 100 - $8}'"]
      running: true

      stdout: StdioCollector {
        onStreamFinished: {
          let val = parseFloat(this.text.trim())
          cpuText.text = " " + val.toFixed(0) + "%"
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

  // RAM usage
  Text {
    id: ramText
    color: "#cfd6f4"
    font.family: "FiraCode Nerd Font"
    font.pixelSize: 13
    text: " ---%"

    Process {
      id: ramProc
      command: ["sh", "-c", "free | awk '/Mem:/ {printf \"%.0f\", $3/$2 * 100}'"]
      running: true

      stdout: StdioCollector {
        onStreamFinished: {
          ramText.text = " " + this.text.trim() + "%"
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
