# Known Issues

## Bar flicker on rotation

On Hyprland versions below the transform-reflow fix, Omarchy's bar (a quickshell
layer surface) briefly disappears while the monitor transform changes.

**Cause:** Hyprland does not reflow layer surfaces at the same time as window
surfaces during a monitor transform change, so layer surfaces briefly render at
the old transform/size.

**Affected:** Hyprland < 0.55.1 (the fix landed upstream in
[Hyprland PR #14771](https://github.com/hyprwm/Hyprland/pull/14771)).

**Workaround:** Upgrade Hyprland to a version that includes the fix.

**Note:** hyprbend already applies the monitor and touch-device transforms in a
single atomic `hyprctl --batch` call to minimize the window in which the display
is inconsistent.
