import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// Default sink volume. Scroll to adjust, left click to mute, right click for
// the full mixer, middle click to cycle outputs -- which is the one that
// matters on a machine that flips between speakers, headset and HDMI.
BarModule {
  id: root

  // Without a tracker Pipewire won't populate the volume/mute fields.
  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real volume: sink?.audio?.volume ?? 0
  readonly property bool muted: sink?.audio?.mute ?? false
  readonly property int percent: Math.round(volume * 100)

  readonly property string sinkName: {
    const props = sink?.properties;
    return props?.["node.nick"] ?? props?.["node.description"] ?? sink?.name ?? "";
  }

  icon: {
    if (muted || volume === 0)
      return "󰝟";
    if (volume < 0.34)
      return "󰕿";
    if (volume < 0.67)
      return "󰖀";
    return "󰕾";
  }
  // Over 100% is soft clipping territory -- worth flagging.
  accent: muted ? Theme.muted : (percent > 100 ? Theme.warn : Theme.accent)

  onClicked: mouse => {
    if (!sink?.audio)
      return;
    if (mouse.button === Qt.LeftButton) {
      sink.audio.mute = !sink.audio.mute;
    } else if (mouse.button === Qt.RightButton) {
      Quickshell.execDetached(["pwvucontrol"]);
    } else if (mouse.button === Qt.MiddleButton) {
      root.cycleSink();
    }
  }

  onWheel: wheel => {
    if (!sink?.audio)
      return;
    const step = wheel.angleDelta.y > 0 ? 0.02 : -0.02;
    // Cap at 1.0: PipeWire will happily go louder, and it sounds terrible.
    sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + step));
    sink.audio.mute = false;
  }

  // Round-robin through the available sinks.
  function cycleSink() {
    const sinks = Pipewire.nodes.values.filter(n => n.isSink && n.audio && !n.isStream);
    if (sinks.length < 2)
      return;
    const at = sinks.indexOf(Pipewire.defaultAudioSink);
    Pipewire.defaultAudioSink = sinks[(at + 1) % sinks.length];
  }

  Text {
    Layout.minimumWidth: volMetrics.width
    horizontalAlignment: Text.AlignRight
    text: root.muted ? "muted" : root.percent + "%"
    color: root.muted ? Theme.muted : Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
  }

  // Inline level bar -- reads faster than the number alone.
  Rectangle {
    Layout.preferredWidth: 34
    Layout.preferredHeight: 4
    Layout.alignment: Qt.AlignVCenter
    radius: 2
    color: Theme.module

    Rectangle {
      width: parent.width * Math.min(1, root.volume)
      height: parent.height
      radius: 2
      color: root.muted ? Theme.muted : root.accent

      Behavior on width {
        NumberAnimation {
          duration: Theme.anim
          easing.type: Easing.OutCubic
        }
      }
    }
  }

  TextMetrics {
    id: volMetrics
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    text: "muted"
  }
}
