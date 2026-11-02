import QtQuick
import QtQuick.Layouts

// One resource readout: icon, live percentage, and a scrolling history graph.
// The numbers come from a ResourceStats reading, sampled once and shared by
// every screen's bar; this widget only draws it.
//
//   ResourceWidget {
//     icon: "󰍛"; label: "MEM"
//     reading: stats.mem
//   }
BarModule {
  id: root

  // A ResourceStats.Reading: value, sub (text after the value) and history.
  required property var reading
  property string label: ""
  property string unit: "%"
  property string subUnit: ""
  property bool graph: true
  // Set false for values where low is bad (free disk space).
  property bool higherIsWorse: true

  readonly property real _value: reading.value
  readonly property string _sub: reading.sub

  accent: isNaN(_value) ? Theme.muted : (higherIsWorse ? Theme.loadColor(_value) : Theme.headroomColor(_value))
  filled: false
  spacing: 5

  Text {
    text: root.label
    color: Theme.muted
    font.family: Theme.font
    font.pixelSize: Theme.smallSize - 1
    visible: root.label !== ""
  }

  Text {
    // Reserve the width of the widest reading so the neighbouring modules
    // don't shuffle sideways every time the number changes digits.
    Layout.minimumWidth: widest.width
    horizontalAlignment: Text.AlignRight
    text: isNaN(root._value) ? "--" + root.unit : Math.round(root._value) + root.unit
    color: root.accent
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    font.bold: true

    Behavior on color {
      ColorAnimation {
        duration: Theme.anim
      }
    }
  }

  Text {
    text: root._sub + root.subUnit
    color: Theme.muted
    font.family: Theme.font
    font.pixelSize: Theme.smallSize - 1
    visible: root._sub !== ""
  }

  Sparkline {
    visible: root.graph
    values: root.reading.history
    stroke: root.accent
    maxValue: 100
  }

  TextMetrics {
    id: widest
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    font.bold: true
    text: "100" + root.unit
  }
}
