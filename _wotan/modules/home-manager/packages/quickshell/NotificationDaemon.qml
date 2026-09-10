import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications

// In-shell notification daemon, an alternative to dunst.
//
// Only instantiated when desktop.notifications.backend = "quickshell" (see
// shell.qml). org.freedesktop.Notifications has exactly one owner, so this and
// dunst can never both run -- whichever loses the race gets nothing, silently.
//
// Behaviour is deliberately modelled on the dunst config this replaces: top
// right, two visible at a time with an overflow count, per-urgency colours and
// timeouts, left click dismisses, right click clears all, middle click fires
// the default action.
Scope {
  id: root

  // Per-urgency dwell time, matching the dunst timeouts. Critical stays until
  // acknowledged -- an alert you can miss by looking away is not an alert.
  readonly property var timeouts: ({
      0: 4000,   // low
      1: 6000,   // normal
      2: 0       // critical: never auto-expire
    })

  readonly property int maxVisible: 2

  readonly property var tracked: server.trackedNotifications.values
  readonly property var shown: tracked.slice(0, maxVisible)
  readonly property int overflow: Math.max(0, tracked.length - maxVisible)

  function urgencyColor(urgency) {
    if (urgency === NotificationUrgency.Critical)
      return Theme.crit;
    if (urgency === NotificationUrgency.Low)
      return Theme.muted;
    return Theme.accent;
  }

  NotificationServer {
    id: server

    // Advertised capabilities. These are read by clients when they connect, so
    // claiming something unimplemented means apps send payloads that silently
    // do nothing -- only turn one on once the UI below actually honours it.
    bodySupported: true
    bodyMarkupSupported: true
    imageSupported: true
    actionsSupported: true
    actionIconsSupported: false
    inlineReplySupported: false
    // A hot reload rebuilds this object; without this, every notification on
    // screen vanishes whenever a QML file is saved.
    keepOnReload: true

    onNotification: notification => {
      // Nothing is retained unless explicitly tracked; this is what puts it
      // into trackedNotifications and therefore on screen.
      notification.tracked = true;
    }
  }

  PanelWindow {
    id: win

    // Follow the focused monitor, like dunst's follow=keyboard.
    screen: {
      const focused = Hyprland.focusedMonitor?.name ?? "";
      for (const s of Quickshell.screens)
        if (s.name === focused)
          return s;
      return null;
    }

    // No notifications means no surface at all: an always-mapped window would
    // sit over the top-right corner swallowing clicks.
    visible: root.tracked.length > 0

    anchors {
      top: true
      right: true
    }
    margins {
      top: Theme.barHeight + 14
      right: 18
    }

    implicitWidth: 460
    implicitHeight: Math.max(1, column.implicitHeight)
    color: "transparent"

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Notifications are clickable, so no input mask -- but the window is only
    // mapped while something is showing, so it never blocks an empty corner.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    ColumnLayout {
      id: column
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: 8

      Repeater {
        model: root.shown

        Rectangle {
          id: card
          required property var modelData

          readonly property color accent: root.urgencyColor(modelData.urgency)
          readonly property int dwell: root.timeouts[modelData.urgency] ?? 6000

          Layout.fillWidth: true
          implicitHeight: content.implicitHeight + 28
          radius: 12
          color: Theme.surface
          border.width: 2
          border.color: accent

          // Slide in from the right rather than appearing: on a 32" panel a
          // popup that simply materialises in the corner is easy to miss.
          opacity: 0
          x: 40
          Component.onCompleted: entry.start()

          ParallelAnimation {
            id: entry
            NumberAnimation {
              target: card
              property: "opacity"
              to: 1
              duration: Theme.animSlow
              easing.type: Easing.OutCubic
            }
            NumberAnimation {
              target: card
              property: "x"
              to: 0
              duration: Theme.animSlow
              easing.type: Easing.OutCubic
            }
          }

          // `dwell === 0` means critical: no timer at all.
          Timer {
            interval: card.dwell
            running: card.dwell > 0
            onTriggered: card.modelData.expire()
          }

          RowLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 12

            // The notification's own image (album art, avatar) wins over the
            // sending app's icon, which is what every other client does.
            Item {
              Layout.alignment: Qt.AlignTop
              Layout.preferredWidth: 40
              Layout.preferredHeight: 40
              visible: img.status === Image.Ready || appIcon.status === Image.Ready

              Image {
                id: img
                anchors.fill: parent
                source: card.modelData.image ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 80
                sourceSize.height: 80
                visible: status === Image.Ready
              }

              IconImage {
                id: appIcon
                anchors.fill: parent
                source: card.modelData.appIcon !== "" ? Quickshell.iconPath(card.modelData.appIcon, "dialog-information") : ""
                asynchronous: true
                visible: img.status !== Image.Ready
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 3

              RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                  Layout.fillWidth: true
                  text: card.modelData.summary
                  color: Theme.text
                  font.family: Theme.font
                  font.pixelSize: Theme.deskSmall
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  text: card.modelData.appName
                  color: Theme.muted
                  font.family: Theme.font
                  font.pixelSize: Theme.deskMeta - 2
                  visible: text !== "" && text !== card.modelData.summary
                }
              }

              Text {
                Layout.fillWidth: true
                text: card.modelData.body
                color: Theme.subtext
                font.family: Theme.font
                font.pixelSize: Theme.deskMeta
                wrapMode: Text.WordWrap
                maximumLineCount: 6
                elide: Text.ElideRight
                // bodyMarkupSupported is advertised, so the body may contain
                // the small HTML subset the spec allows.
                textFormat: Text.StyledText
                visible: text !== ""
              }

              // Action buttons -- the thing dunst cannot draw. Hidden entirely
              // when a notification ships none, which is most of them.
              RowLayout {
                Layout.topMargin: 4
                spacing: 6
                visible: card.modelData.actions.length > 0

                Repeater {
                  model: card.modelData.actions

                  Rectangle {
                    id: actionBtn
                    required property var modelData

                    implicitWidth: actionLabel.implicitWidth + 20
                    implicitHeight: 26
                    radius: 6
                    color: actionArea.containsMouse ? card.accent : Theme.module

                    Behavior on color {
                      ColorAnimation {
                        duration: Theme.anim
                      }
                    }

                    Text {
                      id: actionLabel
                      anchors.centerIn: parent
                      text: actionBtn.modelData.text
                      color: actionArea.containsMouse ? Theme.inverse : Theme.text
                      font.family: Theme.font
                      font.pixelSize: Theme.deskMeta - 1
                    }

                    MouseArea {
                      id: actionArea
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        actionBtn.modelData.invoke();
                        card.modelData.dismiss();
                      }
                    }
                  }
                }
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            // Sits under the action buttons in z-order so their clicks win.
            z: -1

            onClicked: mouse => {
              if (mouse.button === Qt.RightButton) {
                for (const n of root.tracked.slice())
                  n.dismiss();
              } else if (mouse.button === Qt.MiddleButton) {
                const actions = card.modelData.actions;
                if (actions.length > 0)
                  actions[0].invoke();
                card.modelData.dismiss();
              } else {
                card.modelData.dismiss();
              }
            }
          }
        }
      }

      // Overflow count, mirroring dunst's indicate_hidden.
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 26
        radius: 8
        color: Theme.surface
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.15)
        visible: root.overflow > 0

        Text {
          anchors.centerIn: parent
          text: `${root.overflow} more`
          color: Theme.muted
          font.family: Theme.font
          font.pixelSize: Theme.deskMeta - 1
        }
      }
    }
  }
}
