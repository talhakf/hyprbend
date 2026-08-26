# hyprbend

Automatic screen rotation, keyboard toggle, and virtual keyboard for 2-in-1 laptops running Hyprland.

Detects laptop/tablet/tent mode via the hinge sensor and automatically:
- Rotates the screen based on accelerometer orientation
- Rotates touch input to match
- Disables/enables the physical keyboard

## Features

- **Auto-detection**: Hinge sensor, keyboard, touch device, and monitor detected automatically
- **Mode switching**: Laptop ↔ Tablet/Tent with configurable angle thresholds
- **Screen rotation**: 0°/90°/180°/270° based on accelerometer
- **Touch rotation**: Touch input rotates with the screen
- **Keyboard toggle**: Physical keyboard disabled in tablet/tent mode
- **Systemd service**: Starts on login, restarts on failure
- **Clean lifecycle**: Auto-start on install, auto-stop on removal

## Requirements

- Hyprland 0.55+ (Lua config)
- iio-sensor-proxy
- monitor-sensor (from iio-sensor-proxy)
- bash

## Installation

### From AUR (recommended)

```bash
yay -S hyprbend
```

### Manual build

```bash
git clone https://github.com/kosmosys/hyprbend
cd hyprbend
makepkg -si
```

## Usage

The service starts automatically on install. Manage it with:

```bash
# Check status
systemctl --user status hyprbend

# Restart
systemctl --user restart hyprbend

# Stop
systemctl --user stop hyprbend

# View logs
journalctl --user -u hyprbend -f
```

## How It Works

1. **Hinge sensor** (IIO device) provides keyboard angle via `/sys/bus/iio/devices/iio:device*/in_angl*_raw`
2. **Mode detection**: Angle > 150° = tablet/tent, Angle < 30° = laptop
3. **Tablet/tent mode**: Disables keyboard, starts `monitor-sensor --accel` for orientation
4. **Orientation**: Parses `monitor-sensor` output and calls `hyprctl eval` to rotate monitor + touch device
5. **Laptop mode**: Enables keyboard, stops orientation monitor, resets rotation

## Configuration

Thresholds are defined at the top of the script:

```bash
TABLET_THRESHOLD=150  # degrees - above this = tablet/tent mode
LAPTOP_THRESHOLD=30   # degrees - below this = laptop mode
DEBOUNCE_DELAY=1      # seconds - prevents rapid mode switching
```

All hardware devices are auto-detected:
- Hinge IIO device: scanned from `/sys/bus/iio/devices/*/name`
- Keyboard angle channel: matched by label "keyboard" in hinge device
- Internal keyboard: filtered from `hyprctl devices` (excludes video-bus, intel-hid, etc.)
- Touch device: from `hyprctl devices` Touch section
- Monitor: first output from `hyprctl monitors`

## Known Issues

- **Bar flicker on rotation**: Omarchy's bar (quickshell layer surface) briefly disappears during monitor transform changes. This is an upstream Hyprland issue — layer surfaces aren't properly reflowed on transform. See [Hyprland PR #14771](https://github.com/hyprwm/Hyprland/pull/14771) and [omarchy-mac ScreenMoveRemap](https://github.com/omarchy-mac/omarchy-mac/commit/2daeaa7).
- **wvkbd `--auto` not working yet**: The virtual keyboard's auto-show on text input requires proper `zwp_input_method_v2` integration with Hyprland, which needs further investigation.

## Roadmap

### Auto firmware detection
- Detect hardware (Intel ISH, etc.) and automatically install correct sensor firmware
- Support multiple vendors and firmware variants
- Query device DMI and PCI IDs to match firmware blobs

### Virtual keyboard — Hovering mode
- Floating keyboard that follows touch position
- Auto-shows when text field is focused (via `wvkbd --auto` or similar)
- Auto-hides after inactivity timeout
- Draggable, resizable

### Virtual keyboard — Static mode
- Fixed-position keyboard at bottom of screen
- Always visible in tablet/tent mode
- Configurable size and position
- Toggle visibility with gesture or keybind

### Virtual keyboard — Split mode
- Two-panel split keyboard for thumb typing
- Left and right panels at screen edges
- Optimized for holding the device in tablet mode
- Customizable split ratio and key layouts

### Additional
- Stylus/pen support with pressure sensitivity
- Per-app rotation lock (e.g., never rotate in video players)
- Hysteresis zone between laptop and tablet thresholds
- Configuration file for thresholds, device overrides, and keyboard preferences

## Project Structure

```
hyprbend/
├── PKGBUILD              # Arch package build
├── hyprbend.install      # pacman install hooks
├── README.md
└── src/
    ├── hyprbend          # Main service script
    └── hyprbend.service  # Systemd user service
```

## License

MIT
