import QtQuick
import Quickshell
import Quickshell.Io

// The bar's CPU / memory / GPU / disk readings, sampled once and shared by
// every screen's bar (Bar.qml creates one of these next to the clock). Each
// ResourceWidget used to run its own shell pipeline on its own timer, once
// per screen: with two screens that was 4 nvidia-smi launches every 2 s.
//
// /proc and /sys are read with FileView, no subprocess. The GPU comes from a
// single long-running `nvidia-smi -lms`, which prints one line per interval.
// Only disk still forks (`df`, once a minute): Quickshell has no statvfs.
Scope {
  id: root

  // Each reading keeps its own short history so a bar created later (a
  // monitor plugged in) starts with a full graph instead of an empty one.
  component Reading: QtObject {
    property real value: NaN
    property string sub: ""
    property var history: []

    function set(v, s) {
      value = v;
      if (s !== undefined)
        sub = s;
      if (isNaN(v))
        return;
      const next = history.slice();
      next.push(Math.max(0, v));
      while (next.length > 32)
        next.shift();
      history = next;
    }
  }

  readonly property Reading cpu: Reading {}
  readonly property Reading mem: Reading {}
  readonly property Reading gpu: Reading {}
  readonly property Reading diskFree: Reading {}

  // CPU --------------------------------------------------------------------
  // /proc/stat holds since-boot totals, so the busy share is the change
  // between two samples: 1 - d(idle) / d(total). idle includes iowait.
  property real _lastIdle: -1
  property real _lastTotal: -1
  property string _cpuTemp: ""

  FileView {
    id: statFile
    path: "/proc/stat"

    onLoaded: {
      const fields = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
      const idle = fields[3] + fields[4];
      const total = fields.reduce((a, b) => a + b, 0);
      const dTotal = total - root._lastTotal;
      const busy = root._lastTotal < 0 || dTotal <= 0 ? NaN : Math.max(0, Math.min(100, 100 * (1 - (idle - root._lastIdle) / dTotal)));
      root._lastIdle = idle;
      root._lastTotal = total;
      root.cpu.set(busy, root._cpuTemp);
    }
  }

  // hwmon numbers follow probe order and move between boots, so the k10temp
  // sensor is looked up by name -- once, not on every tick.
  Process {
    command: ["sh", "-c", "for h in /sys/class/hwmon/*; do [ \"$(cat $h/name 2>/dev/null)\" = k10temp ] && echo $h/temp1_input && break; done"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: tempFile.path = this.text.trim()
    }
  }

  FileView {
    id: tempFile
    onLoaded: {
      const milli = parseInt(text().trim());
      root._cpuTemp = isNaN(milli) ? "" : String(Math.round(milli / 1000));
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      statFile.reload();
      if (tempFile.path !== "")
        tempFile.reload();
    }
  }

  // Memory -----------------------------------------------------------------
  // Same figure as `free`'s used/total: MemTotal - MemAvailable.
  FileView {
    id: memFile
    path: "/proc/meminfo"

    onLoaded: {
      const kb = key => {
        const m = text().match(new RegExp("^" + key + ":\\s+(\\d+)", "m"));
        return m ? parseInt(m[1]) : NaN;
      };
      const total = kb("MemTotal");
      root.mem.set(100 * (total - kb("MemAvailable")) / total);
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: memFile.reload()
  }

  // GPU --------------------------------------------------------------------
  Process {
    id: gpuProc
    command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits", "-lms", "2000"]
    running: true

    stdout: SplitParser {
      onRead: line => {
        const [util, temp] = line.split(",").map(s => parseFloat(s));
        root.gpu.set(util, isNaN(temp) ? "" : String(temp));
      }
    }

    // It exits when the driver goes away (suspend, a driver reload). Start it
    // again rather than leave the pill frozen on its last reading.
    onExited: {
      root.gpu.set(NaN, "");
      gpuRestart.start();
    }
  }

  Timer {
    id: gpuRestart
    interval: 5000
    onTriggered: gpuProc.running = true
  }

  // Disk -------------------------------------------------------------------
  Process {
    id: diskProc
    command: ["sh", "-c", "df -P / | awk 'NR==2 {gsub(/%/, \"\", $5); printf \"%d\", 100 - $5}'"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: root.diskFree.set(parseFloat(this.text.trim()))
    }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: diskProc.running = true
  }
}
