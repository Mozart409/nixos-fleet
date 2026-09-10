import QtQuick
import QtQuick.Layouts

// Month view for the clock popup. Monday-first, ISO week numbering, with the
// current day highlighted. `monthOffset` lets the arrows page around without
// touching `today`.
ColumnLayout {
  id: root

  required property date today
  property int monthOffset: 0

  readonly property date shown: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)

  // Weekday index with Monday as 0 (JS getDay() puts Sunday at 0).
  function mondayIndex(date) {
    return (date.getDay() + 6) % 7;
  }

  spacing: 8

  RowLayout {
    Layout.fillWidth: true

    Text {
      text: "󰅁"
      color: prevArea.containsMouse ? Theme.accent : Theme.muted
      font.family: Theme.iconFont
      font.pixelSize: Theme.fontSize

      MouseArea {
        id: prevArea
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.monthOffset--
      }
    }

    Text {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      text: Qt.formatDate(root.shown, "MMMM yyyy")
      color: Theme.text
      font.family: Theme.font
      font.pixelSize: Theme.fontSize
      font.bold: true

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // Click the title to snap back to the current month.
        onClicked: root.monthOffset = 0
      }
    }

    Text {
      text: "󰅂"
      color: nextArea.containsMouse ? Theme.accent : Theme.muted
      font.family: Theme.iconFont
      font.pixelSize: Theme.fontSize

      MouseArea {
        id: nextArea
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.monthOffset++
      }
    }
  }

  GridLayout {
    Layout.fillWidth: true
    columns: 7
    columnSpacing: 0
    rowSpacing: 2

    Repeater {
      model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

      Text {
        required property string modelData
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: modelData
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: Theme.smallSize - 1
      }
    }

    // Six rows of seven always -- a fixed cell count keeps the popup from
    // resizing as you page through months of different lengths.
    Repeater {
      model: 42

      Item {
        required property int index

        readonly property date cell: {
          const first = root.shown;
          const lead = root.mondayIndex(first);
          return new Date(first.getFullYear(), first.getMonth(), 1 - lead + index);
        }
        readonly property bool inMonth: cell.getMonth() === root.shown.getMonth()
        readonly property bool isToday: cell.toDateString() === root.today.toDateString()

        Layout.fillWidth: true
        implicitHeight: 26

        Rectangle {
          anchors.centerIn: parent
          width: 24
          height: 22
          radius: 6
          color: parent.isToday ? Theme.accent : "transparent"
        }

        Text {
          anchors.centerIn: parent
          text: parent.cell.getDate()
          color: {
            if (parent.isToday)
              return Theme.inverse;
            return parent.inMonth ? Theme.text : Theme.muted;
          }
          font.family: Theme.font
          font.pixelSize: Theme.smallSize
          font.bold: parent.isToday
          opacity: parent.inMonth ? 1 : 0.45
        }
      }
    }
  }
}
