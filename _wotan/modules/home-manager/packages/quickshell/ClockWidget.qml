import QtQuick
import QtQuick.Layouts

RowLayout {
  required property var time

  Text {
    color: "#cfd6f4"
    font.family: "FiraCode Nerd Font"
    font.pixelSize: 14
    font.bold: true
    text: Qt.formatDateTime(time.date, "ddd dd MMM  HH:mm")
  }
}
