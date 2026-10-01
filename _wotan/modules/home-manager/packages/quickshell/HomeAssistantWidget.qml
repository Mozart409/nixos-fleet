import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Generated

// Quick toggles for a handful of Home Assistant switches and lights.
//
// All HA traffic goes through the `quickshell-ha` script from
// quickshell.nix, never through this file. The script reads the
// long-lived token from the agenix file on every call and hands it to curl as
// a header file, so the token is in no process's argv or environment and
// nowhere in QML -- and it refuses to toggle anything not on the nix-declared
// entity list, so this panel cannot be talked into calling arbitrary services.
//
// Same layer as the homelab board (WlrLayer.Bottom: only visible on an empty
// workspace), but unlike that board it keeps its input region -- the whole
// point is clicking it.
Variants {
  // Only on the primary output: two copies would just mean two pollers
  // hammering HA for the same five states.
  model: {
    const primary = Quickshell.screens.filter(s => s.name === WorkspaceLayout.primary);
    return primary.length > 0 ? primary : Quickshell.screens.slice(0, 1);
  }

  PanelWindow {
    id: panel
    required property var modelData
    screen: modelData

    property var entities: []
    // "" when healthy, otherwise what to show in place of the rows.
    property string error: ""
    property bool everLoaded: false
    // Entity whose switch call is in flight, and the state it was asked for.
    // Its row shows the target immediately and ignores further clicks until
    // the call returns.
    property string pending: ""
    property string pendingState: ""
    // id -> {state, until}: states we have successfully asked HA for but HA
    // has not reported yet. A successful service call does not mean the next
    // read reflects it -- Tasmota switches answer over MQTT a beat later, so
    // an immediate refresh returned the *old* state and the switch snapped
    // back, leaving the panel one click behind reality. Until HA confirms (or
    // `until` passes, so a call that silently did nothing cannot pin a lie on
    // screen forever) refreshes are read through this map.
    property var expected: ({})

    readonly property int onCount: entities.filter(e => e.state === "on").length

    anchors {
      top: true
      left: true
    }
    margins {
      top: Theme.barHeight + 18
      left: 18
    }

    implicitWidth: 280
    implicitHeight: card.implicitHeight
    color: "transparent"

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-homeassistant"

    function refresh() {
      if (!statesProc.running)
        statesProc.running = true;
    }

    function toggle(entity) {
      if (panel.pending !== "" || entity.state === "unavailable")
        return;
      // Ask for the opposite of what is on screen, not a blind HA `toggle`:
      // the user clicked what they saw.
      panel.pending = entity.id;
      panel.pendingState = entity.state === "on" ? "off" : "on";
      toggleProc.command = ["quickshell-ha", "set", panel.pending, panel.pendingState];
      toggleProc.running = true;
    }

    function applyStates(list) {
      const now = Date.now();
      const stillExpected = {};
      panel.entities = list.map(e => {
        const want = panel.expected[e.id];
        if (want && now < want.until && e.state !== want.state) {
          stillExpected[e.id] = want;
          return Object.assign({}, e, {
            state: want.state
          });
        }
        return e;
      });
      panel.expected = stillExpected;
    }

    Process {
      id: statesProc
      command: ["quickshell-ha", "states"]
      running: true

      stdout: StdioCollector {
        onStreamFinished: {
          panel.everLoaded = true;
          const raw = this.text.trim();
          if (raw === "") {
            panel.error = "quickshell-ha produced nothing";
            return;
          }
          try {
            const parsed = JSON.parse(raw);
            if (parsed.error) {
              panel.error = parsed.error;
              return;
            }
            panel.applyStates(parsed.entities);
            panel.error = "";
          } catch (e) {
            panel.error = "bad response";
          }
        }
      }
    }

    Process {
      id: toggleProc
      onExited: (exitCode, exitStatus) => {
        if (exitCode === 0) {
          const next = Object.assign({}, panel.expected);
          next[panel.pending] = {
            state: panel.pendingState,
            until: Date.now() + 8000
          };
          panel.expected = next;
          panel.applyStates(panel.entities);
        }
        panel.pending = "";
        panel.refresh();
      }
    }

    // Poll fast while anything is unconfirmed, so the switch settles on HA's
    // real answer within a second or two instead of at the next 20s tick.
    Timer {
      interval: 1500
      running: Object.keys(panel.expected).length > 0
      repeat: true
      onTriggered: panel.refresh()
    }

    Timer {
      interval: 20000
      running: true
      repeat: true
      onTriggered: panel.refresh()
    }

    Rectangle {
      id: card
      width: parent.width
      implicitHeight: body.implicitHeight + 28
      radius: 12
      color: Qt.alpha(Theme.surface, 0.82)
      border.width: 1
      border.color: panel.error !== "" ? Qt.alpha(Theme.muted, 0.5) : panel.onCount > 0 ? Qt.alpha(Theme.warn, 0.45) : Qt.alpha(Theme.text, 0.15)

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
            text: "󰟐"
            color: Theme.accent
            font.family: Theme.iconFont
            font.pixelSize: Theme.deskSize + 3
          }

          Text {
            text: "LIGHTS"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.deskSmall
            font.bold: true
          }

          Item {
            Layout.fillWidth: true
          }

          Text {
            text: panel.error !== "" ? "offline" : `${panel.onCount} on`
            color: panel.error !== "" ? Theme.muted : panel.onCount > 0 ? Theme.warn : Theme.subtext
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
          visible: panel.entities.length > 0

          Repeater {
            model: panel.entities

            Rectangle {
              id: row
              required property var modelData

              readonly property bool unavailable: modelData.state === "unavailable"
              readonly property bool busy: panel.pending === modelData.id
              // While the call is in flight, show where it is going rather
              // than where it was: the click should feel instant even though
              // HA takes a beat to report back.
              readonly property bool on: busy ? panel.pendingState === "on" : modelData.state === "on"

              Layout.fillWidth: true
              implicitHeight: 30
              radius: Theme.radius
              color: mouse.containsMouse && !unavailable ? Theme.moduleHover : "transparent"
              opacity: unavailable ? 0.45 : 1

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

                Text {
                  text: row.on ? "󰌵" : "󰌶"
                  color: row.on ? Theme.warn : Theme.muted
                  font.family: Theme.iconFont
                  font.pixelSize: Theme.deskSize

                  Behavior on color {
                    ColorAnimation {
                      duration: Theme.anim
                    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  text: row.modelData.name
                  color: row.on ? Theme.text : Theme.subtext
                  font.family: Theme.font
                  font.pixelSize: Theme.deskMeta
                  elide: Text.ElideRight
                }

                Text {
                  visible: row.unavailable
                  text: "unavailable"
                  color: Theme.muted
                  font.family: Theme.font
                  font.pixelSize: Theme.deskMeta - 1
                }

                // Switch track + knob.
                Rectangle {
                  visible: !row.unavailable
                  implicitWidth: 30
                  implicitHeight: 16
                  radius: 8
                  color: row.on ? Qt.alpha(Theme.warn, 0.85) : Qt.alpha(Theme.text, 0.15)
                  opacity: row.busy ? 0.6 : 1

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
                cursorShape: row.unavailable ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: panel.toggle(row.modelData)
              }
            }
          }
        }

        // Error / loading state ---------------------------------------
        Text {
          Layout.fillWidth: true
          visible: panel.entities.length === 0 || panel.error !== ""
          text: panel.error !== "" ? panel.error : panel.everLoaded ? "no entities configured" : "loading…"
          color: Theme.muted
          font.family: Theme.font
          font.pixelSize: Theme.deskMeta
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
