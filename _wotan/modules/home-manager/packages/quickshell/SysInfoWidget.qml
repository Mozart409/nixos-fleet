import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RowLayout {
  spacing: 12

  // Root disk free percentage
  Text {
    id: diskText
    color: "#cfd6f4"
    font.family: "FiraCode Nerd Font"
    font.pixelSize: 13
    text: " D ---%"

    Process {
      id: diskProc
      command: ["sh", "-c", "df -P / | awk 'NR==2 {gsub(/%/, \"\", $5); printf \"%d\", 100 - $5}'"]
      running: true

      stdout: StdioCollector {
        onStreamFinished: {
          diskText.text = " D " + this.text.trim() + "%"
        }
      }
    }

    Timer {
      interval: 10000
      running: true
      repeat: true
      onTriggered: diskProc.running = true
    }
  }

  // CPU usage
  Text {
    id: cpuText
    color: "#cfd6f4"
    font.family: "FiraCode Nerd Font"
    font.pixelSize: 13
    text: " C ---%"

    Process {
      id: cpuProc
      command: ["sh", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print 100 - $8}'"]
      running: true

      stdout: StdioCollector {
        onStreamFinished: {
          let val = parseFloat(this.text.trim())
          cpuText.text = " C " + val.toFixed(0) + "%"
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
    text: " M ---%"

    Process {
      id: ramProc
      command: ["sh", "-c", "free | awk '/Mem:/ {printf \"%.0f\", $3/$2 * 100}'"]
      running: true

      stdout: StdioCollector {
        onStreamFinished: {
          ramText.text = " M " + this.text.trim() + "%"
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
