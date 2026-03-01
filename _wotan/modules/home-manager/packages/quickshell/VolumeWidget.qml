import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

RowLayout {
  spacing: 8

  // Track the default audio sink
  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }

  property var sink: Pipewire.defaultAudioSink
  property real volume: sink?.audio?.volume ?? 0
  property bool muted: sink?.audio?.mute ?? false

  // Volume icon
  Text {
    text: {
      if (muted || volume === 0) return "󰝟"
      if (volume < 0.33) return "󰕿"
      if (volume < 0.66) return "󰖀"
      return "󰕾"
    }
    color: muted ? "#595959" : "#cfd6f4"
    font.family: "FiraCode Nerd Font"
    font.pixelSize: 14

    MouseArea {
      anchors.fill: parent
      onClicked: {
        if (sink?.audio) {
          sink.audio.mute = !sink.audio.mute
        }
      }
      cursorShape: Qt.PointingHandCursor
    }
  }

  // Volume slider
  Rectangle {
    width: 80
    height: 6
    radius: 3
    color: "#2a2a2f"

    Rectangle {
      width: parent.width * volume
      height: parent.height
      radius: 3
      color: muted ? "#595959" : "#33ccff"

      Behavior on width {
        NumberAnimation { duration: 50 }
      }
    }

    // Slider handle
    Rectangle {
      x: parent.width * volume - width / 2
      y: -2
      width: 10
      height: 10
      radius: 5
      color: muted ? "#595959" : "#cfd6f4"
      visible: sliderArea.containsMouse || sliderArea.pressed

      Behavior on x {
        NumberAnimation { duration: 50 }
      }
    }

    MouseArea {
      id: sliderArea
      anchors.fill: parent
      anchors.margins: -4
      hoverEnabled: true

      onPressed: updateVolume(mouse)
      onPositionChanged: if (pressed) updateVolume(mouse)

      function updateVolume(mouse) {
        if (sink?.audio) {
          let newVol = Math.max(0, Math.min(1, mouse.x / parent.width))
          sink.audio.volume = newVol
        }
      }
    }

    // Scroll to change volume
    MouseArea {
      anchors.fill: parent
      propagateComposedEvents: true
      
      onWheel: (wheel) => {
        if (sink?.audio) {
          let delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
          sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + delta))
        }
      }
    }
  }

  // Volume percentage
  Text {
    text: Math.round(volume * 100) + "%"
    color: muted ? "#595959" : "#a6adc8"
    font.family: "FiraCode Nerd Font"
    font.pixelSize: 11
    Layout.minimumWidth: 32
  }
}
