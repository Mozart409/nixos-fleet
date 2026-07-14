import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RowLayout {
  spacing: 12

  // Measure the widest possible text to keep layout stable
  TextMetrics {
    id: sysMetrics
    font.family: "FiraCode Nerd Font"
    font.pixelSize: 13
    text: " D 100%"
  }

  TextMetrics {
    id: tempMetrics
    font.family: "FiraCode Nerd Font"
    font.pixelSize: 13
    text: " 10000K"
  }

  // Root disk free percentage
  Text {
    id: diskText
    color: "#cfd6f4"
    font.family: "FiraCode Nerd Font"
    font.pixelSize: 13
    horizontalAlignment: Text.AlignRight
    Layout.minimumWidth: sysMetrics.width
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

  // Screen color temperature (hyprsunset)
  Text {
    id: tempText
    color: "#cfd6f4"
    font.family: "FiraCode Nerd Font"
    font.pixelSize: 13
    horizontalAlignment: Text.AlignRight
    Layout.minimumWidth: tempMetrics.width
    text: " ----K"

    Process {
      id: tempProc
      command: ["sh", "-c", "hyprctl hyprsunset temperature | tr -d '[:space:]'"]
      running: true

      stdout: StdioCollector {
        onStreamFinished: {
          let val = this.text.trim()
          tempText.text = val.length > 0 ? " " + val + "K" : " ----K"
        }
      }
    }

    Timer {
      interval: 2000
      running: true
      repeat: true
      onTriggered: tempProc.running = true
    }
  }

  // CPU usage
  Text {
    id: cpuText
    color: "#cfd6f4"
    font.family: "FiraCode Nerd Font"
    font.pixelSize: 13
    horizontalAlignment: Text.AlignRight
    Layout.minimumWidth: sysMetrics.width
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
    horizontalAlignment: Text.AlignRight
    Layout.minimumWidth: sysMetrics.width
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

  // GPU usage
  Text {
    id: gpuText
    color: "#cfd6f4"
    font.family: "FiraCode Nerd Font"
    font.pixelSize: 13
    horizontalAlignment: Text.AlignRight
    Layout.minimumWidth: sysMetrics.width
    text: " G ---%"

    Process {
      id: gpuProc
      command: ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | awk '{printf \"%d\", $1}'"]
      running: true

      stdout: StdioCollector {
        onStreamFinished: {
          gpuText.text = " G " + this.text.trim() + "%"
        }
      }
    }

    Timer {
      interval: 2000
      running: true
      repeat: true
      onTriggered: gpuProc.running = true
    }
  }
}
