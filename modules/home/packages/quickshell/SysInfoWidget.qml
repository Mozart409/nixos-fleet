import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RowLayout {
  id: sysInfo
  spacing: 12

  // Threshold-based text colors ---------------------------------------------
  // Tweak the pivot numbers below to taste.
  readonly property color colOk: "#cfd6f4" // default / healthy
  readonly property color colWarn: "#f5c542" // caution
  readonly property color colCrit: "#ff6b6b" // critical

  // Usage metrics (CPU/RAM/GPU): higher = worse
  function usageColor(pct) {
    if (pct >= 85) return colCrit
    if (pct >= 60) return colWarn
    return colOk
  }

  // Free space: lower = worse (inverted)
  function freeColor(pct) {
    if (pct <= 15) return colCrit
    if (pct <= 30) return colWarn
    return colOk
  }

  // Screen temperature: tint warm (low K) vs cool (high K)
  function tempColor(k) {
    if (k <= 4000) return "#ff9e64" // warm / orange
    if (k >= 6000) return "#7dcfff" // cool / blue
    return colOk
  }

  // Measure the widest possible text to keep layout stable
  TextMetrics {
    id: sysMetrics
    font.family: "Berkeley Mono"
    font.pixelSize: 13
    text: " D 100%"
  }

  TextMetrics {
    id: tempMetrics
    font.family: "Berkeley Mono"
    font.pixelSize: 13
    text: " 10000K"
  }

  // Screen color temperature (hyprsunset)
  Text {
    id: tempText
    color: "#cfd6f4"
    font.family: "Berkeley Mono"
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
          let raw = this.text.trim()
          tempText.text = raw.length > 0 ? " " + raw + "K" : " ----K"
          if (raw.length > 0) tempText.color = sysInfo.tempColor(parseInt(raw))
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

  // Root disk free percentage
  Text {
    id: diskText
    color: "#cfd6f4"
    font.family: "Berkeley Mono"
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
          let val = parseFloat(this.text.trim())
          diskText.text = " D " + val.toFixed(0) + "%"
          diskText.color = sysInfo.freeColor(val)
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
    font.family: "Berkeley Mono"
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
          cpuText.color = sysInfo.usageColor(val)
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
    font.family: "Berkeley Mono"
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
          let val = parseFloat(this.text.trim())
          ramText.text = " M " + val.toFixed(0) + "%"
          ramText.color = sysInfo.usageColor(val)
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
    font.family: "Berkeley Mono"
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
          let val = parseFloat(this.text.trim())
          gpuText.text = " G " + val.toFixed(0) + "%"
          gpuText.color = sysInfo.usageColor(val)
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
