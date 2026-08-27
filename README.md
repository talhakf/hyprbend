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
- **Firmware diagnostics**: Detects Intel ISH / AMD SFH hardware, checks firmware status, offers auto-fix
- **Issue reporting**: `hyprbend report` generates copy-paste-ready GitHub issue with full hardware diagnostics

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

### Firmware diagnostics

```bash
# Diagnose sensor and firmware issues
hyprbend check

# Attempt automatic fixes (prompts for report on failure)
hyprbend fix

# Generate GitHub issue report (copy-paste into issues)
hyprbend report > issue.md
```

`hyprbend-check`, `hyprbend-fix`, `hyprbend-report` also work as standalone commands.

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
DEBOUNCE_DELAY=250    # milliseconds - prevents rapid mode switching
```

All hardware devices are auto-detected:
- Hinge IIO device: scanned from `/sys/bus/iio/devices/*/name`
- Keyboard angle channel: matched by label "keyboard" in hinge device
- Internal keyboard: filtered from `hyprctl devices` (excludes video-bus, intel-hid, etc.)
- Touch device: from `hyprctl devices` Touch section
- Monitor: first output from `hyprctl monitors`

## Firmware Troubleshooting

Many 2-in-1 laptops require specific firmware for the Intel ISH (Integrated Sensor Hub) to enumerate sensor devices. Without the correct firmware, no IIO devices appear and hyprbend cannot detect mode switching.

### Common symptoms

- `ls /sys/bus/iio/devices/` shows no devices
- `iio-sensor-proxy` fails to start
- `hyprbend` exits with "No hinge sensor found"

### Quick fix

```bash
hyprbend fix
```

This will:
1. Detect your platform and compute expected firmware filenames (using DMI CRC32 matching)
2. Check if the firmware exists in `/lib/firmware/intel/ish/`
3. Attempt `linux-firmware` installation and `fwupd` updates if needed
4. Print manual instructions for vendor-specific firmware
5. If auto-fix fails, offer to generate a GitHub issue report with all hardware details

### Manual steps

1. Ensure `linux-firmware` is installed: `sudo pacman -S linux-firmware`
2. Reboot and check `dmesg | grep -i ISH` for firmware load status
3. If firmware errors persist, your vendor may provide custom ISH firmware — check their Linux support page or extract from Windows driver packages
4. Place firmware `.bin` files in `/lib/firmware/intel/ish/` and reboot

### Supported platforms

- **Intel ISH**: Cherry Trail, Gemini Lake, Ice Lake, Tiger Lake, Alder Lake, Raptor Lake, Meteor Lake, Lunar Lake, Panther Lake
- **AMD SFH**: Kernel-native, no userspace firmware needed

- **Bar flicker on rotation**: Omarchy's bar (quickshell layer surface) briefly disappears during monitor transform changes. This is an upstream Hyprland issue — layer surfaces aren't properly reflowed on transform. See [Hyprland PR #14771](https://github.com/hyprwm/Hyprland/pull/14771) and [omarchy-mac ScreenMoveRemap](https://github.com/omarchy-mac/omarchy-mac/commit/2daeaa7).
- **wvkbd `--auto` not working yet**: The virtual keyboard's auto-show on text input requires proper `zwp_input_method_v2` integration with Hyprland, which needs further investigation.

## Roadmap

### ~~Auto firmware detection~~ ✓
- Detect hardware (Intel ISH, AMD SFH) and automatically install correct sensor firmware
- Support multiple vendors and firmware variants via DMI CRC32 matching
- Query device DMI and PCI IDs to match firmware blobs
- `hyprbend report` generates GitHub issue with full hardware diagnostics for platform support requests

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
├── PKGBUILD                 # Arch package build
├── hyprbend                 # Main service script (subcommand dispatch)
├── hyprbend-check           # Diagnostics — read-only status report
├── hyprbend-fix             # Auto-fix — attempts repairs, offers report on failure
├── hyprbend-report          # Report — generates GitHub issue markdown
├── hyprbend-detect.sh       # Shared hardware detection library
├── hyprbend.service         # Systemd user service
├── hyprbend.install         # pacman install hooks
└── README.md
```

## License

MIT
