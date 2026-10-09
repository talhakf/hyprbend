import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: kbdRoot

  property bool active: false
  property bool tabletMode: false
  property bool splitMode: false
  property string layoutLang: "de"     // "de" (QWERTZ) or "en" (QWERTY)
  property string layerMode: "alpha"   // "alpha", "num", "sym"
  property bool shiftActive: false
  property bool capsLocked: false
  property bool ctrlLatched: false
  property bool altLatched: false
  property bool superLatched: false

  // Slide offset: 0 = fully open, panelHeight = fully hidden below bottom edge
  property real slideOffset: panelHeight
  property real dragStartY: 0
  property real dragStartOffset: 0
  property bool dragging: false

  readonly property int panelHeight: 310
  readonly property int swipeZoneHeight: tabletMode ? 24 : 14
  readonly property int keySpacing: 6
  readonly property int rowSpacing: 6
  readonly property int outerPad: 10
  readonly property int splitGap: 0

  signal requestClose()
  signal requestOpen()

  onActiveChanged: {
    slideAnim.stop()
    slideAnim.to = active ? 0 : panelHeight
    slideAnim.start()
    if (!active) {
      repeatTimer.stop()
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
    duration: 240
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
          { label: "⌫", action: "key", key: "BackSpace", weight: 1.5, special: true, repeatable: true }
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
          { label: "⌫", action: "key", key: "BackSpace", weight: 1.5, special: true, repeatable: true }
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
          { label: capsLocked ? "CAPS" : "⇧", action: "shift", weight: 1.4, special: true, highlighted: shiftActive || capsLocked },
          { label: "z" }, { label: "x" }, { label: "c" }, { label: "v" },
          { label: "b" }, { label: "n" }, { label: "m" },
          { label: "⌫", action: "key", key: "BackSpace", weight: 1.5, special: true, repeatable: true }
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
        { label: capsLocked ? "CAPS" : "⇧", action: "shift", weight: 1.35, special: true, highlighted: shiftActive || capsLocked },
        { label: "y" }, { label: "x" }, { label: "c" }, { label: "v" },
        { label: "b" }, { label: "n" }, { label: "m" }, { label: "ß", shiftLabel: "?" },
        { label: "⌫", action: "key", key: "BackSpace", weight: 1.45, special: true, repeatable: true }
      ]
    ]
  }

  function getBottomRow() {
    var isAlpha = (layerMode === "alpha")
    return [
      { label: isAlpha ? "?123" : "ABC", action: "layer", target: isAlpha ? "num" : "alpha", weight: 1.3, special: true },
      { label: layoutLang.toUpperCase(), action: "lang", weight: 0.9, special: true },
      { label: ",", shiftLabel: ";" },
      { label: layoutLang === "de" ? "Leertaste" : "Space", action: "key", key: "space", weight: 4.2, isSpace: true, repeatable: true },
      { label: ".", shiftLabel: ":" },
      { label: "-", shiftLabel: "_" },
      { label: "↵", action: "key", key: "Return", weight: 1.45, accent: true },
      { label: "⌨ ↓", action: "hide", weight: 1.1, special: true }
    ]
  }

  function getUtilityRow() {
    return [
      { label: "Esc", action: "key", key: "Escape", weight: 1.0, special: true },
      { label: "Tab", action: "key", key: "Tab", weight: 1.0, special: true },
      { label: "Ctrl", action: "mod", mod: "ctrl", weight: 1.0, special: true, highlighted: ctrlLatched },
      { label: "Alt", action: "mod", mod: "alt", weight: 1.0, special: true, highlighted: altLatched },
      { label: "Super", action: "mod", mod: "super", weight: 1.1, special: true, highlighted: superLatched },
      { label: "←", action: "key", key: "Left", weight: 0.9, special: true, repeatable: true },
      { label: "↓", action: "key", key: "Down", weight: 0.9, special: true, repeatable: true },
      { label: "↑", action: "key", key: "Up", weight: 0.9, special: true, repeatable: true },
      { label: "→", action: "key", key: "Right", weight: 0.9, special: true, repeatable: true },
      { label: splitMode ? "Full" : "Split", action: "split", weight: 1.1, special: true, highlighted: splitMode },
      { label: "▼ Ausblenden", action: "hide", weight: 1.5, special: true }
    ]
  }

  // Expose the active input mask target for PanelWindow
  property alias activeSurface: kbdSurface
  property alias swipeHandleItem: bottomSwipeBar

  // 1. Bottom-edge swipe-up gesture handle (visible & interactive when keyboard is hidden)
  Item {
    id: bottomSwipeBar
    width: kbdRoot.tabletMode ? Math.round(parent.width * 0.85) : Math.min(480, Math.round(parent.width * 0.45))
    height: kbdRoot.swipeZoneHeight
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    visible: !kbdRoot.active || swipeMouse.pressed

    Rectangle {
      id: swipePill
      width: swipeMouse.containsMouse || swipeMouse.pressed ? 130 : 92
      height: swipeMouse.containsMouse || swipeMouse.pressed ? 5 : 4
      radius: height / 2
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 4
      color: swipeMouse.containsMouse || swipeMouse.pressed ? Color.accent : Util.alpha(Color.foreground, kbdRoot.tabletMode ? 0.6 : 0.36)
      visible: !kbdRoot.active && kbdRoot.slideOffset > kbdRoot.panelHeight - 20

      Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
      id: swipeMouse
      anchors.fill: parent
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
        if (dy < -14) kbdRoot.requestOpen()
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

  // 2. Main Keyboard Surface (slides up from bottom)
  Rectangle {
    id: kbdSurface
    width: parent.width
    height: kbdRoot.panelHeight
    x: 0
    y: parent.height - height + kbdRoot.slideOffset
    visible: kbdRoot.active || kbdRoot.slideOffset < kbdRoot.panelHeight
    color: Util.alpha(Color.background, 0.96)
    radius: Math.max(Style.cornerRadius, 12)

    // Top border highlight
    Rectangle {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 1
      color: Util.alpha(Color.foreground, 0.16)
    }

    // Top drag-handle pill (swipe down to close)
    Item {
      id: topHandleArea
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 22

      Rectangle {
        width: topDragMouse.pressed ? 72 : 52
        height: 4
        radius: 2
        anchors.centerIn: parent
        color: topDragMouse.pressed ? Color.accent : Util.alpha(Color.foreground, 0.38)
        Behavior on width { NumberAnimation { duration: 120 } }
      }

      MouseArea {
        id: topDragMouse
        anchors.fill: parent
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
      anchors.leftMargin: kbdRoot.outerPad
      anchors.rightMargin: kbdRoot.outerPad
      anchors.bottomMargin: kbdRoot.outerPad
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

          // Calculate total weight in this row
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

            delegate: Rectangle {
              id: keyRect
              required property int index
              readonly property var keySpec: rowItem.rowKeys[index]
              readonly property real kWeight: keySpec.weight !== undefined ? keySpec.weight : 1.0

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

              radius: Math.max(6, Style.cornerRadius)
              color: {
                if (keyArea.pressed) return Color.accent
                if (keySpec.accent) return Util.alpha(Color.accent, 0.85)
                if (keySpec.highlighted) return Util.alpha(Color.accent, 0.38)
                if (keySpec.special) return Util.alpha(Color.foreground, 0.13)
                return Util.alpha(Color.foreground, 0.08)
              }
              border.width: 1
              border.color: keyArea.pressed || keySpec.highlighted
                ? Color.accent
                : Util.alpha(Color.foreground, 0.12)

              Behavior on color { ColorAnimation { duration: 80 } }

              Text {
                anchors.centerIn: parent
                text: {
                  var lbl = keySpec.label || ""
                  if (kbdRoot.layerMode === "alpha" && !keySpec.action && (kbdRoot.shiftActive || kbdRoot.capsLocked)) {
                    return keySpec.shiftLabel ? keySpec.shiftLabel : lbl.toUpperCase()
                  }
                  return lbl
                }
                font.family: Style.font.family
                font.pixelSize: rowItem.isUtility ? 13 : (keySpec.special ? 14 : 17)
                font.bold: keySpec.accent || keySpec.highlighted || false
                color: keyArea.pressed || keySpec.accent ? Color.background : Color.foreground
              }

              // Subtle secondary shift symbol in top-right corner
              Text {
                visible: kbdRoot.layerMode === "alpha" && !rowItem.isUtility && keySpec.shiftLabel !== undefined && !kbdRoot.shiftActive && !kbdRoot.capsLocked
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 3
                anchors.rightMargin: 6
                text: keySpec.shiftLabel || ""
                font.family: Style.font.family
                font.pixelSize: 10
                color: Util.alpha(Color.foreground, 0.45)
              }

              MouseArea {
                id: keyArea
                anchors.fill: parent
                preventStealing: true
                onPressed: kbdRoot.startRepeat(keyRect.keySpec)
                onReleased: kbdRoot.stopRepeat()
                onCanceled: kbdRoot.stopRepeat()
              }
            }
          }
        }
      }
    }
  }
}
