import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Nebula overlay status: one coloured dot per network, a click opens the
// details (unit state, own overlay address, lighthouses, fleet hosts). Read
// only -- it never starts or stops anything.
//
// Data comes from `quickshell-nebula status` (modules/home/packages/quickshell.nix),
// which pings inside the script, so a run takes a few seconds. Green = ok,
// amber = a lighthouse or fleet host is unreachable, red = the unit is not
// active or the interface has no overlay address. A change into or out of red
// sends a desktop notification (never for the first result after start).
BarModule {
  id: root

  property bool menuOpen: false

  // [{name, label, unit, device, active, ip, state, lighthouses, hosts}]
  property var networks: []
  // "" when the last run worked, otherwise what went wrong.
  property string error: ""
  property bool everLoaded: false
  property string updated: ""
  // network name -> last state, for the down / back up notifications.
  property var lastStates: ({})

  icon: "󰛳"
  accent: menuOpen ? Theme.accent : Theme.subtext

  onClicked: menuOpen = !menuOpen
  onMenuOpenChanged: {
    if (menuOpen)
      refresh();
  }

  function refresh() {
    if (!statusProc.running)
      statusProc.running = true;
  }

  function stateColor(state) {
    if (state === "ok")
      return Theme.good;
    if (state === "degraded")
      return Theme.warn;
    if (state === "down")
      return Theme.crit;
    return Theme.muted;
  }

  function rttText(rtt) {
    return rtt === null || rtt === undefined ? "—" : `${Math.round(rtt)} ms`;
  }

  function notifyChanges(list) {
    const next = {};
    for (const n of list) {
      next[n.name] = n.state;
      const before = root.lastStates[n.name];
      if (!root.everLoaded || before === undefined || before === n.state)
        continue;
      if (n.state === "down") {
        const why = [];
        if (n.active !== "active")
          why.push(n.active);
        if (!n.ip)
          why.push("no address");
        Quickshell.execDetached(["notify-send", "-a", "Nebula", `${n.label}: down`, `${n.unit}: ${why.join(", ")}`]);
      } else if (before === "down") {
        Quickshell.execDetached(["notify-send", "-a", "Nebula", `${n.label}: back up`, n.unit]);
      }
    }
    root.lastStates = next;
  }

  Process {
    id: statusProc
    command: ["quickshell-nebula", "status"]

    stdout: StdioCollector {
      onStreamFinished: {
        const raw = this.text.trim();
        if (raw === "") {
          root.error = "quickshell-nebula produced nothing";
          return;
        }
        try {
          const parsed = JSON.parse(raw);
          if (parsed.error) {
            root.error = parsed.error;
            return;
          }
          root.notifyChanges(parsed.networks);
          root.networks = parsed.networks;
          root.error = "";
          root.everLoaded = true;
          root.updated = Qt.formatTime(new Date(), "HH:mm:ss");
        } catch (e) {
          root.error = "bad response";
        }
      }
    }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Status dot, shared by the pill and the popup.
  component Dot: Rectangle {
    property color tone: Theme.muted

    implicitWidth: 8
    implicitHeight: 8
    radius: 4
    color: tone
  }

  RowLayout {
    spacing: 4

    Repeater {
      model: root.networks

      Dot {
        required property var modelData
        tone: root.error === "" ? root.stateColor(modelData.state) : Theme.muted
      }
    }

    // Before the first result there is nothing to draw; keep one grey dot so
    // the pill is not just a lone glyph.
    Dot {
      visible: root.networks.length === 0
    }
  }

  PopupWindow {
    id: popup
    visible: root.menuOpen
    color: "transparent"

    anchor {
      window: root.QsWindow.window
      // Right-aligned with the pill, like the power menu: a centred popup
      // would run off the screen edge.
      rect.x: root.mapToItem(null, 0, 0).x + root.width - popup.width
      rect.y: root.mapToItem(null, 0, 0).y + root.height + 6
    }

    implicitWidth: 340
    implicitHeight: body.implicitHeight + 24

    Rectangle {
      anchors.fill: parent
      radius: 10
      color: Theme.surface
      border.width: 1
      border.color: Theme.border

      ColumnLayout {
        id: body
        // Height flows outward to the popup (see PowerMenu.qml), so only the
        // horizontal edges and the top are anchored.
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 10

        Repeater {
          model: root.networks

          ColumnLayout {
            id: net
            required property var modelData

            Layout.fillWidth: true
            spacing: 4

            RowLayout {
              Layout.fillWidth: true
              spacing: 6

              Dot {
                tone: root.stateColor(net.modelData.state)
              }

              Text {
                text: `${net.modelData.label} ${net.modelData.name}`
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
              }

              Text {
                text: net.modelData.active
                color: net.modelData.active === "active" ? Theme.good : Theme.crit
                font.family: Theme.font
                font.pixelSize: Theme.smallSize
              }

              Item {
                Layout.fillWidth: true
              }

              Text {
                text: net.modelData.ip ? net.modelData.ip : "no address"
                color: net.modelData.ip ? Theme.subtext : Theme.crit
                font.family: Theme.font
                font.pixelSize: Theme.smallSize
              }
            }

            Repeater {
              model: net.modelData.lighthouses

              RowLayout {
                id: lh
                required property var modelData

                Layout.fillWidth: true
                Layout.leftMargin: 14
                spacing: 6

                Dot {
                  tone: lh.modelData.up ? Theme.good : Theme.crit
                }

                Text {
                  Layout.fillWidth: true
                  text: lh.modelData.name
                  elide: Text.ElideRight
                  color: lh.modelData.up ? Theme.text : Theme.crit
                  font.family: Theme.font
                  font.pixelSize: Theme.smallSize
                }

                Text {
                  text: root.rttText(lh.modelData.rtt)
                  color: Theme.muted
                  font.family: Theme.font
                  font.pixelSize: Theme.smallSize
                }
              }
            }

            GridLayout {
              visible: net.modelData.hosts.length > 0
              Layout.fillWidth: true
              Layout.leftMargin: 14
              Layout.topMargin: 2
              columns: 3
              columnSpacing: 8
              rowSpacing: 3

              Repeater {
                model: net.modelData.hosts

                RowLayout {
                  id: cell
                  required property var modelData

                  Layout.fillWidth: true
                  Layout.preferredWidth: 1
                  spacing: 4

                  Dot {
                    tone: cell.modelData.up ? Theme.good : Theme.crit
                  }

                  Text {
                    Layout.fillWidth: true
                    text: cell.modelData.name
                    elide: Text.ElideRight
                    color: cell.modelData.up ? Theme.text : Theme.crit
                    font.family: Theme.font
                    font.pixelSize: Theme.smallSize
                  }

                  Text {
                    visible: cell.modelData.up
                    text: root.rttText(cell.modelData.rtt)
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.smallSize - 2
                  }
                }
              }
            }
          }
        }

        Text {
          visible: root.error !== ""
          Layout.fillWidth: true
          text: root.error
          wrapMode: Text.Wrap
          color: Theme.crit
          font.family: Theme.font
          font.pixelSize: Theme.smallSize
        }

        Text {
          text: root.everLoaded ? `updated ${root.updated}` : "loading…"
          color: Theme.muted
          font.family: Theme.font
          font.pixelSize: Theme.smallSize
        }
      }
    }
  }
}
