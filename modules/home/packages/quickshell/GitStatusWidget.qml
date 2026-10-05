import QtQuick
import Quickshell
import Quickshell.Io

// How many repositories under `scanPath` have uncommitted work, via
// zinc_oxide. Stays hidden unless the tool is on PATH, so the bar degrades
// quietly on a machine that doesn't have it.
BarModule {
  id: root

  property string scanPath: "/home/amadeus/code"
  property string terminal: "kitty"

  property bool available: false
  property int dirtyCount: -1

  visible: available && dirtyCount >= 0
  icon: ""
  accent: dirtyCount > 0 ? Theme.peach : Theme.muted

  onClicked: if (available)
    Quickshell.execDetached([terminal, "--hold", "-e", "zinc_oxide", "--path", scanPath])

  Process {
    id: checkProc
    command: ["sh", "-c", "command -v zinc_oxide"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        root.available = this.text.trim().length > 0;
        if (root.available)
          scanProc.running = true;
      }
    }
  }

  Process {
    id: scanProc
    command: ["zinc_oxide", "--compact", "--path", root.scanPath]
    running: false

    stdout: StdioCollector {
      onStreamFinished: {
        const count = parseInt(this.text.trim());
        root.dirtyCount = isNaN(count) ? 0 : count;
      }
    }

    stderr: StdioCollector {
      onStreamFinished: if (this.text.trim().length > 0)
        root.dirtyCount = -1
    }
  }

  Timer {
    interval: 60000
    running: root.available
    repeat: true
    onTriggered: scanProc.running = true
  }

  Text {
    text: root.dirtyCount >= 0 ? root.dirtyCount : "--"
    color: root.dirtyCount > 0 ? Theme.peach : Theme.subtext
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    font.bold: root.dirtyCount > 0
  }
}
