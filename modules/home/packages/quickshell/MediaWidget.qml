import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

// Now playing, driven by MPRIS. Picks the player that is actually playing,
// falling back to the first one that exists so a paused Brave tab still shows.
//
// Left click toggles play/pause, scroll skips tracks, right click raises the
// player window. The title scrolls only when it doesn't fit.
BarModule {
  id: root

  // Width budget for the scrolling title. The bar sets this from the screen
  // width so the module gives way instead of running into the clock.
  property int maxLabelWidth: 210

  readonly property var player: {
    const players = Mpris.players.values;
    if (players.length === 0)
      return null;
    for (const p of players)
      if (p.isPlaying)
        return p;
    return players[0];
  }

  readonly property bool playing: player?.isPlaying ?? false
  readonly property string label: {
    if (!player)
      return "";
    const artist = player.trackArtist ?? "";
    const title = player.trackTitle ?? "";
    if (title === "")
      return player.identity ?? "";
    return artist === "" ? title : `${artist} — ${title}`;
  }

  visible: player !== null
  accent: playing ? Theme.special : Theme.muted
  icon: playing ? "󰎈" : "󰏤"

  onClicked: mouse => {
    if (!player)
      return;
    if (mouse.button === Qt.LeftButton && player.canTogglePlaying)
      player.togglePlaying();
    else if (mouse.button === Qt.RightButton && player.canRaise)
      player.raise();
  }

  onWheel: wheel => {
    if (!player)
      return;
    if (wheel.angleDelta.y < 0 && player.canGoNext)
      player.next();
    else if (wheel.angleDelta.y > 0 && player.canGoPrevious)
      player.previous();
  }

  RowLayout {
    id: mediaRow
    spacing: 7

    // Album art, if the player publishes one.
    Rectangle {
      Layout.preferredWidth: 16
      Layout.preferredHeight: 16
      radius: 3
      color: Theme.module
      clip: true
      visible: art.status === Image.Ready

      Image {
        id: art
        anchors.fill: parent
        source: root.player?.trackArtUrl ?? ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 32
        sourceSize.height: 32
      }
    }

    // Viewport for the marquee. Fixed width so the bar layout never jumps
    // when the track changes.
    Item {
      Layout.preferredWidth: Math.min(scrollText.implicitWidth, root.maxLabelWidth)
      Layout.preferredHeight: scrollText.implicitHeight
      clip: true

      Text {
        id: scrollText
        text: root.label
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.smallSize

        readonly property bool overflows: implicitWidth > parent.width

        // Scroll only what doesn't fit, pause at each end, then reverse --
        // less distracting than a continuous loop.
        SequentialAnimation on x {
          running: scrollText.overflows && root.playing
          loops: Animation.Infinite
          onStopped: scrollText.x = 0

          PauseAnimation {
            duration: 2000
          }
          NumberAnimation {
            to: Math.min(0, scrollText.parent.width - scrollText.implicitWidth)
            duration: Math.max(1, scrollText.implicitWidth - scrollText.parent.width) * 28
            easing.type: Easing.Linear
          }
          PauseAnimation {
            duration: 2000
          }
          NumberAnimation {
            to: 0
            duration: 400
            easing.type: Easing.OutCubic
          }
        }
      }
    }
  }
}
