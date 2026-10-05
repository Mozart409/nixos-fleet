import QtQuick
import QtQuick.Layouts

// The pill every bar widget sits in. Owns the shape, the hover feedback and
// the click plumbing so individual widgets only describe their contents:
//
//   BarModule {
//     icon: "󰍛"
//     accent: Theme.good
//     onClicked: ...
//     Text { ... }        // default children land in the row
//   }
//
// Width follows the content; height is fixed so every module lines up.
Rectangle {
  id: root

  // Optional Nerd Font glyph rendered before the content.
  property string icon: ""
  // Tint for the icon and the hover border. Defaults to plain body text so an
  // un-themed module still looks deliberate.
  property color accent: Theme.text
  // Set true to draw the module in its "active" state (filled with `accent`).
  property bool active: false
  // Turn off to get a bare row with no pill behind it.
  property bool filled: true

  property alias hovered: hover.hovered
  property alias spacing: row.spacing
  // Extra children declared by the caller are reparented into the row below.
  default property alias moduleContent: row.data

  signal clicked(var mouse)
  signal wheel(var wheel)

  implicitWidth: row.implicitWidth + Theme.pad * 2
  implicitHeight: Theme.moduleHeight
  radius: Theme.radius

  // Hover still lights up an unfilled module -- inside a ModuleGroup the group
  // owns the background, but each entry is individually clickable and needs to
  // say so.
  color: {
    if (active)
      return accent;
    if (hover.hovered)
      return Theme.moduleHover;
    return filled ? Theme.module : "transparent";
  }

  border.width: 1
  border.color: hover.hovered && !active ? Qt.alpha(accent, 0.45) : "transparent"

  Behavior on color {
    ColorAnimation {
      duration: Theme.anim
    }
  }
  Behavior on border.color {
    ColorAnimation {
      duration: Theme.anim
    }
  }

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 6

    Text {
      visible: root.icon !== ""
      text: root.icon
      color: root.active ? Theme.inverse : root.accent
      font.family: Theme.iconFont
      font.pixelSize: Theme.iconSize

      Behavior on color {
        ColorAnimation {
          duration: Theme.anim
        }
      }
    }
  }

  HoverHandler {
    id: hover
    cursorShape: Qt.PointingHandCursor
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: mouse => root.clicked(mouse)
    onWheel: wheel => root.wheel(wheel)
  }
}
