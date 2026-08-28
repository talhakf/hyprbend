<div align="center">

  <img src="https://github.com/user-attachments/assets/cc44320c-c2b2-4f89-9039-66f44dbf273c" width="600" alt="Hyprbend">

  <h3>Seamless 2-in-1 Flexibility for Hyprland</h3>

</div>

<div align="left">

Transform your convertible laptop into a true tablet experience. Designed specifically for **Omarchy Quattro**, **Hyprbend** bridges the gap between hardware and software, bringing native, fluid auto-rotation and orientation handling to 2-in-1 devices running Hyprland.

* **Intelligent Auto-Switching:** Detects hinge angles instantly to toggle seamlessly between laptop, tent, and tablet modes.
* **Instantaneous Snap-Rotation:** Rotates both your screen and touch input smoothly while suppressing clunky window scaling animations.
* **Zero-Hassle Diagnostics:** Built-in firmware checks and automated fix utilities get your Intel ISH sensors up and running effortlessly.

> ⚠️ **Disclaimer:** This project is under active development and your specific hardware platform might not be supported yet (currently only tested on the HP OmniBook X Flip Laptop 14-fm0xxx). **Note:** This is an unofficial tool and is not affiliated with or endorsed by Omarchy or Hyprland.

</div>

---

## Features

- **Auto-detection**: Hinge sensor, touch device, and monitor detected automatically
- **Mode switching**: Laptop ↔ Tent ↔ Tablet with configurable angle boundary
- **Screen rotation**: 0°/90°/180°/270° based on accelerometer/gyroscope
- **Touch rotation**: Touch input rotates with the screen
- **Firmware diagnostics**: Detects Intel ISH, checks firmware status, offers auto-fix (install)
- **Issue reporting**: Generates copy-paste-ready GitHub issue with full hardware diagnostics to ask for support for your platform hardware (see [Usage](#usage)). 

## Requirements

- Hyprland 0.55+ (Lua config)
- iio-sensor-proxy
- monitor-sensor (from iio-sensor-proxy)
- Omarchy Quattro

## Installation

Installing this package will:

- Install a bash service that auto-detects sensors positions and rotates hyprland accordingly.
- Add an Omarchy plugin for rotating animation. (If you don't care for this, disable it)

### Manual build

```bash
git clone https://github.com/kosmosys/hyprbend
cd hyprbend
makepkg -si
```

### From AUR

*Coming soon! Package will be available as `hyprbend-git`.*

## Usage

### Firmware diagnostics and installation

```bash
# Diagnose sensor and firmware issues
hyprbend check

# Auto-installs firmware for your platform if detected and implemented. (Will need system reboot)
hyprbend fix

# Generate GitHub issue report (copy-paste into issues) to ask for your platform to be supported
hyprbend report > issue.md
```

### Monitoring Logs

```bash
# Watch live mode-detection and rotation logs
hyprbend
```

## How It Works

1. **Hinge sensor** (IIO device) provides the lid angle via `/sys/bus/iio/devices/iio:device*/in_angl*_raw` (the `hinge` channel)
2. **Mode detection**: Hinge angle ≥ 180° = tablet/tent, else laptop
3. **Tablet/tent mode**: Reads `monitor-sensor --accel` orientation (running for the service's lifetime)
4. **Orientation**: Parses `monitor-sensor` output and calls `hyprctl eval` to rotate monitor + touch device. While the transform is applied, Hyprland's animations (`global`) are suppressed for a short window so windows and the background **snap** to the new aspect instead of sliding/scaling; the exact animation specs are restored right after (`SUPPRESS_ANIM_ON_ROTATE`, see Configuration)
5. **Laptop mode**: Resets rotation

> **Note on keyboard/touchpad deactivation**: Most 2-in-1s deactivate the built-in keyboard and touchpad at the firmware/kernel level via the Intel HID `SW_TABLET_MODE` switch once the lid passes a vendor-defined angle (typically ~190-200°). hyprbend therefore does **not** disable the keyboard itself — doing so in software does not take effect on these devices and would duplicate the hardware behavior. hyprbend only handles screen + touch rotation.

All hardware devices are auto-detected:
- Hinge IIO device: scanned from `/sys/bus/iio/devices/*/name`
- Hinge angle channel: matched by label "hinge" (falls back to "screen", then "keyboard") in the hinge device
- Touch device: from `hyprctl devices` Touch section
- Monitor: first output from `hyprctl monitors`

## Firmware Troubleshooting
Ideally I'd like this package to support all platforms, please submit an issue with the auto-generated report.
Many 2-in-1 laptops require specific firmware for the Intel ISH (Integrated Sensor Hub) to enumerate sensor devices. Without the correct firmware, no IIO devices appear and hyprbend cannot detect mode switching.

### Supported platforms

- **Intel ISH**: Cherry Trail, Gemini Lake, Ice Lake, Tiger Lake, Alder Lake, Raptor Lake, Meteor Lake, Lunar Lake, Panther Lake

## Known Issues

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for known issues and workarounds.

## Roadmap

### ~~Auto firmware detection~~ ✓
- Detect hardware (Intel ISH) and automatically install correct sensor firmware. (Only tested with `HP OmniBook X Flip Laptop 14-fm0xxx` ATM)
- Support multiple vendors and firmware variants via DMI CRC32 matching.
- Query device DMI and PCI IDs to match firmware blobs

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
