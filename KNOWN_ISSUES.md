# Known Issues

## Bar flicker / window re-tiling on rotation

During auto-rotation the bar and background (Omarchy quickshell layer surfaces)
briefly disappear and reappear, and tiled windows visibly expand and then
contract again.

### Root cause (confirmed, 2026-08-28)

The flicker is **not** sensor noise and **not** the debounce window. It happens on a
clean, single rotation and is caused by Omarchy's `ScreenMoveRemap` helper
(`$OMARCHY_PATH/shell/Ui/ScreenMoveRemap.qml`), which both the bar
(`Bar.qml`) and background (`Background.qml`) use to stay glued to their
monitor:

```
visible: !remapGuard.remapping
```

`ScreenMoveRemap` watches `screen.onXChanged`/`onYChanged` and pulses
`remapping` true for ~50ms, which unmaps the layer surface. The problem: when a
monitor's **transform** changes (a pure in-place rotation, e.g. 0 → 1 → 0), the
origin stays anchored (this panel never leaves `x=0,y=0`), **but QML still emits
the `onXChanged`/`onYChanged` property-notify signal** — the signal fires on
assignment regardless of whether the value actually differs. So every transform
change pulses `remapping`, unmapping both surfaces:

- the **bar** is an exclusive layer surface (Hyprland `reserved = [0, 20, 0, 0]`),
  so unmapping **releases its 20px reserved area** → tiled windows expand to fill
  it;
- the **background** is `exclusionMode: Ignore` but still unmaps → the desktop
  goes dark;
- on remap the reserved area is reclaimed → windows contract again.

Verified with a controlled quickshell reproduction on this machine:
- stock `ScreenMoveRemap.qml` → 0→1→0 rotation unmaps the surface **3×**;
- patched (origin-aware) version → **0 unmaps**.

### Fix (hyprbend, applied)

- Rotation changes are debounced by `DEBOUNCE_DELAY` (250ms default) and the
  laptop-mode reset is applied immediately — this stops *sensor-thrash*
  (`normal ⇄ left-up` bouncing) from looping the remap, but is **not** the fix
  for the single-rotation flicker above.

### Fix (Omarchy upstream — proposed)

Patch `ScreenMoveRemap.qml` to pulse `remapping` only when the screen's origin
**actually moves**, comparing the current `x`/`y` against the last seen values
instead of reacting to the raw notify signal:

```qml
property real lastX: root.screen ? root.screen.x : 0
property real lastY: root.screen ? root.screen.y : 0

function onOriginNotified() {
  if (!root.screen) return
  var movedX = root.screen.x !== root.lastX
  var movedY = root.screen.y !== root.lastY
  root.lastX = root.screen.x
  root.lastY = root.screen.y
  if (movedX || movedY) settleTimer.restart()
}

Connections {
  target: root.screen
  function onXChanged() { root.onOriginNotified() }
  function onYChanged() { root.onOriginNotified() }
}
```

This preserves the intended behavior (remap when a monitor genuinely moves, e.g.
undock / layout reshuffle) while eliminating the transform-only remap. The full
patched file is in this repo as `ScreenMoveRemap.fixed.qml`, ready to propose as
an upstream PR.

### Workaround (bar only, insufficient)

`no_anim` on the bar namespace reduces the animation but does **not** stop the
unmap/release of the reserved area, so it does not fix the re-tile:

```lua
hl.layer_rule({ match = { namespace = "omarchy-bar" }, no_anim = true, animation = "none" })
```

**Note:** hyprbend already applies the monitor and touch-device transforms in a
single atomic `hyprctl --batch` call to minimize the window in which the display
is inconsistent.

## Window tiles / background slide on rotation

When the panel rotates, the logical resolution swaps (landscape ⇄ portrait), so
Hyprland re-tiles windows and the background layer re-scales. With Omarchy's
default animations this shows as a visible **slide/scale** transition.

### Cause

Hyprland's animations (`windows` move/resize for re-tiling, `layers` resize for
the background) interpolate the geometry instead of snapping.

### Fix (hyprbend, applied)

hyprbend suppresses **all** animations for the brief rotation window and
restores them afterwards:

- Before applying the transform it sets Hyprland's master animation switch
  (`global`) to `enabled=false`, so nothing animates — windows and the
  background jump straight to their new size.
- After a short hold (`ROTATE_ANIM_HOLD_MS`, 200ms default) it re-enables
  `global`, restoring the **exact** prior speed/bezier/style from a live
  snapshot (re-enabling requires the full spec, which is captured before
  suppression).
- Controlled by `SUPPRESS_ANIM_ON_ROTATE` (default `1`; set `0` to keep the
  default animations during rotation).

Disabling only the `windows`/`layers` leaves proved insufficient on Hyprland
0.56.2 (tiles and background still animated), so the fix gates the whole
animation engine via `global`.
