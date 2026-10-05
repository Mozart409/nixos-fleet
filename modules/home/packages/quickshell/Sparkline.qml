import QtQuick

// A tiny filled history graph. Push a fresh sample in with `push(value)` and
// it scrolls left, keeping the last `samples` points.
//
// The vertical scale auto-fits the window's own peak rather than pinning to
// `maxValue`, because a machine idling at 8% would otherwise draw a flat line
// along the bottom and tell you nothing. `scaleFloor` stops that from turning
// idle jitter into dramatic mountains -- below it, the graph really is flat.
Item {
  id: root

  property int samples: 32
  property real maxValue: 100
  property real scaleFloor: 30
  property bool autoScale: true
  property color stroke: Theme.accent

  property var values: []

  implicitWidth: 34
  implicitHeight: Theme.moduleHeight - 8

  function push(v) {
    const next = values.slice();
    next.push(Math.max(0, v));
    while (next.length > samples)
      next.shift();
    values = next;
    canvas.requestPaint();
  }

  // Faint plot area, so the graph reads as a graph even while it is flat.
  Rectangle {
    anchors.fill: parent
    radius: 3
    color: Qt.alpha(root.stroke, 0.08)
  }

  Canvas {
    id: canvas
    anchors.fill: parent
    anchors.margins: 1

    onPaint: {
      const ctx = getContext("2d");
      ctx.reset();
      if (root.values.length < 2)
        return;

      let peak = root.maxValue;
      if (root.autoScale) {
        peak = root.scaleFloor;
        for (const v of root.values)
          peak = Math.max(peak, v);
        peak = Math.min(peak * 1.15, root.maxValue);
      }
      peak = Math.max(peak, 1);

      const step = width / (root.samples - 1);
      // Right-align the history so a partially filled buffer grows in from the
      // right edge instead of stretching to fit.
      const x0 = width - (root.values.length - 1) * step;
      const y = i => height - Math.min(1, root.values[i] / peak) * (height - 1.5) - 0.75;

      const trace = () => {
        ctx.beginPath();
        ctx.moveTo(x0, y(0));
        for (let i = 1; i < root.values.length; i++)
          ctx.lineTo(x0 + i * step, y(i));
      };

      trace();
      ctx.lineTo(x0 + (root.values.length - 1) * step, height);
      ctx.lineTo(x0, height);
      ctx.closePath();
      ctx.fillStyle = Qt.alpha(root.stroke, 0.3);
      ctx.fill();

      // Re-stroke the open path so the fill's closing edges don't get outlined.
      trace();
      ctx.strokeStyle = root.stroke;
      ctx.lineWidth = 1.4;
      ctx.lineJoin = "round";
      ctx.stroke();
    }
  }

  // Canvas keeps its old pixels when the colour changes, so force a repaint.
  onStrokeChanged: canvas.requestPaint()
}
