import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: kbdRoot

  property bool active: false
  property bool tabletMode: false
  property bool rotationLocked: false
  property bool dockMode: true
  property bool splitMode: false
  property bool spaceTrackpadActive: false
  property string layoutLang: "de"     // "de" (QWERTZ) or "en" (QWERTY)
  property string layerMode: "alpha"   // "alpha", "num", "sym"
  property bool shiftActive: false
  property bool capsLocked: false
  property bool ctrlLatched: false
  property bool altLatched: false
  property bool superLatched: false

  // Slide offset: 0 = fully open, panelHeight = fully hidden below bottom edge
  property int panelHeight: Style.space(310)
  property real slideOffset: panelHeight
  property real dragStartY: 0
  property real dragStartOffset: 0
  property bool dragging: false

  readonly property int swipeZoneHeight: tabletMode ? Style.space(22) : Style.space(14)
  readonly property int keySpacing: Style.spacing.sm
  readonly property int rowSpacing: Style.spacing.sm
  readonly property int outerPad: Style.spacing.lg
  readonly property int edgeMargin: dockMode ? 0 : Style.gapsOut
  readonly property int splitGap: splitMode ? Math.min(Style.space(260), Math.round(width * 0.22)) : 0

  readonly property color surfaceFg: Color.popups.text
  readonly property color surfaceBg: Color.popups.background
  readonly property color surfaceAccent: Color.accent
  readonly property var panelBorderSpec: Border.localOrSurfaceSpec(
    "popups",
    "border",
    Color.popups.border,
    Color.popups.border,
    Math.max(1, Style.space(2))
  )

  signal requestClose()
  signal requestOpen()
  signal requestToggleLock()
  signal requestToggleDock()

  onActiveChanged: {
    slideAnim.stop()
    slideAnim.to = active ? 0 : panelHeight
    slideAnim.start()
    if (!active) {
      repeatTimer.stop()
      spaceTrackpadActive = false
      ctrlLatched = false
      altLatched = false
      superLatched = false
      if (!capsLocked) shiftActive = false
    }
  }

  NumberAnimation {
    id: slideAnim
    target: kbdRoot
    property: "slideOffset"
    duration: 200
    easing.type: Easing.OutCubic
  }

  // Auto-repeat timer for BackSpace / Arrows / Space
  property var repeatKeySpec: null
  Timer {
    id: repeatInitialTimer
    interval: 380
    repeat: false
    onTriggered: {
      if (kbdRoot.repeatKeySpec) {
        kbdRoot.triggerKeyAction(kbdRoot.repeatKeySpec)
        repeatTimer.start()
      }
    }
  }
  Timer {
    id: repeatTimer
    interval: 55
    repeat: true
    onTriggered: {
      if (kbdRoot.repeatKeySpec) {
        kbdRoot.triggerKeyAction(kbdRoot.repeatKeySpec)
      } else {
        stop()
      }
    }
  }

  function startRepeat(spec) {
    triggerKeyAction(spec)
    if (spec && spec.repeatable) {
      repeatKeySpec = spec
      repeatInitialTimer.restart()
    }
  }

  function stopRepeat() {
    repeatInitialTimer.stop()
    repeatTimer.stop()
    repeatKeySpec = null
  }

  function sendWtype(args) {
    var cmd = ["wtype"]
    if (ctrlLatched)  { cmd.push("-M"); cmd.push("ctrl") }
    if (altLatched)   { cmd.push("-M"); cmd.push("alt") }
    if (superLatched) { cmd.push("-M"); cmd.push("logo") }

    for (var i = 0; i < args.length; i++) cmd.push(args[i])

    if (superLatched) { cmd.push("-m"); cmd.push("logo") }
    if (altLatched)   { cmd.push("-m"); cmd.push("alt") }
    if (ctrlLatched)  { cmd.push("-m"); cmd.push("ctrl") }

    Quickshell.execDetached(cmd)

    ctrlLatched = false
    altLatched = false
    superLatched = false
    if (shiftActive && !capsLocked) {
      shiftActive = false
    }
  }

  function triggerKeyAction(spec) {
    if (!spec) return
    var action = spec.action || "char"

    if (action === "shift") {
      if (shiftActive && !capsLocked) {
        capsLocked = true
      } else if (capsLocked) {
        capsLocked = false
        shiftActive = false
      } else {
        shiftActive = true
      }
      return
    }
    if (action === "layer") {
      layerMode = spec.target || "alpha"
      return
    }
    if (action === "lang") {
      layoutLang = (layoutLang === "de") ? "en" : "de"
      return
    }
    if (action === "split") {
      splitMode = !splitMode
      return
    }
    if (action === "rotlock") {
      requestToggleLock()
      return
    }
    if (action === "dock") {
      requestToggleDock()
      return
    }
    if (action === "mod") {
      if (spec.mod === "ctrl")  ctrlLatched = !ctrlLatched
      if (spec.mod === "alt")   altLatched = !altLatched
      if (spec.mod === "super") superLatched = !superLatched
      return
    }
    if (action === "hide") {
      requestClose()
      return
    }
    if (action === "key") {
      sendWtype(["-k", spec.key])
      return
    }

    // Character input
    var ch = spec.label || ""
    if (layerMode === "alpha") {
      var upper = shiftActive || capsLocked
      if (upper && spec.shiftLabel) ch = spec.shiftLabel
      else if (upper) ch = ch.toUpperCase()
    }
    if (ch.length > 0) {
      sendWtype(["--", ch])
    }
  }

  // Row definitions for alpha (DE / EN), num, and sym layers
  function getRows() {
    if (layerMode === "num") {
      return [
        [
          { label: "1" }, { label: "2" }, { label: "3" }, { label: "4" }, { label: "5" },
          { label: "6" }, { label: "7" }, { label: "8" }, { label: "9" }, { label: "0" }
        ],
        [
          { label: "@" }, { label: "#" }, { label: "€" }, { label: "%" }, { label: "&" },
          { label: "-" }, { label: "+" }, { label: "(" }, { label: ")" }, { label: "/" }
        ],
        [
          { label: "#+=", action: "layer", target: "sym", weight: 1.4, special: true },
          { label: "*" }, { label: "\"" }, { label: "'" }, { label: ":" },
          { label: ";" }, { label: "!" }, { label: "?" },
          { label: "󰁮", action: "key", key: "BackSpace", weight: 1.5, special: true, repeatable: true }
        ]
      ]
    }
    if (layerMode === "sym") {
      return [
        [
          { label: "~" }, { label: "`" }, { label: "|" }, { label: "•" }, { label: "√" },
          { label: "π" }, { label: "÷" }, { label: "×" }, { label: "§" }, { label: "∆" }
        ],
        [
          { label: "$" }, { label: "£" }, { label: "^" }, { label: "°" }, { label: "=" },
          { label: "{" }, { label: "}" }, { label: "\\" }, { label: "[" }, { label: "]" }
        ],
        [
          { label: "123", action: "layer", target: "num", weight: 1.4, special: true },
          { label: "<" }, { label: ">" }, { label: "_" }, { label: "«" },
          { label: "»" }, { label: "¦" }, { label: "¬" },
          { label: "󰁮", action: "key", key: "BackSpace", weight: 1.5, special: true, repeatable: true }
        ]
      ]
    }

    if (layoutLang === "en") {
      return [
        [
          { label: "q" }, { label: "w" }, { label: "e" }, { label: "r" }, { label: "t" },
          { label: "y" }, { label: "u" }, { label: "i" }, { label: "o" }, { label: "p" }
        ],
        [
          { label: "a" }, { label: "s" }, { label: "d" }, { label: "f" }, { label: "g" },
          { label: "h" }, { label: "j" }, { label: "k" }, { label: "l" }
        ],
        [
          { label: capsLocked ? "󰘲 CAPS" : "󰘶", action: "shift", weight: 1.4, special: true, highlighted: shiftActive || capsLocked },
          { label: "z" }, { label: "x" }, { label: "c" }, { label: "v" },
          { label: "b" }, { label: "n" }, { label: "m" },
          { label: "󰁮", action: "key", key: "BackSpace", weight: 1.5, special: true, repeatable: true }
        ]
      ]
    }

    // Default: German QWERTZ
    return [
      [
        { label: "q" }, { label: "w" }, { label: "e" }, { label: "r" }, { label: "t" },
        { label: "z" }, { label: "u" }, { label: "i" }, { label: "o" }, { label: "p" }, { label: "ü" }
      ],
      [
        { label: "a" }, { label: "s" }, { label: "d" }, { label: "f" }, { label: "g" },
        { label: "h" }, { label: "j" }, { label: "k" }, { label: "l" }, { label: "ö" }, { label: "ä" }
      ],
      [
        { label: capsLocked ? "󰘲 CAPS" : "󰘶", action: "shift", weight: 1.35, special: true, highlighted: shiftActive || capsLocked },
        { label: "y" }, { label: "x" }, { label: "c" }, { label: "v" },
        { label: "b" }, { label: "n" }, { label: "m" }, { label: "ß", shiftLabel: "?" },
        { label: "󰁮", action: "key", key: "BackSpace", weight: 1.45, special: true, repeatable: true }
      ]
    ]
  }

  function getBottomRow() {
    var isAlpha = (layerMode === "alpha")
    return [
      { label: isAlpha ? "?123" : "ABC", action: "layer", target: isAlpha ? "num" : "alpha", weight: 1.3, special: true },
      { label: layoutLang.toUpperCase(), action: "lang", weight: 0.9, special: true },
      { label: ",", shiftLabel: ";" },
      {
        label: spaceTrackpadActive ? "󰅁  CURSOR  󰅂" : (layoutLang === "de" ? "LEERTASTE" : "SPACE"),
        action: "key",
        key: "space",
        weight: 4.2,
        isSpace: true,
        repeatable: true,
        highlighted: spaceTrackpadActive
      },
      { label: ".", shiftLabel: ":" },
      { label: "-", shiftLabel: "_" },
      { label: "󰌑", action: "key", key: "Return", weight: 1.45, accent: true },
      { label: "󰌌 󰅀", action: "hide", weight: 1.1, special: true }
    ]
  }

  function getUtilityRow() {
    return [
      { label: "ESC", action: "key", key: "Escape", weight: 0.95, special: true },
      { label: "TAB", action: "key", key: "Tab", weight: 0.95, special: true },
      { label: "CTRL", action: "mod", mod: "ctrl", weight: 0.95, special: true, highlighted: ctrlLatched },
      { label: "ALT", action: "mod", mod: "alt", weight: 0.95, special: true, highlighted: altLatched },
      { label: "SUPER", action: "mod", mod: "super", weight: 1.05, special: true, highlighted: superLatched },
      { label: "󰅁", action: "key", key: "Left", weight: 0.85, special: true, repeatable: true },
      { label: "󰅀", action: "key", key: "Down", weight: 0.85, special: true, repeatable: true },
      { label: "󰅃", action: "key", key: "Up", weight: 0.85, special: true, repeatable: true },
      { label: "󰅂", action: "key", key: "Right", weight: 0.85, special: true, repeatable: true },
      { label: rotationLocked ? "󰌾 LOCK" : "󰌿 ROT", action: "rotlock", weight: 1.15, special: true, highlighted: rotationLocked },
      { label: dockMode ? "󰘔 DOCK" : "󰖲 FLOAT", action: "dock", weight: 1.1, special: true, highlighted: dockMode },
      { label: splitMode ? "󰯍 FULL" : "󰯌 SPLIT", action: "split", weight: 1.1, special: true, highlighted: splitMode },
      { label: "󰅀 HIDE", action: "hide", weight: 1.25, special: true }
    ]
  }

  // Expose the active input mask target for PanelWindow
  property alias activeSurface: kbdSurface
  property alias swipeHandleItem: bottomSwipeBar

  // 1. Bottom-edge swipe-up gesture handle (only visible & interactive in tent/tablet mode)
  Item {
    id: bottomSwipeBar
    width: Math.round(parent.width * 0.85)
    height: kbdRoot.swipeZoneHeight
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    visible: kbdRoot.tabletMode && (!kbdRoot.active || swipeMouse.pressed)

    BorderSurface {
      id: swipePill
      width: swipeMouse.containsMouse || swipeMouse.pressed ? Style.space(136) : Style.space(96)
      height: swipeMouse.containsMouse || swipeMouse.pressed ? Style.space(6) : Style.space(4)
      radius: Style.cornerRadius
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.spacing.sm
      color: swipeMouse.containsMouse || swipeMouse.pressed
        ? kbdRoot.surfaceAccent
        : Util.alpha(kbdRoot.surfaceFg, 0.55)
      borderSpec: Border.none()
      visible: kbdRoot.tabletMode && !kbdRoot.active && kbdRoot.slideOffset > kbdRoot.panelHeight - 20

      Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
      id: swipeMouse
      anchors.fill: parent
      enabled: kbdRoot.tabletMode
      hoverEnabled: true
      preventStealing: true

      property real startGlobalY: 0

      onPressed: function(mouse) {
        startGlobalY = mapToItem(kbdRoot, 0, mouse.y).y
        slideAnim.stop()
      }

      onPositionChanged: function(mouse) {
        if (!pressed) return
        var curY = mapToItem(kbdRoot, 0, mouse.y).y
        var dy = curY - startGlobalY
        if (dy < 0) {
          kbdRoot.slideOffset = Math.max(0, Math.min(kbdRoot.panelHeight, kbdRoot.panelHeight + dy))
        }
      }

      onReleased: function(mouse) {
        var curY = mapToItem(kbdRoot, 0, mouse.y).y
        var dy = curY - startGlobalY
        if (dy < -14 || Math.abs(dy) < 6) {
          kbdRoot.requestOpen()
          slideAnim.stop()
          slideAnim.to = 0
          slideAnim.start()
        } else {
          slideAnim.stop()
          slideAnim.to = kbdRoot.panelHeight
          slideAnim.start()
        }
      }
    }
  }

  // 2. Main Keyboard Surface — uses Omarchy's native BorderSurface & [popups] theme tokens
  BorderSurface {
    id: kbdSurface
    width: parent.width - kbdRoot.edgeMargin * 2
    height: kbdRoot.panelHeight
    x: kbdRoot.edgeMargin
    y: parent.height - height + kbdRoot.slideOffset
    visible: kbdRoot.active || kbdRoot.slideOffset < kbdRoot.panelHeight
    color: kbdRoot.surfaceBg
    borderSpec: kbdRoot.panelBorderSpec
    radius: Style.cornerRadius

    // Top drag-handle bar (swipe down to close)
    Item {
      id: topHandleArea
      anchors.top: parent.top
      anchors.topMargin: kbdSurface.borderTop
      anchors.left: parent.left
      anchors.right: parent.right
      height: Style.space(20)

      Rectangle {
        width: topDragMouse.pressed || topDragMouse.containsMouse ? Style.space(76) : Style.space(52)
        height: Style.space(3)
        radius: Style.cornerRadius
        anchors.centerIn: parent
        color: topDragMouse.pressed || topDragMouse.containsMouse
          ? kbdRoot.surfaceAccent
          : Util.alpha(kbdRoot.surfaceFg, 0.35)
        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 120 } }
      }

      MouseArea {
        id: topDragMouse
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        property real pressGlobalY: 0

        onPressed: function(mouse) {
          pressGlobalY = mapToItem(kbdRoot, 0, mouse.y).y
          kbdRoot.dragging = true
          slideAnim.stop()
        }
        onPositionChanged: function(mouse) {
          if (!pressed) return
          var curY = mapToItem(kbdRoot, 0, mouse.y).y
          var dy = curY - pressGlobalY
          kbdRoot.slideOffset = Math.max(0, Math.min(kbdRoot.panelHeight, dy))
        }
        onReleased: function(mouse) {
          kbdRoot.dragging = false
          if (kbdRoot.slideOffset > 55) {
            kbdRoot.requestClose()
          } else {
            slideAnim.to = 0
            slideAnim.start()
          }
        }
      }
    }

    // Keyboard rows container
    Column {
      id: rowsCol
      anchors.top: topHandleArea.bottom
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: kbdSurface.borderLeft + kbdRoot.outerPad
      anchors.rightMargin: kbdSurface.borderRight + kbdRoot.outerPad
      anchors.bottomMargin: kbdSurface.borderBottom + kbdRoot.outerPad
      spacing: kbdRoot.rowSpacing

      readonly property var alphaRows: kbdRoot.getRows()
      readonly property var allRows: [
        kbdRoot.getUtilityRow(),
        alphaRows[0],
        alphaRows[1],
        alphaRows[2],
        kbdRoot.getBottomRow()
      ]

      Repeater {
        model: rowsCol.allRows.length

        delegate: Item {
          id: rowItem
          required property int index
          readonly property var rowKeys: rowsCol.allRows[index] || []
          readonly property bool isUtility: index === 0
          width: rowsCol.width
          height: isUtility
            ? Math.round((rowsCol.height - kbdRoot.rowSpacing * 4) * 0.145)
            : Math.round((rowsCol.height - kbdRoot.rowSpacing * 4) * 0.213)

          readonly property real totalWeight: {
            var sum = 0
            for (var i = 0; i < rowKeys.length; i++) {
              sum += (rowKeys[i].weight !== undefined ? rowKeys[i].weight : 1.0)
            }
            return sum > 0 ? sum : 1
          }

          readonly property int midIndex: Math.floor(rowKeys.length / 2)
          readonly property int activeSplitGap: (!isUtility && kbdRoot.splitMode) ? kbdRoot.splitGap : 0
          readonly property real availWidth: Math.max(100, width - kbdRoot.keySpacing * Math.max(0, rowKeys.length - 1) - activeSplitGap)

          Repeater {
            model: rowItem.rowKeys.length

            delegate: BorderSurface {
              id: keyRect
              required property int index
              readonly property var keySpec: rowItem.rowKeys[index]
              readonly property real kWeight: keySpec.weight !== undefined ? keySpec.weight : 1.0
              readonly property bool isHot: keyArea.containsMouse
              readonly property bool isSelected: Boolean(keySpec.highlighted || keySpec.accent)

              width: Math.floor(rowItem.availWidth * (kWeight / rowItem.totalWeight))
              height: rowItem.height
              x: {
                var pos = 0
                for (var i = 0; i < index; i++) {
                  var w = rowItem.rowKeys[i].weight !== undefined ? rowItem.rowKeys[i].weight : 1.0
                  pos += Math.floor(rowItem.availWidth * (w / rowItem.totalWeight)) + kbdRoot.keySpacing
                }
                if (rowItem.activeSplitGap > 0 && index >= rowItem.midIndex) {
                  pos += rowItem.activeSplitGap
                }
                return pos
              }
              y: 0

              radius: Style.cornerRadius

              // Exact Omarchy [controls] state precedence from qs.Ui.Button
              color: {
                if (keyArea.pressed) {
                  return Style.pressedFillFor(kbdRoot.surfaceFg, kbdRoot.surfaceAccent)
                }
                if (isSelected) {
                  return Style.selectedFillFor(kbdRoot.surfaceFg, kbdRoot.surfaceAccent)
                }
                if (isHot) {
                  return Style.hoverFillFor(kbdRoot.surfaceFg, kbdRoot.surfaceAccent)
                }
                if (keySpec.special) {
                  return Util.alpha(kbdRoot.surfaceFg, Math.min(1, Style.normalFillAlpha * 1.85))
                }
                return Style.normalFillFor(kbdRoot.surfaceFg, kbdRoot.surfaceAccent)
              }

              borderSpec: {
                if (keyArea.pressed || isSelected) {
                  return Border.flat(kbdRoot.surfaceAccent, Math.max(1, Style.normalBorderWidth))
                }
                if (isHot) {
                  return Border.controlSpec("hover-cursor", kbdRoot.surfaceFg, kbdRoot.surfaceAccent)
                }
                return Border.controlSpec("normal", kbdRoot.surfaceFg, kbdRoot.surfaceAccent)
              }

              Behavior on color { ColorAnimation { duration: 100 } }

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: {
                  var lbl = keySpec.label || ""
                  if (kbdRoot.layerMode === "alpha" && !keySpec.action && (kbdRoot.shiftActive || kbdRoot.capsLocked)) {
                    return keySpec.shiftLabel ? keySpec.shiftLabel : lbl.toUpperCase()
                  }
                  return lbl
                }
                font.family: Style.font.family
                font.pixelSize: rowItem.isUtility
                  ? Style.font.bodySmall
                  : (keySpec.special ? Style.font.body : Style.font.heading)
                font.bold: isSelected || keyArea.pressed
                color: (isSelected || keyArea.pressed)
                  ? kbdRoot.surfaceAccent
                  : kbdRoot.surfaceFg
              }

              // Subtle secondary shift symbol in top-right corner
              Text {
                textFormat: Text.PlainText
                visible: kbdRoot.layerMode === "alpha" && !rowItem.isUtility && keySpec.shiftLabel !== undefined && !kbdRoot.shiftActive && !kbdRoot.capsLocked
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Style.spacing.xs
                anchors.rightMargin: Style.spacing.md
                text: keySpec.shiftLabel || ""
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Util.alpha(kbdRoot.surfaceFg, 0.45)
              }

              MouseArea {
                id: keyArea
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true

                property real pressX: 0
                property real pressY: 0
                property real lastStepX: 0
                property real lastStepY: 0
                property bool spaceDragged: false

                onPressed: function(mouse) {
                  if (keyRect.keySpec.isSpace) {
                    pressX = mouse.x
                    pressY = mouse.y
                    lastStepX = mouse.x
                    lastStepY = mouse.y
                    spaceDragged = false
                  } else {
                    kbdRoot.startRepeat(keyRect.keySpec)
                  }
                }

                onPositionChanged: function(mouse) {
                  if (!pressed || !keyRect.keySpec.isSpace) return
                  if (!spaceDragged && Math.abs(mouse.x - pressX) >= 12) {
                    spaceDragged = true
                    kbdRoot.spaceTrackpadActive = true
                    lastStepX = mouse.x
                    lastStepY = mouse.y
                  }
                  if (spaceDragged) {
                    while (Math.abs(mouse.x - lastStepX) >= 15) {
                      var hKey = (mouse.x > lastStepX) ? "Right" : "Left"
                      kbdRoot.sendWtype(["-k", hKey])
                      lastStepX += (mouse.x > lastStepX) ? 15 : -15
                    }
                    while (Math.abs(mouse.y - lastStepY) >= 22) {
                      var vKey = (mouse.y > lastStepY) ? "Down" : "Up"
                      kbdRoot.sendWtype(["-k", vKey])
                      lastStepY += (mouse.y > lastStepY) ? 22 : -22
                    }
                  }
                }

                onReleased: function(mouse) {
                  if (keyRect.keySpec.isSpace) {
                    if (!spaceDragged) {
                      kbdRoot.triggerKeyAction(keyRect.keySpec)
                    }
                    spaceDragged = false
                    kbdRoot.spaceTrackpadActive = false
                  } else {
                    kbdRoot.stopRepeat()
                  }
                }

                onCanceled: {
                  spaceDragged = false
                  kbdRoot.spaceTrackpadActive = false
                  kbdRoot.stopRepeat()
                }
              }
            }
          }
        }
      }
    }
  }
}
