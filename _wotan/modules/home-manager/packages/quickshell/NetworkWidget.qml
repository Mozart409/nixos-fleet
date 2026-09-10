import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Link state plus live throughput.
//
// NetworkManager (via Quickshell.Networking) supplies the device, its type and
// its address; the byte counters come from /sys, which is cheaper and finer
// grained than asking NM. Rates are deltas between polls, so the first tick
// after a reload reads zero.
BarModule {
  id: root

  // Prefer whichever managed device is actually connected. Wired wins over
  // wifi when both are up, which matches how the routing table resolves.
  readonly property var device: {
    let wifi = null;
    for (const d of Networking.devices.values) {
      if (!d.connected)
        continue;
      if (d.type === DeviceType.Wired)
        return d;
      if (d.type === DeviceType.Wifi)
        wifi = d;
    }
    return wifi;
  }

  readonly property bool wired: device?.type === DeviceType.Wired
  readonly property bool online: device?.connected ?? false

  property real rxRate: 0 // bytes/sec
  property real txRate: 0
  property real _lastRx: -1
  property real _lastTx: -1

  readonly property int pollMs: 1500

  icon: {
    if (!online)
      return "󰤭";
    return wired ? "󰈀" : "󰖩";
  }
  accent: online ? Theme.good : Theme.crit

  // Terminal used for the click action. nmtui ships with NetworkManager and
  // is already on PATH -- nm-connection-editor is not installed on this host,
  // and a bar widget should not be the reason a GTK app gets pulled in.
  property string terminal: "kitty"

  onClicked: mouse => {
    if (mouse.button === Qt.LeftButton)
      Quickshell.execDetached([terminal, "-e", "nmtui"]);
  }

  function humanRate(bytesPerSec) {
    const kb = bytesPerSec / 1024;
    if (kb < 1)
      return "0K";
    if (kb < 1000)
      return Math.round(kb) + "K";
    return (kb / 1024).toFixed(kb / 1024 < 10 ? 1 : 0) + "M";
  }

  Process {
    id: counters
    // Both counters in one read so rx and tx always come from the same instant.
    command: ["sh", "-c", root.device ? `cat /sys/class/net/${root.device.name}/statistics/rx_bytes /sys/class/net/${root.device.name}/statistics/tx_bytes` : "echo; echo"]
    running: false

    stdout: StdioCollector {
      onStreamFinished: {
        const parts = this.text.trim().split("\n");
        if (parts.length < 2)
          return;
        const rx = parseFloat(parts[0]);
        const tx = parseFloat(parts[1]);
        if (isNaN(rx) || isNaN(tx))
          return;

        const seconds = root.pollMs / 1000;
        if (root._lastRx >= 0) {
          root.rxRate = Math.max(0, (rx - root._lastRx) / seconds);
          root.txRate = Math.max(0, (tx - root._lastTx) / seconds);
        }
        root._lastRx = rx;
        root._lastTx = tx;
      }
    }
  }

  Timer {
    interval: root.pollMs
    running: root.device !== null
    repeat: true
    triggeredOnStart: true
    onTriggered: counters.running = true
  }

  // Reset the baseline when the interface changes, otherwise the first delta
  // is the difference between two unrelated counters and spikes absurdly.
  onDeviceChanged: {
    _lastRx = -1;
    _lastTx = -1;
    rxRate = 0;
    txRate = 0;
  }

  ColumnLayout {
    spacing: -2
    visible: root.online

    Text {
      text: "󰇚 " + root.humanRate(root.rxRate)
      color: root.rxRate > 1024 ? Theme.accent : Theme.muted
      font.family: Theme.iconFont
      font.pixelSize: Theme.smallSize - 2
    }

    Text {
      text: "󰕒 " + root.humanRate(root.txRate)
      color: root.txRate > 1024 ? Theme.peach : Theme.muted
      font.family: Theme.iconFont
      font.pixelSize: Theme.smallSize - 2
    }
  }

  Text {
    // NetworkDevice.address is the hardware (MAC) address, which is not what
    // you want on a bar. The interface name carries more day-to-day meaning,
    // and the rates above already say whether the link is doing anything.
    text: root.online ? (root.device?.name ?? "") : "offline"
    color: root.online ? Theme.subtext : Theme.crit
    font.family: Theme.font
    font.pixelSize: Theme.smallSize
    visible: text !== ""
  }
}
