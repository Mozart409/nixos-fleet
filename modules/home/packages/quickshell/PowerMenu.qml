import QtQuick
import QtQuick.Layouts
import Quickshell
import "PowerActions.js" as PowerActions

// Session actions behind one button. The entries live in PowerActions.js,
// where they are tested.
BarModule {
  id: root

  property bool menuOpen: false

  readonly property var actions: PowerActions.actions

  icon: "󰐥"
  accent: menuOpen ? Theme.crit : Theme.subtext
  active: menuOpen

  onClicked: menuOpen = !menuOpen

  PopupWindow {
    id: popup
    visible: root.menuOpen
    color: "transparent"

    anchor {
      window: root.QsWindow.window
      // Right-aligned with the button: this module lives at the end of the bar,
      // so a centred popup would hang off the screen edge.
      rect.x: root.mapToItem(null, 0, 0).x + root.width - popup.width
      rect.y: root.mapToItem(null, 0, 0).y + root.height + 6
    }

    implicitWidth: 170
    implicitHeight: menuColumn.implicitHeight + 12

    Rectangle {
      anchors.fill: parent
      radius: 10
      color: Theme.surface
      border.width: 1
      border.color: Qt.alpha(Theme.crit, 0.3)

      ColumnLayout {
        id: menuColumn
        // Height flows outward to the popup (see CalendarGrid in
        // ClockWidget.qml for why filling the parent instead would collapse
        // it), so only the horizontal edges are anchored.
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        spacing: 2

        Repeater {
          model: root.actions

          Rectangle {
            id: entry
            required property var modelData

            Layout.fillWidth: true
            implicitHeight: 30
            radius: 6
            color: entryArea.containsMouse ? Qt.alpha(Theme[modelData.colour], 0.18) : "transparent"

            Behavior on color {
              ColorAnimation {
                duration: Theme.anim
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: 10

              Text {
                text: entry.modelData.icon
                color: Theme[entry.modelData.colour]
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSize
              }

              Text {
                Layout.fillWidth: true
                text: entry.modelData.label
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.smallSize
              }
            }

            MouseArea {
              id: entryArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.menuOpen = false;
                Quickshell.execDetached(entry.modelData.exec);
              }
            }
          }
        }
      }
    }
  }
}
