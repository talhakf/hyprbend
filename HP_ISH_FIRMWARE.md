# HP ISH Firmware Investigation

Summary of research into extracting Intel ISH firmware from HP softpaq driver packages for use on Linux.

## Background

Intel ISH (Integrated Sensor Hub) is a low-power co-processor that handles sensor processing (accelerometer, gyroscope, etc.) on Intel laptops. Many 2-in-1 laptops depend on ISH for hinge angle detection and screen rotation. Without working ISH firmware, no IIO sensor devices appear and tools like `iio-sensor-proxy` and `hyprbend` cannot function.

## Two ISH Architectures

Intel has shipped two fundamentally different ISH firmware loading architectures:

### Pre-Lunar Lake (Raptor Lake, Alder Lake, Meteor Lake, and earlier)

- The **entire ISH firmware is embedded in the BIOS/UEFI SPI flash**
- At power-on, the ISH boots autonomously from BIOS-loaded firmware
- By the time the Linux kernel loads, the ISH is already running
- The kernel's `intel_ish_ipc` driver connects to the already-running ISH over ISHTP
- **No host-side firmware loading occurs** — the kernel does nothing to "activate" the ISH
- If BIOS has correct firmware, sensors work out of the box
- If not, the only fix is a BIOS update

### Lunar Lake and newer

- Intel split the firmware into two components:
  1. **Bootloader** (small, in BIOS) — initializes ISH hardware
  2. **Main firmware** (large `.bin` blob) — loaded by the kernel from `/lib/firmware/intel/ish/`
- At power-on, ISH boots into the BIOS bootloader (shim)
- Kernel's ISHTP driver sends `HOST_START_REQ_CMD`
- Bootloader responds with `ISHTP_SUPPORT_CAP_LOADER` bit set — "I need firmware from you"
- Kernel calls `request_firmware()`, reads DMI info, tries filenames in order
- Sends firmware to ISH via `LOADER_CMD_XFER_QUERY` → `LOADER_CMD_XFER_FRAGMENT` → `LOADER_CMD_START`
- ISH reboots into main firmware → sensors appear

## Platform Matrix

| Platform | PCI ID | `fw_generation` | Host FW Loading? | Firmware Source |
|----------|--------|-----------------|-----------------|-----------------|
| Cherry Trail | varies | `NULL` | No | BIOS |
| Gemini Lake | varies | `NULL` | No | BIOS |
| Ice Lake | varies | `NULL` | No | BIOS |
| Tiger Lake | varies | `NULL` | No | BIOS |
| Alder Lake | varies | `NULL` | No | BIOS |
| Raptor Lake | `0x7A78` | `NULL` | No | BIOS |
| Meteor Lake | `0x7E45` | `NULL` | No | BIOS |
| Arrow Lake | `0x7745`/`0x7F78` | `NULL` | No | BIOS |
| **Lunar Lake** | `0xA845` | `"lnlm"` | **Yes** | Host filesystem |
| **Panther Lake** | `0xE345`/`0xE445` | `"ptl"` | **Yes** | Host filesystem |
| **Nova Lake** | `0xD354`/`0x6E78` | `"nvlh"`/`"nvls"` | **Yes** | Host filesystem |

## HP Softpaq Findings

### What are HP softpaqs?

HP distributes driver packages as self-extracting `.exe` files (softpaqs) containing Windows drivers and firmware. The ISH-related softpaqs are named "Intel Sensor Hub Components Driver" and contain ISH firmware binaries under `IshHeciExtensionTemplate/FwImage/`.

### Extracted structure

```
sp.exe (self-extracting 7z archive)
└── extracted/
    ├── src/
    │   ├── Driver/ (or driver/)
    │   │   ├── IshHeci/           # Generic Intel firmware (NOT what you want)
    │   │   │   └── FWImage/
    │   │   │       ├── 0003/
    │   │   │       │   └── ishS_SI_5.8.0.XXXX.bin
    │   │   │       └── 0004/
    │   │   │           └── ishS_SI_5.8.1.XXXX.bin
    │   │   └── IshHeciExtensionTemplate/  # HP-signed firmware (what you want)
    │   │       └── (x64/)
    │   │           └── FwImage/ (or FWImage/)
    │   │               └── 000N/
    │   │                   └── <one .bin file>
    │   └── ...
    └── ...
```

### Extraction command

```bash
7z x -y sp<XXXXX>.exe -oextracted
```

