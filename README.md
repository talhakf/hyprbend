<div align="center">

  <img src="https://github.com/user-attachments/assets/cc44320c-c2b2-4f89-9039-66f44dbf273c" width="600" alt="Hyprbend">

  <h3>Seamless 2-in-1 Flexibility for Hyprland</h3>

</div>

<div align="left">

Transform your convertible laptop into a true tablet experience. Designed specifically for **Omarchy Quattro**, **Hyprbend** bridges the gap between hardware and software, bringing native, fluid auto-rotation and orientation handling to 2-in-1 devices running Hyprland.

* **Intelligent Auto-Switching:** Detects hinge angles instantly to toggle seamlessly between laptop, tent, and tablet modes.
* **Instantaneous Snap-Rotation:** Rotates both your screen and touch input smoothly while suppressing clunky window scaling animations.
* **Zero-Hassle Diagnostics:** Built-in firmware checks and automated fix utilities get your Intel ISH sensors up and running effortlessly.

> ⚠️ **Disclaimer:** This project is under active development. It has been verified on the **Lenovo IdeaPad Flex 5 16IAU7** and **HP OmniBook X Flip Laptop 14-fm0xxx**, and should work out of the box on similar 2-in-1 convertibles (such as other Lenovo IdeaPad Flex / Yoga and HP x360 / OmniBook models) that use the same Intel ISH hinge sensor or dual IIO 3D accelerometers (display + base). **Note:** This is an unofficial tool and is not affiliated with or endorsed by Omarchy or Hyprland.

</div>

---

## Features

- **Auto-detection**: Hinge sensor, dual 3D accelerometers (screen + base), tablet mode switch, touch device, stylus/pen input devices, and monitor detected automatically
- **Mode switching with hysteresis**: Laptop ↔ Tent ↔ Tablet with configurable angle boundaries, hysteresis zone, and dual-accelerometer fallback for Lenovo IdeaPad Flex / Yoga convertibles
- **Screen, Touch & Stylus rotation**: 0°/90°/180°/270° atomic rotation for display, touch screen, and Wacom/HID stylus pens (`hl.device`)
- **Rotation Lock & Live Status CLI**: `hyprbend lock`, `hyprbend unlock`, `hyprbend status`, plus a quick-toggle `🔒 Lock` button directly in the virtual keyboard
- **Native Omarchy On-Screen Keyboard (OSK)**:
  - **Bottom-edge swipe-up gesture** (GNOME-style, active only in tent/tablet mode) with real-time finger tracking to slide the keyboard up
  - **Window Auto-Push (`Dock` / `Float` mode)**: Reserves a Wayland exclusive zone when docked so tiled windows automatically shift upward and bottom input fields are never covered
  - **Spacebar Cursor Trackpad**: Slide your finger left/right/up/down across the spacebar (`Leertaste  ⟷`) to move the text cursor with precision
  - **Hide button & swipe-down handle** to smoothly collapse the keyboard back down
  - **German (QWERTZ) & English (QWERTY)** layouts, numbers/symbols layers, sticky `Ctrl`/`Alt`/`Super` modifiers, arrow keys, and **Split thumb-typing mode**
  - Focus-preserving Wayland virtual keyboard input via `wtype`
