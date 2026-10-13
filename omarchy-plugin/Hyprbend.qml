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
  property bool keyboardOpen: false
  property bool tabletMode: false
  property bool rotationLocked: false
  property bool dockKeyboard: true
  property int oskCustomHeight: 310
  property string fromSide: "bottom"
  property string toSide: "right"
  property real travel: 0   // 0..1, drives only the overall fade-in/fade-out envelope

  function applyMode(mode) {
    var isTab = (mode === "tablet" || mode === "tent")
    tabletMode = isTab
    if (!isTab) {
      keyboardOpen = false
    }
  }

  function setLockState(locked) {
    rotationLocked = locked
    var val = locked ? "1" : "0"
    Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"" + val + "\" > \"${XDG_RUNTIME_DIR:-/tmp}/hyprbend-lock\""])
  }

  Component.onCompleted: {
    initModeProc.running = true
  }

  Process {
    id: initModeProc
    command: [
      "sh", "-c",
      "m=$(cat \"${XDG_RUNTIME_DIR:-/tmp}/hyprbend-mode\" 2>/dev/null || echo ''); " +
      "l=$(cat \"${XDG_RUNTIME_DIR:-/tmp}/hyprbend-lock\" 2>/dev/null || echo '0'); " +
      "OSK_DEFAULT_LANG=de; OSK_DOCK_MODE=1; OSK_HEIGHT=310; " +
      "[ -f \"$HOME/.config/hyprbend/config.conf\" ] && . \"$HOME/.config/hyprbend/config.conf\" 2>/dev/null || true; " +
      "printf '%s|%s|%s|%s|%s\\n' \"$m\" \"$l\" \"$OSK_DEFAULT_LANG\" \"$OSK_DOCK_MODE\" \"$OSK_HEIGHT\""
    ]
    stdout: SplitParser {
      onRead: data => {
        var parts = (data || "").trim().split("|")
        if (parts.length >= 1 && parts[0].length > 0) root.applyMode(parts[0])
        if (parts.length >= 2) root.rotationLocked = (parts[1] === "1" || parts[1] === "true")
        if (parts.length >= 3 && (parts[2] === "de" || parts[2] === "en")) osk.layoutLang = parts[2]
        if (parts.length >= 4) root.dockKeyboard = (parts[3] !== "0" && parts[3] !== "false")
        if (parts.length >= 5) {
          var h = parseInt(parts[4], 10)
          if (!isNaN(h) && h >= 220 && h <= 520) root.oskCustomHeight = h
        }
      }
    }
  }

  function open(payloadJson) {
    var p = {}
    try { p = JSON.parse(payloadJson || "{}") } catch (e) {}
    if (p.keyboard) {
      if (p.keyboard === "close") {
        keyboardOpen = false
      } else if (tabletMode) {
        if (p.keyboard === "open") keyboardOpen = true
        else if (p.keyboard === "toggle") keyboardOpen = !keyboardOpen
      }
      return
    }
    if (p.mode) {
      applyMode(p.mode)
      return
    }
    if (p.rotationLock !== undefined) {
      rotationLocked = Boolean(p.rotationLock)
      return
    }
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

  PanelWindow {
    id: oskPanel
    visible: root.tabletMode || root.keyboardOpen || osk.slideOffset < osk.panelHeight
    anchors { bottom: true; left: true; right: true }
    implicitHeight: osk.panelHeight
    color: "transparent"
    WlrLayershell.namespace: "omarchy-hyprbend-osk"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: (root.keyboardOpen && root.dockKeyboard)
      ? ExclusionMode.Normal
      : ExclusionMode.Ignore
    mask: Region {
      item: (root.keyboardOpen || osk.slideOffset < osk.panelHeight - 2)
        ? osk.activeSurface
        : (root.tabletMode ? osk.swipeHandleItem : null)
    }

    VirtualKeyboard {
      id: osk
      anchors.fill: parent
      active: root.keyboardOpen
      tabletMode: root.tabletMode
      rotationLocked: root.rotationLocked
      dockMode: root.dockKeyboard
      panelHeight: root.oskCustomHeight
      onRequestOpen: if (root.tabletMode) root.keyboardOpen = true
      onRequestClose: root.keyboardOpen = false
      onRequestToggleLock: root.setLockState(!root.rotationLocked)
      onRequestToggleDock: root.dockKeyboard = !root.dockKeyboard
    }
  }

  IpcHandler {
    target: "hyprbend"
    function open(payloadJson: string): string { root.open(payloadJson); return "ok" }
    function close(): string { root.close(); return "ok" }
    function state(): string { return root.opened ? "open" : "closed" }
    function openKeyboard(): string {
      if (!root.tabletMode) return "disabled-in-laptop-mode"
      root.keyboardOpen = true
      return "ok"
    }
    function closeKeyboard(): string { root.keyboardOpen = false; return "ok" }
    function toggleKeyboard(): string {
      if (!root.tabletMode) return "disabled-in-laptop-mode"
      root.keyboardOpen = !root.keyboardOpen
      return root.keyboardOpen ? "open" : "closed"
    }
    function keyboardState(): string { return root.keyboardOpen ? "open" : (root.tabletMode ? "closed" : "disabled-in-laptop-mode") }
    function setMode(mode: string): string {
      root.applyMode(mode)
      return "ok"
    }
    function setRotationLock(locked: string): string {
      var isLocked = (locked === "1" || locked === "true" || locked === "locked" || locked === "on")
      root.setLockState(isLocked)
      return root.rotationLocked ? "locked" : "unlocked"
    }
    function toggleRotationLock(): string {
      root.setLockState(!root.rotationLocked)
      return root.rotationLocked ? "locked" : "unlocked"
    }
    function rotationLockState(): string {
      return root.rotationLocked ? "locked" : "unlocked"
    }
    function ping(): string { return "ok" }
  }
}
