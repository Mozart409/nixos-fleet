import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Generated

// On/off switches for a few system units -- on wotan the on-demand AI
// services (llama.cpp, ComfyUI, SillyTavern). Built like the Home Assistant
// panel: same card, same rows, same switch.
//
// Everything goes through the `quickshell-units` script from quickshell.nix.
// The unit list lives in Nix (desktop.quickshell.serviceToggles.units); the
// script reports their state and refuses to start or stop anything else.
// What actually lets an unprivileged click start a system unit is a polkit
// rule generated from that same list on the host -- no sudo, no password
// prompt (the script passes --no-ask-password, so a missing rule shows up
// here as "Access denied" rather than as a rofi prompt).
//
// Bottom-left, on the same layer as the other boards (WlrLayer.Bottom: only
// visible on an empty workspace), keeping its input region so it can be
// clicked.
Variants {
  // Only on the primary output, like the HA panel.
  model: {
    const primary = Quickshell.screens.filter(s => s.name === WorkspaceLayout.primary);
    return primary.length > 0 ? primary : Quickshell.screens.slice(0, 1);
  }

  PanelWindow {
    id: panel
    required property var modelData
    screen: modelData

    property var units: []
    // "" when healthy, otherwise what to show in place of the rows.
    property string error: ""
    // Last failed start/stop (polkit denial, unknown unit...). Shown under
    // the rows until it times out or the next toggle succeeds.
    property string toggleError: ""
    property bool everLoaded: false
    // Unit whose start/stop call is in flight, and the state it was asked
    // for. Its row shows "starting…"/"stopping…" at once and ignores clicks
    // until the call returns.
    property string pending: ""
    property string pendingState: ""
    // unit -> {want, from, until}: toggles systemd has accepted but not yet
    // acted on. With --no-block the job is only queued when the call returns,
    // so the very next read can still say the old state and the switch would
    // snap back. While systemd keeps reporting exactly the pre-click state
    // (`from`) and `until` has not passed, the row stays in transition; any
    // change at all and systemd's answer wins.
    property var expected: ({})

    readonly property int onCount: units.filter(u => panel.viewState(u) === "on").length
    readonly property int gpuBusy: units.filter(u => u.gpu && ["on", "starting"].includes(panel.viewState(u))).length
    readonly property bool settling: Object.keys(expected).length > 0 || units.some(u => ["starting", "stopping"].includes(panel.viewState(u)))

    anchors {
      bottom: true
      left: true
    }
    margins {
      bottom: 18
      left: 18
    }

    implicitWidth: 280
    implicitHeight: card.implicitHeight
    color: "transparent"

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-services"

    // on | off | starting | stopping | failed | missing
    function viewState(u) {
      if (u.load === "not-found" || u.load === "masked")
        return "missing";
      if (panel.pending === u.unit)
        return panel.pendingState === "on" ? "starting" : "stopping";
      const exp = panel.expected[u.unit];
      if (exp)
        return exp.want === "on" ? "starting" : "stopping";
      switch (u.active) {
      case "active":
      case "reloading":
      case "refreshing":
        return "on";
      case "activating":
        return "starting";
      case "deactivating":
        return "stopping";
      case "failed":
        return "failed";
      default:
        return "off";
      }
    }

    function refresh() {
      if (!statesProc.running)
        statesProc.running = true;
    }

    function toggle(u) {
      const view = panel.viewState(u);
      if (panel.pending !== "" || view === "missing")
        return;
      // Ask for the opposite of what is on screen. A unit still starting
      // counts as on (a click cancels it); failed counts as off (a click
      // retries).
      panel.pending = u.unit;
      panel.pendingState = ["on", "starting"].includes(view) ? "off" : "on";
      panel.toggleError = "";
      toggleProc.from = u.active;
      toggleProc.command = ["quickshell-units", "set", panel.pending, panel.pendingState];
      toggleProc.running = true;
    }

    function applyStates(list) {
      const now = Date.now();
      const stillExpected = {};
      for (const u of list) {
        const exp = panel.expected[u.unit];
        if (exp && now < exp.until && u.active === exp.from)
          stillExpected[u.unit] = exp;
      }
      panel.expected = stillExpected;
      panel.units = list;
    }

    Process {
      id: statesProc
      command: ["quickshell-units", "states"]
      running: true

      stdout: StdioCollector {
        onStreamFinished: {
          panel.everLoaded = true;
          const raw = this.text.trim();
          if (raw === "") {
            panel.error = "quickshell-units produced nothing";
            return;
          }
          try {
            const parsed = JSON.parse(raw);
            if (parsed.error) {
              panel.error = parsed.error;
              return;
            }
            panel.applyStates(parsed.units);
            panel.error = "";
          } catch (e) {
            panel.error = "bad response";
          }
        }
      }
    }

    Process {
      id: toggleProc
      // ActiveState of the unit when it was clicked.
      property string from: ""

      stdout: StdioCollector {
        onStreamFinished: {
          const raw = this.text.trim();
          if (raw === "")
            return;
          try {
            const parsed = JSON.parse(raw);
            if (parsed.error)
              panel.toggleError = parsed.error;
          } catch (e) {
            panel.toggleError = raw;
          }
        }
      }

      onExited: (exitCode, exitStatus) => {
        if (exitCode === 0) {
          const next = Object.assign({}, panel.expected);
          next[panel.pending] = {
            want: panel.pendingState,
            from: toggleProc.from,
            until: Date.now() + 5000
          };
          panel.expected = next;
        } else if (panel.toggleError === "") {
          panel.toggleError = `could not ${panel.pendingState === "on" ? "start" : "stop"} ${panel.pending}`;
        }
        panel.pending = "";
        panel.refresh();
      }
    }

    // Poll every second while a unit is starting or stopping, so the switch
    // settles on systemd's answer instead of at the next slow tick.
    Timer {
      interval: 1000
      running: panel.settling
      repeat: true
      onTriggered: panel.refresh()
    }

    // `systemctl show` is a local D-Bus call; this only catches changes made
    // outside the panel (a CLI start, a crash).
    Timer {
      interval: 10000
      running: true
      repeat: true
      onTriggered: panel.refresh()
    }

    Timer {
      interval: 8000
      running: panel.toggleError !== ""
      onTriggered: panel.toggleError = ""
    }

    Rectangle {
      id: card
      width: parent.width
      implicitHeight: body.implicitHeight + 28
      radius: 12
      color: Qt.alpha(Theme.surface, 0.82)
      border.width: 1
      border.color: panel.error !== "" ? Qt.alpha(Theme.muted, 0.5) : panel.units.some(u => panel.viewState(u) === "failed") ? Qt.alpha(Theme.crit, 0.5) : panel.onCount > 0 ? Qt.alpha(Theme.good, 0.45) : Qt.alpha(Theme.text, 0.15)

      Behavior on border.color {
        ColorAnimation {
          duration: Theme.animSlow
        }
      }

      ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 10

        // Header ------------------------------------------------------
        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Text {
            text: "󰚩"
            color: Theme.accent
            font.family: Theme.iconFont
            font.pixelSize: Theme.deskSize + 3
          }

          Text {
            text: Features.serviceTogglesTitle
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.deskSmall
            font.bold: true
          }

          Item {
            Layout.fillWidth: true
          }

          Text {
            text: panel.error !== "" ? "error" : `${panel.onCount} running`
            color: panel.error !== "" ? Theme.muted : panel.onCount > 0 ? Theme.good : Theme.subtext
            font.family: Theme.font
            font.pixelSize: Theme.deskSmall
            font.bold: true
          }
        }

        Rectangle {
          Layout.fillWidth: true
          height: 1
          color: Qt.alpha(Theme.text, 0.1)
        }

        // Rows --------------------------------------------------------
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          visible: panel.units.length > 0

          Repeater {
            model: panel.units

            Rectangle {
              id: row
              required property var modelData

              readonly property string view: panel.viewState(modelData)
              readonly property bool missing: view === "missing"
              readonly property bool busy: view === "starting" || view === "stopping"
              // Knob position: where the unit is going, so a click feels
              // instant even though ComfyUI takes a while to come up.
              readonly property bool on: view === "on" || view === "starting"
              readonly property color stateColor: view === "on" ? Theme.good : busy ? Theme.warn : view === "failed" ? Theme.crit : Theme.muted

              Layout.fillWidth: true
              implicitHeight: 30
              radius: Theme.radius
              color: mouse.containsMouse && !missing ? Theme.moduleHover : "transparent"
              opacity: missing ? 0.45 : 1

              Behavior on color {
                ColorAnimation {
                  duration: Theme.anim
                }
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 8

                // Status dot: green running, amber in transition, red failed.
                Rectangle {
                  id: dot
                  implicitWidth: 8
                  implicitHeight: 8
                  radius: 4
                  color: row.stateColor

                  Behavior on color {
                    ColorAnimation {
                      duration: Theme.anim
                    }
                  }

                  // Pulses while starting/stopping; reset so a unit that
                  // settles mid-fade is not left dimmed.
                  SequentialAnimation on opacity {
                    running: row.busy
                    loops: Animation.Infinite
                    onRunningChanged: if (!running)
                      dot.opacity = 1
                    NumberAnimation {
                      to: 0.3
                      duration: 500
                    }
                    NumberAnimation {
                      to: 1
                      duration: 500
                    }
                  }
                }

                Text {
                  text: row.modelData.label
                  color: row.on ? Theme.text : Theme.subtext
                  font.family: Theme.font
                  font.pixelSize: Theme.deskMeta
                  elide: Text.ElideRight
                  Layout.maximumWidth: 120
                }

                // Hint (e.g. VRAM), or what the unit is doing right now.
                Text {
                  Layout.fillWidth: true
                  text: row.view === "starting" ? "starting…" : row.view === "stopping" ? "stopping…" : row.view === "failed" ? "failed" : row.missing ? "not installed" : (row.modelData.note ?? "")
                  color: row.busy ? Theme.warn : row.view === "failed" ? Theme.crit : Theme.muted
                  font.family: Theme.font
                  font.pixelSize: Theme.deskMeta - 1
                  elide: Text.ElideRight
                }

                // Switch track + knob.
                Rectangle {
                  visible: !row.missing
                  implicitWidth: 30
                  implicitHeight: 16
                  radius: 8
                  color: row.view === "on" ? Qt.alpha(Theme.good, 0.85) : row.busy ? Qt.alpha(Theme.warn, 0.6) : row.view === "failed" ? Qt.alpha(Theme.crit, 0.45) : Qt.alpha(Theme.text, 0.15)
                  opacity: panel.pending === row.modelData.unit ? 0.6 : 1

                  Behavior on color {
                    ColorAnimation {
                      duration: Theme.anim
                    }
                  }

                  Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    y: 2
                    x: row.on ? parent.width - width - 2 : 2
                    color: row.on ? Theme.inverse : Theme.subtext

                    Behavior on x {
                      NumberAnimation {
                        duration: Theme.anim
                        easing.type: Easing.OutCubic
                      }
                    }
                  }
                }
              }

              MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: row.missing ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: panel.toggle(row.modelData)
              }
            }
          }
        }

        // GPU hint: never acted on, only shown. Two GPU-heavy units at once
        // usually means the second one OOMs while loading its model.
        RowLayout {
          Layout.fillWidth: true
          visible: panel.gpuBusy > 1
          spacing: 8

          Text {
            text: "󰢮"
            color: Theme.warn
            font.family: Theme.iconFont
            font.pixelSize: Theme.deskMeta
          }

          Text {
            Layout.fillWidth: true
            text: `${panel.gpuBusy} GPU services up -- they share the VRAM`
            color: Theme.warn
            font.family: Theme.font
            font.pixelSize: Theme.deskMeta - 1
            wrapMode: Text.WordWrap
          }
        }

        Text {
          Layout.fillWidth: true
          visible: panel.toggleError !== ""
          text: panel.toggleError
          color: Theme.crit
          font.family: Theme.font
          font.pixelSize: Theme.deskMeta - 1
          wrapMode: Text.WordWrap
        }

        // Error / loading state ---------------------------------------
        Text {
          Layout.fillWidth: true
          visible: panel.units.length === 0 || panel.error !== ""
          text: panel.error !== "" ? panel.error : panel.everLoaded ? "no units configured" : "loading…"
          color: Theme.muted
          font.family: Theme.font
          font.pixelSize: Theme.deskMeta
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