### Finding the correct firmware binary

The correct firmware is **always in `IshHeciExtensionTemplate`**, not `IshHeci`. There is exactly **one `.bin` file** in the template directory across all platforms.

```bash
find extracted/ -path "*/IshHeciExtensionTemplate/*" -name "*.bin"
```

### Platform-specific paths

| Platform | Softpaq | Relative path to `.bin` |
|----------|---------|------------------------|
| LNLM | sp172806.exe | `src/Driver/IshHeciExtensionTemplate/FWImage/0003/ishS_SI_5.8.0.7718.bin` |
| PTL | sp172141.exe | `src/driver/Win10/IshHeciExtensionTemplate/x64/FwImage/0004/*.bin` |
| ARL | sp172141.exe | `src/driver/Win10/IshHeciExtensionTemplate/x64/FwImage/0004/*.bin` |
| MTL | sp172141.exe | `src/driver/Win10/IshHeciExtensionTemplate/x64/FwImage/0004/*.bin` |
| NVL | sp173468.exe | `src/driver/Win10/IshHeciExtensionTemplate/x64/FwImage/0007/*.bin` |
| RPL | sp173162.exe | **No firmware** — driver-only package |

### Directory structure variations

- **Case**: `Driver` vs `driver` (varies between softpaqs)
- **Architecture subfolder**: LNLM has no `x64/`; PTL/ARL/MTL/NVL have `Win10/x64/`
- **FWImage case**: `FWImage` (LNLM) vs `FwImage` (PTL/ARL/MTL/NVL)
- **Subdirectory number**: `0003` (LNLM), `0004` (PTL/ARL/MTL), `0007` (NVL) — **these are Windows INF packaging artifacts, irrelevant for Linux**

### Firmware filenames in softpaqs

| Platform | Softpaq | Filename | Notes |
|----------|---------|----------|-------|
| LNLM | **sp172806** | `ishS_SI_5.8.0.7718.bin` | **CORRECT** — ~645 KB, contains hinge + accel + gyro |
| LNLM | sp173552 | `ishS_SI_Chiharu26C2_v7728_260109_v1.bin` | **WRONG for this device** — ~531 KB, only proximity/hall, no hinge/accel |
| PTL | sp172141 | `HPSigned_ishC_5.8.310.7783_0304.bin` | HP custom-signed |
| ARL | sp172141 | `HPSigned_ishC_5.8.310.7783_0304.bin` | Same as PTL |
| MTL | sp172141 | `HPSigned_ishC_5.8.310.7783_0304.bin` | Same as PTL |
| NVL | sp173468 | `HPSigned_ishC_5.8.300.7784_0310.bin` | HP custom-signed |

### ⚠️ LNLM: sp172806 vs sp173552 (regression pitfall)

For HP OmniBook X Flip 14-fm0xxx, use **SP172806**, NOT sp173552.

- **sp172806** → `IshHeciExtensionTemplate/FWImage/0003/ishS_SI_5.8.0.7718.bin` (645632 bytes). Its sensor table explicitly lists `hinge`, `MOTION_ACCELEROMETER_3D` (LIS2DW12/LSM6DSOX), `platform_lid_mode`. This is the one that makes the hinge + accelerometer work.
- **sp173552** → `IshHeciExtensionTemplate/FWImage/0003/ishS_SI_Chiharu26C2_v7728_260109_v1.bin` (530944 bytes). Its sensor table only lists `ec_interface` and `lid_closed_detection` (hall effect) — **no hinge, no accelerometer**. It loads fine but only exposes a proximity sensor, so `iio-sensor-proxy` exits with "No sensors".

Both are in `IshHeciExtensionTemplate` and both load, but only the 7718 one delivers the target sensors. The `find ... -iname "*.bin"` glob would pick a Chiharu if present, and the softpaq URL in the firmware table determines which one gets installed. **Keep the LNLM table entry pointed at sp172806 with glob `ishS*.bin`** so it never regresses to the Chiharu/sp173552 variant.

## Why MTL/ARL Softpaqs Contain `.bin` Files (But Linux Can't Use Them)

The `.bin` files in MTL/ARL softpaqs exist **for the Windows ISH driver only**. The Windows ISH driver (`IshHeciExtension`) uses a proprietary firmware loading mechanism via HECI that can inject firmware from host even on older ISH architectures. The Linux driver cannot do this.

