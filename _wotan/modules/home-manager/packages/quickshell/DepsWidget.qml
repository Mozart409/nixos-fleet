import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Which of this flake's direct inputs have meaningfully moved upstream.
//
// The gate is `locked rev != upstream HEAD`, computed by the flake-drift
// script. It is deliberately NOT lock age on its own: agenix has sat at
// upstream HEAD for 232 days and rose-pine-hyprcursor for 487, because those
// projects are finished or dormant. An age-ranked board would paint both
// permanently red with nothing to do about it, which is how you train yourself
// to ignore a widget.
//
// Raw drift alone fails the same way from the other side. nixpkgs follows
// nixos-unstable, which lands a channel commit several times a day, so it goes
// "behind" within hours of every update -- an amber you cannot clear by
// updating, which reads as broken. So drift is the gate and lock age is the
// threshold: only inputs that have moved AND whose lock is older than
// graceDays get a row. Drifted-but-fresh inputs are still counted and named on
// the quiet line -- nothing that has moved is ever claimed current.
//
// Only direct inputs are considered. Transitive nodes (`systems`,
// `flake-utils`) are pinned by other flakes, are years old by design, and are
// not something this machine can act on.
Variants {
  model: Quickshell.screens

  PanelWindow {
    id: panel
    required property var modelData
    screen: modelData

    property string flakePath: "/etc/nixos"

    property var inputs: []
    property bool ok: true
    property bool everRan: false

    property real graceDays: 3

    // What the board is about: moved upstream and the lock is old enough that
    // pulling it in is worth a rebuild.
    readonly property var stale: inputs.filter(i => i.stale === true)
    // Moved upstream, but you are already within graceDays of it. Reported,
    // not escalated.
    readonly property var drifting: inputs.filter(i => i.behind === true && i.stale !== true)
    readonly property var unknown: inputs.filter(i => i.unreachable === true)
    readonly property int current: inputs.filter(i => i.behind === false).length

    anchors {
      bottom: true
      right: true
    }
    margins {
      bottom: 18
      right: 18
    }

    implicitWidth: 400
    implicitHeight: card.implicitHeight
    color: "transparent"

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-deps"
    mask: Region {}

    Process {
      id: driftProc
      command: ["flake-drift", panel.flakePath]
      running: true

      stdout: StdioCollector {
        onStreamFinished: {
          const raw = this.text.trim();
          if (raw === "") {
            panel.ok = false;
            panel.everRan = true;
            return;
          }
          try {
            const parsed = JSON.parse(raw);
            panel.ok = parsed.ok === true;
            panel.inputs = parsed.inputs ?? [];
            panel.graceDays = parsed.graceDays ?? panel.graceDays;
          } catch (e) {
            panel.ok = false;
          }
          panel.everRan = true;
        }
      }
    }

    // Every run fans out a dozen network round trips, so this is a slow poll on
    // purpose -- upstream moving five minutes ago is not news you need within
    // five minutes.
    Timer {
      interval: 45 * 60 * 1000
      running: true
      repeat: true
      onTriggered: driftProc.running = true
    }

    function ageText(days) {
      if (days === null || days === undefined)
        return "";
      if (days < 1)
        return "today";
      if (days < 60)
        return Math.round(days) + "d";
      return (days / 30).toFixed(0) + "mo";
    }

    Rectangle {
      id: card
      width: parent.width
      implicitHeight: body.implicitHeight + 28
      radius: 12
      color: Qt.alpha(Theme.surface, 0.82)
      border.width: 1
      border.color: {
        if (!panel.ok)
          return Qt.alpha(Theme.muted, 0.5);
        if (panel.stale.length > 0)
          return Qt.alpha(Theme.warn, 0.5);
        return Qt.alpha(Theme.good, 0.35);
      }

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

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Text {
            text: "󰚰"
            color: Theme.accent
            font.family: Theme.iconFont
            font.pixelSize: Theme.deskSize + 3
          }

          Text {
            text: "FLAKE INPUTS"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.deskSmall
            font.bold: true
          }

          Item {
            Layout.fillWidth: true
          }

          Text {
            text: {
              if (!panel.everRan)
                return "checking";
              if (!panel.ok)
                return "check failed";
              return panel.stale.length > 0 ? `${panel.stale.length} behind` : "all current";
            }
            color: {
              if (!panel.everRan || !panel.ok)
                return Theme.muted;
              return panel.stale.length > 0 ? Theme.warn : Theme.good;
            }
            font.family: Theme.font
            font.pixelSize: Theme.deskSmall
            font.bold: true
          }
        }

        Rectangle {
          Layout.fillWidth: true
          height: 1
          color: Qt.alpha(Theme.text, 0.1)
          visible: panel.stale.length > 0 || panel.drifting.length > 0 || panel.unknown.length > 0
        }

        // Only inputs with something to do get a row. Everything sitting at
        // upstream HEAD collapses into the one-line count below.
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 5
          visible: panel.stale.length > 0

          Repeater {
            model: panel.stale

            RowLayout {
              id: behindRow
              required property var modelData
              Layout.fillWidth: true
              spacing: 6

              Rectangle {
                width: 7
                height: 7
                radius: 3.5
                color: Theme.warn
              }

              Text {
                Layout.fillWidth: true
                text: behindRow.modelData.name
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.deskSmall
                elide: Text.ElideRight
              }

              Text {
                // How old *your lock* is, which is the useful number once you
                // already know the input has moved: it says how much you are
                // about to pull in.
                text: panel.ageText(behindRow.modelData.lockedAge)
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: Theme.deskMeta
              }
            }
          }
        }

        // Inputs that moved but whose lock is still inside the grace window.
        // Named rather than hidden -- the point of the window is to stop this
        // demanding action, not to pretend it did not happen.
        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          visible: panel.drifting.length > 0

          Rectangle {
            width: 7
            height: 7
            radius: 3.5
            color: Qt.alpha(Theme.muted, 0.7)
          }

          Text {
            Layout.fillWidth: true
            text: panel.drifting.map(i => i.name).join(", ") + " moved, lock still fresh"
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.deskMeta
            elide: Text.ElideRight
          }
        }

        // Inputs we could not reach are called out separately -- reporting them
        // as current would be the one answer that makes this widget lie.
        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          visible: panel.unknown.length > 0

          Rectangle {
            width: 7
            height: 7
            radius: 3.5
            color: Theme.muted
          }

          Text {
            Layout.fillWidth: true
            text: `${panel.unknown.length} unreachable`
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.deskMeta
            elide: Text.ElideRight
          }
        }

        Text {
          Layout.fillWidth: true
          text: {
            if (!panel.everRan)
              return "checking upstream…";
            if (!panel.ok)
              return "flake-drift failed";
            if (panel.stale.length === 0 && panel.drifting.length === 0)
              return `all ${panel.current} inputs at upstream HEAD`;
            if (panel.stale.length === 0)
              return `${panel.current} inputs at upstream HEAD · nothing older than ${panel.graceDays}d`;
            return `${panel.current} others current`;
          }
          color: panel.ok && panel.stale.length === 0 ? Theme.good : Theme.muted
          font.family: Theme.font
          font.pixelSize: Theme.deskMeta
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
