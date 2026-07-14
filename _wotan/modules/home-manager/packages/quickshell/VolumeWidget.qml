import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

RowLayout {
  id: volumeWidget
  spacing: 8

  // Track the default audio sink
  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }

  property var sink: Pipewire.defaultAudioSink
  property real volume: sink?.audio?.volume ?? 0
  property bool muted: sink?.audio?.mute ?? false
  property bool popupVisible: false

  // Audio output selector (shows current device, click to switch)
  Rectangle {
    width: deviceName.width + 16
    height: 20
    radius: 4
    color: deviceArea.containsMouse ? "#3a3a3f" : "transparent"

    Text {
      id: deviceName
      anchors.centerIn: parent
      // Get short name from sink
      text: {
        let name = sink?.properties?.["node.nick"] ?? sink?.properties?.["node.description"] ?? sink?.name ?? "?"
        // Truncate to 12 chars
        return name.length > 12 ? name.substring(0, 12) + "…" : name
      }
      color: "#a6adc8"
      font.families: ["Berkeley Mono", "FiraCode Nerd Font"]
      font.pixelSize: 10
    }

    MouseArea {
      id: deviceArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor

      onClicked: {
        volumeWidget.popupVisible = !volumeWidget.popupVisible
      }
    }
  }

  // Volume icon
  Text {
    text: {
      if (muted || volume === 0) return "󰝟"
      if (volume < 0.33) return "󰕿"
      if (volume < 0.66) return "󰖀"
      return "󰕾"
    }
    color: muted ? "#595959" : "#cfd6f4"
    font.families: ["Berkeley Mono", "FiraCode Nerd Font"]
    font.pixelSize: 14

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: (mouse) => {
        if (mouse.button === Qt.LeftButton) {
          if (sink?.audio) {
            sink.audio.mute = !sink.audio.mute
          }
        } else if (mouse.button === Qt.RightButton) {
          // Open pwvucontrol for advanced control
          Qt.openUrlExternally("file:///run/current-system/sw/bin/pwvucontrol")
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
    font.families: ["Berkeley Mono", "FiraCode Nerd Font"]
    font.pixelSize: 11
    Layout.minimumWidth: 32
  }

  // Audio device selection popup
  PopupWindow {
    id: sinkPopup
    visible: volumeWidget.popupVisible
    anchor {
      window: volumeWidget.QsWindow.window
      rect.x: volumeWidget.mapToItem(null, 0, 0).x
      rect.y: volumeWidget.mapToItem(null, 0, 0).y + volumeWidget.height + 4
    }
    width: 280
    height: sinkList.contentHeight + 16

    color: "transparent"

    Rectangle {
      anchors.fill: parent
      color: "#1e1e24"
      border.color: "#33ccff44"
      border.width: 1
      radius: 8

      Column {
        id: sinkList
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        Text {
          text: "Audio Output"
          color: "#cfd6f4"
          font.families: ["Berkeley Mono", "FiraCode Nerd Font"]
          font.pixelSize: 11
          font.bold: true
        }

        Rectangle {
          width: parent.width
          height: 1
          color: "#33ccff44"
        }

        Repeater {
          model: Pipewire.nodes.values.filter(n => n.isSink && n.audio)

          Rectangle {
            required property var modelData
            width: sinkList.width
            height: 28
            radius: 4
            color: isDefault ? "#33ccff33" : (sinkItemArea.containsMouse ? "#3a3a3f" : "transparent")

            property bool isDefault: modelData === Pipewire.defaultAudioSink

            RowLayout {
              anchors.fill: parent
              anchors.margins: 4
              spacing: 8

              Text {
                text: isDefault ? "●" : "○"
                color: isDefault ? "#33ccff" : "#595959"
                font.pixelSize: 10
              }

              Text {
                text: modelData.properties?.["node.nick"] ?? modelData.properties?.["node.description"] ?? modelData.name ?? "Unknown"
                color: "#cfd6f4"
                font.families: ["Berkeley Mono", "FiraCode Nerd Font"]
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }

            MouseArea {
              id: sinkItemArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor

              onClicked: {
                Pipewire.defaultAudioSink = modelData
                volumeWidget.popupVisible = false
              }
            }
          }
        }
      }
    }

    // Close popup when clicking outside
    MouseArea {
      anchors.fill: parent
      z: -1
      onClicked: volumeWidget.popupVisible = false
    }
  }
}
