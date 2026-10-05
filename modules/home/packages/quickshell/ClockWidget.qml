import QtQuick
import QtQuick.Layouts
import Quickshell

// Clock, with a month calendar hanging off a click.
BarModule {
  id: root

  required property var time

  // Second line, dimmer and smaller. Empty hides it.
  property string dateFormat: "ddd dd MMM"
  property string timeFormat: "HH:mm"

  property bool calendarOpen: false

  icon: "󰃭"
  accent: calendarOpen ? Theme.accent : Theme.subtext
  spacing: 8

  onClicked: mouse => {
    if (mouse.button === Qt.LeftButton)
      calendarOpen = !calendarOpen;
  }

  Text {
    text: Qt.formatDateTime(root.time.date, root.dateFormat)
    color: Theme.subtext
    font.family: Theme.font
    font.pixelSize: Theme.smallSize
  }

  Text {
    text: Qt.formatDateTime(root.time.date, root.timeFormat)
    color: Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    font.bold: true
  }

  PopupWindow {
    id: popup
    visible: root.calendarOpen
    color: "transparent"

    anchor {
      window: root.QsWindow.window
      rect.x: root.mapToItem(null, 0, 0).x + root.width / 2 - popup.width / 2
      rect.y: root.mapToItem(null, 0, 0).y + root.height + 6
    }

    implicitWidth: 250
    implicitHeight: calendarBody.implicitHeight + 24

    Rectangle {
      anchors.fill: parent
      radius: 10
      color: Theme.surface
      border.width: 1
      border.color: Qt.alpha(Theme.accent, 0.3)

      CalendarGrid {
        id: calendarBody
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        // Deliberately not anchors.fill: the popup takes its height from this
        // layout, so filling the popup would make the two define each other
        // and QML would break the loop by leaving the popup zero-height.
        today: root.time.date
      }
    }
  }
}
