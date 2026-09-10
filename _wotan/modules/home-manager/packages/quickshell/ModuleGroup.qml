import QtQuick
import QtQuick.Layouts

// Draws one pill around several related modules, with hairline separators in
// the gaps between them. Put `filled: false` modules inside: the group owns
// the background so the cluster reads as a single object instead of a row of
// loose numbers.
Rectangle {
  id: root

  property int itemSpacing: 8
  default property alias groupContent: row.data

  implicitWidth: row.implicitWidth + Theme.pad * 2
  implicitHeight: Theme.moduleHeight
  radius: Theme.radius
  color: Theme.module
  visible: row.implicitWidth > 0

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: root.itemSpacing
  }

  // Separators are drawn over the gaps rather than interleaved into the row,
  // so callers can add and remove modules without also maintaining dividers.
  // Widgets that hide themselves (no Bluetooth adapter, no tray items) drop
  // out of visibleChildren and take their divider with them.
  Repeater {
    model: Math.max(0, row.visibleChildren.length - 1)

    Rectangle {
      required property int index

      readonly property Item before: row.visibleChildren[index] ?? null

      x: before ? row.x + before.x + before.width + root.itemSpacing / 2 : 0
      y: (root.height - height) / 2
      width: 1
      height: Theme.moduleHeight - 12
      color: Qt.alpha(Theme.text, 0.13)
      visible: before !== null
    }
  }
}
