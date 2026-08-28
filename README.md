# hyprbend

Automatic screen rotation and virtual keyboard for 2-in-1 laptops running Hyprland.

Detects laptop/tablet/tent mode via the hinge sensor and automatically:
- Rotates the screen based on accelerometer orientation
- Rotates touch input to match

## Features

- **Auto-detection**: Hinge sensor, touch device, and monitor detected automatically
- **Mode switching**: Laptop ↔ Tablet/Tent with configurable angle boundary
- **Screen rotation**: 0°/90°/180°/270° based on accelerometer
- **Touch rotation**: Touch input rotates with the screen
- **Systemd service**: Starts on login, restarts on failure
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

1. **Hinge sensor** (IIO device) provides the lid angle via `/sys/bus/iio/devices/iio:device*/in_angl*_raw` (the `hinge` channel)
2. **Mode detection**: Hinge angle ≥ 180° = tablet/tent, else laptop
3. **Tablet/tent mode**: Reads `monitor-sensor --accel` orientation (running for the service's lifetime)
4. **Orientation**: Parses `monitor-sensor` output and calls `hyprctl eval` to rotate monitor + touch device
5. **Laptop mode**: Resets rotation

> **Note on keyboard/touchpad deactivation**: Most 2-in-1s deactivate the built-in keyboard and touchpad at the firmware/kernel level via the Intel HID `SW_TABLET_MODE` switch once the lid passes a vendor-defined angle (typically ~190-200°). hyprbend therefore does **not** disable the keyboard itself — doing so in software does not take effect on these devices and would duplicate the hardware behavior. hyprbend only handles screen + touch rotation.

## Configuration

Mode detection is defined by a single boundary, with reference anchors:

```bash
CLOSED_ANGLE=0          # lid fully closed (reference)
TABLET_ANGLE=360        # lid folded fully back (reference)
LAPTOP_TENT_BOUNDARY=180  # degrees - divides laptop from tent/tablet
DEBOUNCE_DELAY=250      # milliseconds - prevents rapid mode switching
```

The hinge channel reports the lid opening angle in degrees:
- **< 180°** = laptop / normal use (lid at most flat open)
- **≥ 180°** = tent or tablet (lid folded back past flat)

All hardware devices are auto-detected:
- Hinge IIO device: scanned from `/sys/bus/iio/devices/*/name`
- Hinge angle channel: matched by label "hinge" (falls back to "screen", then "keyboard") in the hinge device
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

## Known Issues

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for known issues and workarounds.

## Roadmap

### ~~Auto firmware detection~~ ✓
- Detect hardware (Intel ISH, AMD SFH) and automatically install correct sensor firmware
- Support multiple vendors and firmware variants via DMI CRC32 matching
- Query device DMI and PCI IDs to match firmware blobs
- `hyprbend report` generates GitHub issue with full hardware diagnostics for platform support requests

### Virtual keyboard — Hovering mode
- Floating keyboard that follows touch position
- Auto-shows when a text field is focused
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
- Configuration file for thresholds and device overrides

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
├── KNOWN_ISSUES.md          # Known issues and workarounds
└── README.md
```

## License

MIT
