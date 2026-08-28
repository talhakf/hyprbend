import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  // ---- tunables -----------------------------------------------------
  property real arcTowardCenter: 0.55   // 0 = straight chord, 1 = bows fully to screen center
  property int  rayCount: 70             // number of light streaks
  property int  duration: 900             // ms — total envelope: fade in, hold, fade out
  property real speed: 2.4                // loops/second — how fast streaks flow along their path
                                           // (independent of duration: raising duration only makes
                                           // the effect last longer, not the streaks flow faster/slower)

  property bool opened: false
  property string fromSide: "bottom"
  property string toSide: "right"
  property real travel: 0   // 0..1, drives only the overall fade-in/fade-out envelope

  function open(payloadJson) {
    var p = {}
    try { p = JSON.parse(payloadJson || "{}") } catch (e) {}
    fromSide = p.from || "bottom"
    toSide = p.to || "right"
    travel = 0
    content.opacity = 1
    opened = true
    buildRays()
    sweepAnim.restart()
    revealTimer.restart()
    bitCanvas.requestPaint()
  }

  function close() {
    opened = false
    sweepAnim.stop()
    revealTimer.stop()
  }

  NumberAnimation {
    id: sweepAnim
    target: root
    property: "travel"
    from: 0; to: 1
    duration: root.duration
    easing.type: Easing.Linear   // envelope shaping happens by hand in onPaint, keep this linear
  }

  Timer {
    id: revealTimer
    interval: root.duration + 200
    repeat: false
    onTriggered: fadeAnim.start()
  }

  NumberAnimation {
    id: fadeAnim
    target: content
    property: "opacity"
    to: 0
    duration: 180
    onFinished: root.close()
  }

  onTravelChanged: bitCanvas.requestPaint()

  // ---- geometry helpers ----------------------------------------------
  // point at `spread` (0..1) along an edge; `overshoot` pushes the point
  // past the screen boundary so streaks fly fully off-screen at the end
  function edgePoint(edge, spread, overshoot, w, h) {
    switch (edge) {
      case "top":    return { x: spread * w, y: -overshoot * h }
      case "bottom": return { x: spread * w, y: h + overshoot * h }
      case "left":   return { x: -overshoot * w, y: spread * h }
      case "right":  return { x: w + overshoot * w, y: spread * h }
      default:       return { x: w / 2, y: h / 2 }
    }
  }

  // top/right run clockwise around the screen perimeter as spread increases,
  // bottom/left run counter-clockwise. Two chords whose endpoints both run
  // the same rotational direction cross each other; opposite directions fan
  // out in parallel. We flip the destination spread only for adjacent
  // (corner-sharing) edge pairs so they always cross, while leaving opposite
  // edge pairs (top<->bottom, left<->right) parallel like before.
  function edgeSign(edge) { return (edge === "top" || edge === "right") ? 1 : -1 }
  function isOpposite(a, b) {
    return (a === "top" && b === "bottom") || (a === "bottom" && b === "top") ||
           (a === "left" && b === "right") || (a === "right" && b === "left")
  }

  function bezierPt(p0, p1, p2, t) {
    var u = 1 - t
    return {
      x: u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
      y: u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y
    }
  }
  function frac(x) { return x - Math.floor(x) }

  function buildRays() {
    var arr = []
    for (var i = 0; i < rayCount; i++) {
      arr.push({
        spread: 0.04 + 0.92 * Math.random(),
        bow: (Math.random() - 0.5) * 0.9,
        // phase spreads rays across the WHOLE path immediately, so the
        // trajectory is already full of light at travel=0 (no falling-star pop-in)
        phase: Math.random(),
        speedJitter: 0.75 + Math.random() * 0.6,
        width: 1.0 + Math.random() * 2.4,
        trail: 0.10 + Math.random() * 0.22,
        hue: Math.floor(Math.random() * 8)
      })
    }
    bitCanvas.bits = arr
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-hyprbend"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    Rectangle {
      id: content
      anchors.fill: parent
      color: "#000000"
      opacity: 0

      Canvas {
        id: bitCanvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        property var bits: []

        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          if (!root.opened) return
          var w = width, h = height
          if (w < 1 || h < 1) return

          var colors = [
            Color.accent, Qt.lighter(Color.accent, 1.3),
            Color.urgent, Color.foreground,
            Qt.lighter(Color.foreground, 1.2), Color.muted,
            Qt.darker(Color.urgent, 1.4), Qt.lighter(Color.muted, 1.5)
          ]

          var center = { x: w / 2, y: h / 2 }
          var travel = root.travel

          // whole-effect envelope: fades the tunnel in, holds, fades out
          var overall = 1
          if (travel < 0.12) overall = travel / 0.12
          else if (travel > 0.82) overall = Math.max(0, (1 - travel) / 0.18)

          // real elapsed seconds since this sweep started. travel*DURATION
          // is exactly elapsed ms regardless of DURATION's value, which is
          // what lets SPEED (loops/sec) stay decoupled from DURATION.
          var elapsedSec = (travel * root.duration) / 1000

          var flip = (!isOpposite(root.fromSide, root.toSide) &&
                      edgeSign(root.fromSide) !== edgeSign(root.toSide))

          ctx.globalCompositeOperation = "lighter"

          for (var i = 0; i < bitCanvas.bits.length; i++) {
            var ray = bitCanvas.bits[i]
            var p = frac(elapsedSec * root.speed * ray.speedJitter + ray.phase)
            var headT = p
            var tailT = Math.max(0, p - ray.trail)
            if (headT - tailT < 0.004) continue

            var destSpread = flip ? (1 - ray.spread) : ray.spread
            var p0 = edgePoint(root.fromSide, ray.spread, 0, w, h)
            var p2 = edgePoint(root.toSide, destSpread, 0.12, w, h)
            var mid = { x: (p0.x + p2.x) / 2, y: (p0.y + p2.y) / 2 }
            var control = {
              x: mid.x + (center.x - mid.x) * root.arcTowardCenter + ray.bow * 0.10 * w,
              y: mid.y + (center.y - mid.y) * root.arcTowardCenter + ray.bow * 0.10 * h
            }

            var steps = 10
            ctx.beginPath()
            for (var s = 0; s <= steps; s++) {
              var tt = tailT + (headT - tailT) * (s / steps)
              var pt = bezierPt(p0, control, p2, tt)
              if (s === 0) ctx.moveTo(pt.x, pt.y); else ctx.lineTo(pt.x, pt.y)
            }
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            var c = colors[ray.hue]

            // outer glow pass
            ctx.strokeStyle = c
            ctx.lineWidth = ray.width * 3.2
            ctx.globalAlpha = 0.15 * overall
            ctx.stroke()

            // bright core pass
            ctx.lineWidth = ray.width
            ctx.globalAlpha = 0.85 * overall
            ctx.stroke()
          }
          ctx.globalAlpha = 1
          ctx.globalCompositeOperation = "source-over"
        }
      }
    }
  }

  IpcHandler {
    target: "hyprbend"
    function open(payloadJson: string): string { root.open(payloadJson); return "ok" }
    function close(): string { root.close(); return "ok" }
    function state(): string { return root.opened ? "open" : "closed" }
    function ping(): string { return "ok" }
  }
}
