import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris

// Floating music player widget - bottom left corner
PanelWindow {
  id: musicWidget

  anchors {
    bottom: true
    left: true
  }

  margins {
    bottom: 60
    left: 20
  }

  implicitWidth: 280
  implicitHeight: 100
  color: "transparent"

  // White border container
  Rectangle {
    anchors.fill: parent
    color: "#1a1a1fcc"
    radius: 8
    border.width: 1
    border.color: "#ffffff44"
  }

  // Place below normal windows (desktop widget)
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "quickshell-music"

  // Get the first active player
  property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

  RowLayout {
    anchors.fill: parent
    anchors.margins: 12
    spacing: 12

    // Album art placeholder
    Rectangle {
      width: 76
      height: 76
      radius: 8
      color: "#2a2a2f"

      Image {
        anchors.fill: parent
        anchors.margins: 2
        source: musicWidget.player?.trackArtUrl ?? ""
        fillMode: Image.PreserveAspectCrop
        visible: musicWidget.player?.trackArtUrl !== ""

        Rectangle {
          anchors.fill: parent
          radius: 6
          color: "transparent"
          border.width: 0
        }
      }

      Text {
        anchors.centerIn: parent
        text: ""
        color: "#595959"
        font.families: ["Berkeley Mono", "FiraCode Nerd Font"]
        font.pixelSize: 32
        visible: !musicWidget.player?.trackArtUrl
      }
    }

    // Track info and controls
    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 4

      // Track title
      Text {
        Layout.fillWidth: true
        text: musicWidget.player?.trackTitle ?? "No music playing"
        color: "#cfd6f4"
        font.families: ["Berkeley Mono", "FiraCode Nerd Font"]
        font.pixelSize: 12
        font.bold: true
        elide: Text.ElideRight
      }

      // Artist
      Text {
        Layout.fillWidth: true
        text: musicWidget.player?.trackArtists?.join(", ") ?? ""
        color: "#a6adc8"
        font.families: ["Berkeley Mono", "FiraCode Nerd Font"]
        font.pixelSize: 10
        elide: Text.ElideRight
        visible: musicWidget.player?.trackArtists?.length > 0
      }

      Item { Layout.fillHeight: true }

      // Playback controls
      RowLayout {
        spacing: 16

        // Previous
        Text {
          text: "󰒮"
          color: musicWidget.player?.canGoPrevious ? "#cfd6f4" : "#595959"
          font.families: ["Berkeley Mono", "FiraCode Nerd Font"]
          font.pixelSize: 18

          MouseArea {
            anchors.fill: parent
            enabled: musicWidget.player?.canGoPrevious ?? false
            onClicked: musicWidget.player.previous()
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          }
        }

        // Play/Pause
        Text {
          text: musicWidget.player?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
          color: musicWidget.player?.canTogglePlaying ? "#33ccff" : "#595959"
          font.families: ["Berkeley Mono", "FiraCode Nerd Font"]
          font.pixelSize: 24

          MouseArea {
            anchors.fill: parent
            enabled: musicWidget.player?.canTogglePlaying ?? false
            onClicked: musicWidget.player.togglePlaying()
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          }
        }

        // Next
        Text {
          text: "󰒭"
          color: musicWidget.player?.canGoNext ? "#cfd6f4" : "#595959"
          font.families: ["Berkeley Mono", "FiraCode Nerd Font"]
          font.pixelSize: 18

          MouseArea {
            anchors.fill: parent
            enabled: musicWidget.player?.canGoNext ?? false
            onClicked: musicWidget.player.next()
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          }
        }
      }
    }
  }

  // Show/hide based on player availability
  visible: musicWidget.player !== null
}
