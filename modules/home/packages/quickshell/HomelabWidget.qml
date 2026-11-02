import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Desktop panel showing the state of the homelab, straight from Prometheus.
//
// Two reads, both unauthenticated on the LAN: `/api/v1/query` for a per-host
// up/down vector, and `/api/v1/alerts` for whatever is currently firing. The
// point of this widget is to notice things without opening Grafana -- a host
// that dropped overnight should be visible the moment you sit down.
//
// It lives on WlrLayer.Bottom: above the wallpaper, below every window. That
// means it is only visible on an empty workspace, which is the intent -- it is
// a desktop widget, not an overlay competing with the bar.
Scope {
  id: root

  // The data lives out here, once: each screen gets its own panel but they all
  // draw the same two Prometheus reads.
  property string endpoint: "https://prometheus.homelab.internal"
  // `up` is per scrape job and a host with several jobs reports one series
  // each, so the grid has to collapse them.
  //
  // Two subtleties, both of which produced a wrong grid on the first
  // attempt:
  //
  //  - Blackbox jobs are labelled with the *probe target's* instance, but
  //    `up` for them means "was the blackbox exporter scrapable" -- and that
  //    exporter runs on the otel host, not on the target. So a dead host
  //    with a blackbox probe still reports up == 1 under its own name.
  //    Whether the probe itself passed is `probe_success`, not `up`.
  //    Excluding blackbox jobs is what makes the grid tell the truth.
  //  - min(), not max(): a host is only healthy when everything on it is
  //    scraping. max() reported a host as up when any one of its jobs
  //    answered, which hid three genuinely dead machines.
  //
  // The `or` tail covers hosts that have no exporter of their own and are
  // only watched by a blackbox probe -- the router, for one. Without it,
  // excluding blackbox jobs drops those hosts off the grid entirely, which
  // is worse than showing them wrong. `or` keeps right-hand series only for
  // instances the left-hand side did not already produce.
  readonly property string upQuery: 'min by (instance) (up{job!~"blackbox.*"}) or min by (instance) (probe_success)'

  property var hosts: []
  property var alerts: []
  property bool reachable: true
  property string lastError: ""

  readonly property int hostsUp: hosts.filter(h => h.up).length

  Process {
    id: upProc
    command: ["sh", "-c", `curl -sf --max-time 6 -G '${root.endpoint}/api/v1/query' --data-urlencode 'query=${root.upQuery}'`]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        const raw = this.text.trim();
        if (raw === "") {
          // curl -f exits non-zero and prints nothing when Prometheus is
          // unreachable. That is itself worth showing: a blank panel would
          // look identical to a healthy one with no hosts.
          root.reachable = false;
          root.lastError = "prometheus unreachable";
          return;
        }
        try {
          const parsed = JSON.parse(raw);
          const rows = parsed.data.result.map(r => ({
                name: r.metric.instance ?? "?",
                up: r.value[1] === "1"
              }));
          rows.sort((a, b) => (a.up === b.up) ? a.name.localeCompare(b.name) : (a.up ? 1 : -1));
          root.hosts = rows;
          root.reachable = true;
          root.lastError = "";
        } catch (e) {
          root.reachable = false;
          root.lastError = "bad response";
        }
      }
    }
  }

  Process {
    id: alertProc
    command: ["sh", "-c", `curl -sf --max-time 6 '${root.endpoint}/api/v1/alerts'`]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        const raw = this.text.trim();
        if (raw === "")
          return;
        try {
          const all = JSON.parse(raw).data.alerts;
          const rank = s => s === "critical" ? 0 : (s === "warning" ? 1 : 2);
          const firing = all.filter(a => a.state === "firing");
          firing.sort((a, b) => rank(a.labels.severity) - rank(b.labels.severity));
          root.alerts = firing.map(a => ({
                severity: a.labels.severity ?? "info",
                summary: a.annotations.summary ?? a.labels.alertname ?? "alert",
                since: a.activeAt ?? ""
              }));
        } catch (e) {}
      }
    }
  }

  function refresh() {
    upProc.running = true;
    alertProc.running = true;
  }

  // Polls only while an empty workspace shows the panel (see Desktop.qml),
  // and refreshes the moment one does.
  Timer {
    interval: 30000
    running: Desktop.anyVisible
    repeat: true
    onTriggered: root.refresh()
  }

  Connections {
    target: Desktop

    function onAnyVisibleChanged() {
      if (Desktop.anyVisible)
        root.refresh();
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData
      screen: modelData



      anchors {
        top: true
        right: true
      }
      margins {
        top: Theme.barHeight + 18
        right: 18
      }

      implicitWidth: 460
      implicitHeight: card.implicitHeight
      color: "transparent"

      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.namespace: "quickshell-homelab"
      // Purely informational, so let every click reach the desktop underneath.
      mask: Region {}

      function severityColor(sev) {
        if (sev === "critical")
          return Theme.crit;
        if (sev === "warning")
          return Theme.warn;
        return Theme.subtext;
      }

      // "homelab-woodpecker" -> "woodpecker". The prefix is on almost every host
      // and eats the width the actual name needs.
      function shortName(name) {
        return name.replace(/^homelab-/, "");
      }

      // "2026-09-09T18:22:00Z" -> "19h". Rough on purpose: the useful signal is
      // "this has been broken a while", not the exact duration.
      function age(iso) {
        if (iso === "")
          return "";
        const mins = (Date.now() - new Date(iso).getTime()) / 60000;
        if (isNaN(mins) || mins < 0)
          return "";
        if (mins < 60)
          return Math.round(mins) + "m";
        if (mins < 1440)
          return Math.round(mins / 60) + "h";
        return Math.round(mins / 1440) + "d";
      }

      Rectangle {
        id: card
        width: parent.width
        implicitHeight: body.implicitHeight + 28
        radius: 12
        color: Qt.alpha(Theme.surface, 0.82)
        border.width: 1
        // The whole card takes on the worst state in it, so peripheral vision
        // does the triage before you have read a single word.
        border.color: {
          if (!root.reachable)
            return Qt.alpha(Theme.muted, 0.5);
          if (root.alerts.some(a => a.severity === "critical"))
            return Qt.alpha(Theme.crit, 0.55);
          if (root.alerts.length > 0)
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

          // Header ------------------------------------------------------
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
              text: "󰒋"
              color: Theme.accent
              font.family: Theme.iconFont
              font.pixelSize: Theme.deskSize + 3
            }

            Text {
              text: "HOMELAB"
              color: Theme.text
              font.family: Theme.font
              font.pixelSize: Theme.deskSmall
              font.bold: true
            }

            Item {
              Layout.fillWidth: true
            }

            Text {
              text: root.reachable ? `${root.hostsUp}/${root.hosts.length}` : "offline"
              color: {
                if (!root.reachable)
                  return Theme.muted;
                return root.hostsUp === root.hosts.length ? Theme.good : Theme.crit;
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
          }

          // Host grid ---------------------------------------------------
          GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 6
            rowSpacing: 5
            visible: root.hosts.length > 0

            Repeater {
              model: root.hosts

              RowLayout {
                id: hostRow
                required property var modelData
                Layout.fillWidth: true
                spacing: 5

                Rectangle {
                  width: 8
                  height: 8
                  radius: 4
                  color: hostRow.modelData.up ? Theme.good : Theme.crit

                  // Down hosts pulse; up hosts sit still. Motion is reserved for
                  // the thing that needs attention.
                  SequentialAnimation on opacity {
                    running: !hostRow.modelData.up
                    loops: Animation.Infinite
                    NumberAnimation {
                      to: 0.3
                      duration: 800
                    }
                    NumberAnimation {
                      to: 1.0
                      duration: 800
                    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  text: panel.shortName(hostRow.modelData.name)
                  color: hostRow.modelData.up ? Theme.subtext : Theme.crit
                  font.family: Theme.font
                  font.pixelSize: Theme.deskMeta
                  elide: Text.ElideRight
                }
              }
            }
          }

          // Alerts ------------------------------------------------------
          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(Theme.text, 0.1)
            visible: root.alerts.length > 0
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: root.alerts.length > 0

            Repeater {
              // Cap the list: a homelab that is properly on fire would otherwise
              // grow the panel off the bottom of the screen.
              model: root.alerts.slice(0, 6)

              RowLayout {
                id: alertRow
                required property var modelData
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                  Layout.alignment: Qt.AlignTop
                  Layout.topMargin: 3
                  width: 7
                  height: 7
                  radius: 3.5
                  color: panel.severityColor(alertRow.modelData.severity)
                }

                Text {
                  Layout.fillWidth: true
                  text: alertRow.modelData.summary
                  color: Theme.subtext
                  font.family: Theme.font
                  font.pixelSize: Theme.deskMeta
                  wrapMode: Text.WordWrap
                  maximumLineCount: 2
                  elide: Text.ElideRight
                }

                Text {
                  Layout.alignment: Qt.AlignTop
                  text: panel.age(alertRow.modelData.since)
                  color: Theme.muted
                  font.family: Theme.font
                  font.pixelSize: Theme.deskMeta - 1
                }
              }
            }

            Text {
              text: `+${root.alerts.length - 6} more`
              color: Theme.muted
              font.family: Theme.font
              font.pixelSize: Theme.deskMeta - 1
              visible: root.alerts.length > 6
            }
          }

          // All-clear / error state -------------------------------------
          Text {
            Layout.fillWidth: true
            text: root.reachable ? "no alerts firing" : root.lastError
            color: root.reachable ? Theme.good : Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.deskMeta
            visible: root.alerts.length === 0
          }
        }
      }
    }
  }
}