Proof from kernel source (`drivers/hid/intel-ish-hid/ipc/pci-ish.c`):
- MTL and ARL PCI device IDs use `PCI_VDEVICE()` which defaults `driver_data` to 0 (`ISHTP_DRIVER_DATA_NONE`)
- No `ISH_FW_GEN_MTL` or `ISH_FW_GEN_ARL` exists
- The ISH hardware on MTL/ARL does not set `ISHTP_SUPPORT_CAP_LOADER` in its response
- No `ish_mtl.bin` or `ish_arl.bin` exists in linux-firmware
- Even if you placed the files in `/lib/firmware/intel/ish/`, the kernel would never request them

## Linux Firmware Installation

### Kernel filename expectations

The kernel tries firmware files in this order (stopping at first match):

1. `intel/ish/ish_${gen}_${VENDOR_CRC32}_${PRODUCT_FAMILY_CRC32}_${PRODUCT_NAME_CRC32}_${PRODUCT_SKU_CRC32}.bin`
2. ... progressively less specific CRC32 matches ...
3. `intel/ish/ish_${gen}.bin` (Intel generic fallback, last)

Where `${gen}` is `lnlm`, `ptl`, or `nvlh`/`nvls`.

### How to install extracted HP firmware

After extracting the `.bin` from the softpaq:

```bash
# For Lunar Lake
sudo cp <extracted>.bin /lib/firmware/intel/ish/ish_lnlm.bin

# For Panther Lake
sudo cp <extracted>.bin /lib/firmware/intel/ish/ish_ptl.bin

# For Nova Lake
sudo cp <extracted>.bin /lib/firmware/intel/ish/ish_nvlh.bin  # or ish_nvls.bin
```

### CRC32 vendor matching (optional)

The kernel can also match vendor-specific firmware using CRC32 hashes of DMI strings. For HP:

| Platform | Typical vendor firmware filename |
|----------|----------------------------------|
| LNLM | `ish_lnlm_<HP_CRC32>_<product_CRC32>.bin` |
| PTL | `ish_ptl_<HP_CRC32>_<product_CRC32>.bin` |

The CRC32 uses: poly=`0x04C11DB7`, init=`0xFFFFFFFF`, RefIn=true, RefOut=true, XorOut=`0xFFFFFFFF`.

DMI fields used: `DMI_SYS_VENDOR`, `DMI_PRODUCT_FAMILY`, `DMI_PRODUCT_NAME`, `DMI_PRODUCT_SKU`.

For HP, `SYS_VENDOR` CRC32 is `12128606` (from linux-firmware repo).

### Vendor firmware in linux-firmware repo

```
intel/ish/ish_lnlm.bin              # Intel generic (fallback)
intel/ish/ish_ptl.bin                # Intel generic (not yet upstreamed)
HP/ish/ish_lnlm_12128606_f9751b71.bin   # HP Lunar Lake
HP/ish/ish_ptl_12128606_581.7779.0.bin  # HP Panther Lake
```

## Recommendations for hyprbend

### Scope

The HP softpaq extraction method is only needed for **Lunar Lake, Panther Lake, and Nova Lake**. All older platforms (RPL, ARL, MTL, and earlier) have ISH firmware in BIOS — fix via BIOS update.

### For `hyprbend-fix`

1. Detect platform generation from PCI device ID
2. If pre-LNL: advise BIOS update, do not attempt firmware extraction
3. If LNLM/PTL/NVL: attempt `linux-firmware` installation first, then `fwupd`, then offer manual HP softpaq extraction with step-by-step instructions
4. The extracted `.bin` should be installed as `ish_${gen}.bin` in `/lib/firmware/intel/ish/`

### Softpaq URLs (HP FTP)

| Platform | Softpaq ID | URL |
|----------|-----------|-----|
| LNLM | sp172806 | `https://ftp.hp.com/pub/softpaq/sp172501-173000/sp172806.exe` |
| PTL | sp172141 | `https://ftp.hp.com/pub/softpaq/sp172001-172500/sp172141.exe` |
| ARL | sp172141 | Same as PTL (universal softpaq) |
| MTL | sp172141 | Same as PTL (universal softpaq) |
| NVL | sp173468 | `https://ftp.hp.com/pub/softpaq/sp173001-173500/sp173468.exe` |
| RPL | sp173162 | `https://ftp.hp.com/pub/softpaq/sp173001-173500/sp173162.exe` (no firmware) |
