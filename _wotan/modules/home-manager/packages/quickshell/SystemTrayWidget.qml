import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// StatusNotifierItem tray.
//
// Click behaviour is menu-first: if an item publishes a DBusMenu, left click
// opens it. That is deliberate -- both trays on this machine (nm-applet and
// Steam) are libappindicator items under org.ayatana.NotificationItem, and
// those do not implement the SNI `Activate` method at all, so an
// activate-on-left-click bar looks broken when you click them. Items with no
// menu still get activate(); middle click is always the secondary action.
Item {
  id: root

  // Tray ids to leave out of the bar entirely. Steam is hidden because its
  // item is inert here: it exports no working menu and, being an
  // appindicator item, implements no activate action either -- so it was a
  // permanent icon that did nothing when clicked. Hiding it in the bar does
  // not stop Steam exporting it; turn the icon off in Steam itself under
  // Settings -> Interface if you want it gone at the source.
  property var hiddenItems: ["steam"]

  readonly property var items: SystemTray.items.values.filter(i => root.hiddenItems.indexOf(i.id) === -1)

  implicitWidth: items.length > 0 ? row.implicitWidth + Theme.pad * 2 : 0
  implicitHeight: Theme.moduleHeight
  visible: items.length > 0

  Rectangle {
    anchors.fill: parent
    radius: Theme.radius
    color: Theme.module
  }

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 8

    Repeater {
      model: root.items

      Item {
        id: entry
        required property var modelData

        implicitWidth: Theme.iconSize + 2
        implicitHeight: Theme.iconSize + 2



        IconImage {
          id: trayIcon
          anchors.fill: parent
          source: entry.modelData.icon
          asynchronous: true
          opacity: mouse.containsMouse ? 1.0 : 0.85

          Behavior on opacity {
            NumberAnimation {
              duration: Theme.anim
            }
          }
        }

        // NeedsAttention items get a dot so a background app can still shout.
        Rectangle {
          anchors.right: parent.right
          anchors.top: parent.top
          width: 5
          height: 5
          radius: 2.5
          color: Theme.crit
          visible: entry.modelData.status === Status.NeedsAttention
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

          onClicked: mouse => {
            const item = entry.modelData;
            if (mouse.button === Qt.MiddleButton) {
              item.secondaryActivate();
              return;
            }
            // Menu-first: see the note at the top of this file. Only items
            // that publish no menu at all fall through to activate().
            if (item.hasMenu)
              item.display(root.QsWindow.window, entry.x + entry.width / 2, root.height);
            else
              item.activate();
          }

          onWheel: wheel => {
            entry.modelData.scroll(wheel.angleDelta.y, false);
            entry.modelData.scroll(wheel.angleDelta.x, true);
          }
        }

      }
    }
  }
}
