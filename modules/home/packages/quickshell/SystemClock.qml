import QtQuick
import Quickshell

Scope {
  id: root
  property date date: new Date()

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.date = new Date()
  }
}
