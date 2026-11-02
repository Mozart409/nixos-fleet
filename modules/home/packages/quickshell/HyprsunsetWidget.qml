import QtQuick
import Quickshell
import Quickshell.Io

// Screen colour temperature from the hyprsunset daemon, over its IPC socket
// (`hyprctl hyprsunset`, the same path the mod+H / mod+B binds use). Scroll
// to shift by 500K like those binds. When the daemon can't be reached the
// pill shows "--" instead of hiding, since that is exactly when the binds
// stop working -- and a click restarts the user unit.
//
// hyprsunset has no D-Bus interface and its socket is request/response only,
// so nothing announces a change. The binds in hyprland.lua push one instead
// (`qs ipc call hyprsunset refresh`); the slow poll only catches what nothing
// announces: the 21:00 profile switch, the daemon dying, a manual hyprctl.
BarModule {
  id: root

  readonly property int step: 500
  // -1 = daemon unreachable.
  property int kelvin: -1
  // Identity mode: the filter is off, whatever `kelvin` says.
  property bool identity: false

  icon: "󰖛"
  accent: {
    if (kelvin < 0 || identity)
      return Theme.muted;
    if (kelvin <= 4000)
      return Theme.peach;
    if (kelvin >= 6000)
      return Theme.accent;
    return Theme.warn;
  }

  onClicked: if (kelvin < 0)
    restartProc.running = true

  onWheel: wheel => {
    if (kelvin < 0)
      return;
    const sign = wheel.angleDelta.y > 0 ? "+" : "-";
    Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", sign + root.step]);
    reread.restart();
  }

  // Bar.qml creates this on the primary screen only, so there is exactly one
  // handler for the target.
  IpcHandler {
    target: "hyprsunset"

    function refresh(): void {
      readProc.running = true;
    }
  }

  Process {
    id: readProc
    command: ["sh", "-c", "hyprctl hyprsunset identity get; hyprctl hyprsunset temperature"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        // An unreachable daemon prints an error instead of a number, so only
        // a bare number counts.
        const lines = this.text.trim().split("\n").map(l => l.trim());
        const raw = lines[1] ?? "";
        root.identity = lines[0] === "true";
        root.kelvin = /^\d+$/.test(raw) ? parseInt(raw) : -1;
      }
    }
  }

  Process {
    id: restartProc
    command: ["systemctl", "--user", "restart", "hyprsunset.service"]
    running: false
    onExited: reread.restart()
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: readProc.running = true
  }

  // One-shot re-read shortly after a scroll or restart, so the number follows
  // the change without waiting for the next poll.
  Timer {
    id: reread
    interval: 300
    onTriggered: readProc.running = true
  }

  Text {
    text: root.kelvin < 0 ? "--" : (root.identity ? "off" : root.kelvin + "K")
    color: root.kelvin < 0 || root.identity ? Theme.muted : Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
  }
}