- **Configuration file**: Customize angle boundaries, hysteresis, debounce delay, default keyboard layout, dock mode, and panel height in `~/.config/hyprbend/config.conf`
- **Firmware diagnostics**: Detects Intel ISH (both BIOS-embedded and host-loaded firmware), checks sensor status, offers auto-fix
- **Issue reporting**: Generates copy-paste-ready GitHub issue with full hardware diagnostics (see [Usage](#usage))

## Requirements

- Hyprland 0.55+ (Lua config)
- Omarchy Quattro (`omarchy-shell`)
- `wtype`, `jq`, `gawk`, `python`
- `iio-sensor-proxy` *(optional — built-in direct IIO accelerometer polling is used automatically if not installed)*

## Installation

Installing this package will:

- Install a bash service that auto-detects sensors positions and rotates hyprland accordingly.
- Add an Omarchy plugin for rotating animation and the bottom-edge swipe On-Screen Keyboard.

### Manual build

```bash
git clone https://github.com/talhakf/hyprbend
cd hyprbend
makepkg -si
```

### From AUR

*Coming soon! Package will be available as `hyprbend-git`.*

## Usage

### Status & Rotation Lock

```bash
# Show live hinge angle, current mode, transform, lock state, and detected touch/stylus devices
hyprbend status

# Lock / unlock screen auto-rotation (e.g. when lying down in tablet mode)
hyprbend lock
hyprbend unlock
hyprbend toggle-lock
```

### On-Screen Keyboard

In **tent/tablet mode** (when the physical keyboard is folded away behind the display), swipe up from the pill handle at the bottom center of your screen to pull up the virtual keyboard, or control it via CLI / keybind:

```bash
# Toggle the on-screen keyboard (active in tent/tablet mode)
hyprbend keyboard toggle

# Explicitly open / close / query state
hyprbend keyboard open
hyprbend keyboard close
hyprbend keyboard state
```

### Configuration (`~/.config/hyprbend/config.conf`)

Copy `/usr/share/doc/hyprbend/config.conf.example` (or `config.conf.example` from the repo) to `~/.config/hyprbend/config.conf`:

```ini
LAPTOP_TENT_BOUNDARY=180
TABLET_ANGLE=310
ANGLE_HYSTERESIS=8
DEBOUNCE_DELAY=250
ROTATE_IN_LAPTOP_MODE=0
OSK_DEFAULT_LANG="de"
OSK_DOCK_MODE=1
OSK_HEIGHT=310
```

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

1. **Hinge sensor / Dual Accelerometers**: Reads the lid opening angle via `/sys/bus/iio/devices/iio:device*/in_angl*_raw` (`hinge` channel) or computes it in real time from dual 3D accelerometers (lid + base gravity vectors around the X hinge axis on Lenovo IdeaPad Flex / Yoga laptops)
2. **Mode detection**: Hinge angle `< 180°` = laptop, `180°–309°` = tent, `≥ 310°` = tablet (with configurable hysteresis margin)
3. **Tablet/tent mode**: Enables automatic 4-way screen, touch & stylus rotation and activates the bottom-edge OSK swipe handle
4. **Orientation**: Applies monitor + touch-device + stylus transforms atomically via `hyprctl --batch` while playing the `hyprbend.rotation` Omarchy overlay
5. **Laptop mode**: Resets rotation to normal (`0°`) and completely hides/disables the virtual keyboard and bottom swipe handle

> **Note on keyboard/touchpad deactivation**: Most 2-in-1s deactivate the built-in keyboard and touchpad at the firmware/kernel level via the Intel HID `SW_TABLET_MODE` switch once the lid passes a vendor-defined angle (typically ~190-200°). hyprbend therefore does **not** disable the keyboard itself — doing so in software does not take effect on these devices and would duplicate the hardware behavior. hyprbend only handles screen + touch rotation.

All hardware devices are auto-detected:
- Hinge IIO device: scanned from `/sys/bus/iio/devices/*/name`
- Hinge angle channel: matched by label "hinge" (falls back to "screen", "keyboard", or dual-accelerometer vector angle)
- Touch & Stylus devices: from `hyprctl -j devices` (`touch` and `tablets` sections)
- Monitor: first output from `hyprctl monitors`

## Firmware Troubleshooting
Ideally I'd like this package to support all platforms, please submit an issue with the auto-generated report.
Many 2-in-1 laptops require specific firmware for the Intel ISH (Integrated Sensor Hub) to enumerate sensor devices. Without the correct firmware, no IIO devices appear and hyprbend cannot detect mode switching.

### Supported platforms

- **Intel ISH**: Cherry Trail, Gemini Lake, Ice Lake, Tiger Lake, Alder Lake, Raptor Lake, Meteor Lake, Lunar Lake, Panther Lake
- **Tested devices**: `Lenovo IdeaPad Flex 5 16IAU7` (BIOS-embedded ISH + dual 3D accelerometers) and `HP OmniBook X Flip Laptop 14-fm0xxx` (host-loaded ISH firmware)
- **Compatible hardware**: Other 2-in-1 convertibles (e.g. Lenovo IdeaPad Flex / Yoga series, HP OmniBook / Envy / Spectre x360, Dell Inspiron 2-in-1) that expose either a standard IIO `hinge` angle channel or dual `accel_3d` IIO sensors (lid + base) are expected to work automatically without device-specific configuration.

## Known Issues

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for known issues and workarounds.

## Roadmap

### ~~Auto firmware detection~~ ✓
- Detect hardware (Intel ISH) and automatically install correct sensor firmware.
- Support multiple vendors and firmware variants via DMI CRC32 matching.
- Query device DMI and PCI IDs to match firmware blobs

### ~~Virtual keyboard — Bottom-edge swipe, Dock mode, Spacebar trackpad & Split mode~~ ✓
- Slide-up virtual keyboard triggered by swiping up from the bottom screen edge in tent/tablet mode
- Window Auto-Push (`Dock` mode) and Spacebar Cursor Trackpad (`Leertaste  ⟷`)
- German (QWERTZ) & English (QWERTY) layouts + numbers/symbols layers
- Two-panel split keyboard toggle for thumb typing in tablet mode

### ~~Stylus rotation, Rotation lock, Hysteresis & Config file~~ ✓
- Atomic Wacom/HID stylus pen transform rotation alongside touch and monitor
- Rotation lock CLI (`hyprbend lock/unlock`) and keyboard quick-toggle
- Configurable angle hysteresis and `~/.config/hyprbend/config.conf`

## Project Structure

```
hyprbend/
├── PKGBUILD                         # Arch package build
├── PKGBUILD.aur                     # AUR git package build
├── config.conf.example              # Example user configuration file
├── LICENSE                          # MIT License
├── hyprbend                         # Main service script (subcommand dispatch)
├── hyprbend-check                   # Diagnostics — read-only status report
├── hyprbend-fix                     # Auto-fix — attempts repairs, offers report on failure
├── hyprbend-report                  # Report — generates GitHub issue markdown
├── hyprbend-detect.sh               # Shared hardware detection library
├── hyprbend.service                 # Systemd user service
├── hyprbend.install                 # pacman install hooks
├── omarchy-plugin/
│   ├── manifest.json                # Omarchy shell plugin manifest
│   ├── Hyprbend.qml                 # Rotation overlay + OSK layer window & IPC
│   └── VirtualKeyboard.qml          # Touch keyboard with swipe-up, dock & trackpad
├── KNOWN_ISSUES.md                  # Known issues and workarounds
└── README.md
```

## License

MIT — see [LICENSE](LICENSE) (original work by [kosmo-sys](https://github.com/kosmo-sys/hyprbend)).
