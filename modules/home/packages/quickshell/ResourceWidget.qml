import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// One resource readout: icon, live percentage, and a scrolling history graph.
// The caller supplies the shell command; whatever it prints on stdout is
// parsed as a number and treated as a percentage unless `unit` says otherwise.
//
//   ResourceWidget {
//     icon: "󰍛"; label: "MEM"; interval: 5000
//     command: "free | awk '/Mem:/ {printf \"%.0f\", $3/$2 * 100}'"
//   }
BarModule {
  id: root

  required property string command
  property string label: ""
  property int interval: 2000
  property string unit: "%"
  // Secondary command whose output is appended after the main value, e.g. a
  // temperature next to a utilisation percentage. Optional.
  property string subCommand: ""
  property string subUnit: ""
  property bool graph: true
  // Set false for values where low is bad (free disk space).
  property bool higherIsWorse: true
  // Counter mode: the command prints two cumulative numbers, "idle total", and
  // the widget reports how much of the change *between polls* was not idle.
  // That is the only correct way to read /proc/stat -- the raw numbers are
  // since-boot totals, so a plain ratio would show a flat lifetime average.
  property bool counterMode: false

  readonly property real value: _value
  property real _value: NaN
  property string _sub: ""
  property real _lastIdle: -1
  property real _lastTotal: -1

  accent: isNaN(_value) ? Theme.muted : (higherIsWorse ? Theme.loadColor(_value) : Theme.headroomColor(_value))
  filled: false
  spacing: 5

  Process {
    id: proc
    command: ["sh", "-c", root.command]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        const out = this.text.trim();
        const parsed = root.counterMode ? root.consumeCounters(out) : parseFloat(out);
        root._value = isNaN(parsed) ? NaN : parsed;
        if (!isNaN(parsed) && root.graph)
          spark.push(parsed);
      }
    }
  }

  // Turns "idle total" into a busy percentage for this interval. Returns NaN
  // on the first sample, when there is no previous reading to diff against.
  function consumeCounters(out) {
    const parts = out.split(/\s+/);
    if (parts.length < 2)
      return NaN;
    const idle = parseFloat(parts[0]);
    const total = parseFloat(parts[1]);
    if (isNaN(idle) || isNaN(total))
      return NaN;

    const prevIdle = _lastIdle;
    const prevTotal = _lastTotal;
    _lastIdle = idle;
    _lastTotal = total;

    const dTotal = total - prevTotal;
    if (prevTotal < 0 || dTotal <= 0)
      return NaN;
    return Math.max(0, Math.min(100, 100 * (1 - (idle - prevIdle) / dTotal)));
  }

  Process {
    id: subProc
    command: ["sh", "-c", root.subCommand]
    running: root.subCommand !== ""

    stdout: StdioCollector {
      onStreamFinished: root._sub = this.text.trim()
    }
  }

  Timer {
    interval: root.interval
    running: true
    repeat: true
    onTriggered: {
      proc.running = true;
      if (root.subCommand !== "")
        subProc.running = true;
    }
  }

  Text {
    text: root.label
    color: Theme.muted
    font.family: Theme.font
    font.pixelSize: Theme.smallSize - 1
    visible: root.label !== ""
  }

  Text {
    // Reserve the width of the widest reading so the neighbouring modules
    // don't shuffle sideways every time the number changes digits.
    Layout.minimumWidth: widest.width
    horizontalAlignment: Text.AlignRight
    text: isNaN(root._value) ? "--" + root.unit : Math.round(root._value) + root.unit
    color: root.accent
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    font.bold: true

    Behavior on color {
      ColorAnimation {
        duration: Theme.anim
      }
    }
  }

  Text {
    text: root._sub + root.subUnit
    color: Theme.muted
    font.family: Theme.font
    font.pixelSize: Theme.smallSize - 1
    visible: root._sub !== ""
  }

  Sparkline {
    id: spark
    visible: root.graph
    stroke: root.accent
    maxValue: 100
  }

  TextMetrics {
    id: widest
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    font.bold: true
    text: "100" + root.unit
  }
}
