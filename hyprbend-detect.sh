#!/bin/bash
# hyprbend-detect.sh — Shared hardware detection library
# Sourced by hyprbend and hyprbend-check
#
# Provides: platform detection, DMI reading, CRC32 computation,
#           ISH firmware enumeration, IIO device checks

# --- DMI ---

read_dmi() {
    local field=$1
    cat "/sys/class/dmi/id/${field}" 2>/dev/null || echo ""
}

# --- CRC32 ---

compute_crc32() {
    local data="$1"
    local -a crc_table
    local i r j crc byte

    for ((i = 0; i < 256; i++)); do
        r=$((i))
        for ((j = 0; j < 8; j++)); do
            if ((r & 1)); then
                r=$(((r >> 1) ^ 0xEDB88320))
            else
                r=$((r >> 1))
            fi
        done
        crc_table[$i]=$r
    done

    crc=0xFFFFFFFF
    for ((i = 0; i < ${#data}; i++)); do
        printf -v byte '%d' "'${data:$i:1}"
        crc=$(((crc >> 8) ^ crc_table[(crc ^ byte) & 0xFF]))
    done
    echo $((crc ^ 0xFFFFFFFF))
}

# CRC32 as lowercase hex (no 0x prefix, no zero padding)
crc32_hex() {
    local decimal
    decimal=$(compute_crc32 "$1")
    printf '%x' "$decimal"
}

# --- Firmware resolution ---

# Format: "vendor|gen|device_ids|url|fw_glob"
# vendor:     DMI sys_vendor match (lowercase, substring)
# gen:        ISH generation from detect_ish_gen()
# device_ids: space-separated PCI device IDs (hex, no 0x prefix)
# url:        download URL for the driver package (.exe)
# fw_glob:    glob for firmware inside IshHeciExtensionTemplate/FWImage/0003/
FIRMWARE_TABLE=(
    "hp|lnlm|a825 a828 a845|https://ftp.hp.com/pub/softpaq/sp172501-173000/sp172806.exe|ishS*.bin"
    # Samsung Galaxy Book5 — source: https://dnsense.pub/posts/9-book5-sensor-hub/
    # "samsung|lnlm|a825 a828 a845|<url>|ishS*.bin"
    # ASUS Zenbook S14 — source: https://github.com/dantmnf/zenbook-s14-ux5406sa-linux
    # "asus|lnlm|a825 a828|<url>|ishS*.bin"
    # Lenovo Yoga 9i — source: https://github.com/johnmeade/linux-yoga-9i-2-in-1-aura
    # "lenovo|lnlm|a825 a828|<url>|ishS*.bin"
)

# Resolves firmware package info for a detected platform.
# Args: vendor gen device_id
# Sets: FIRMWARE_URL, FIRMWARE_FW_PATTERN, FIRMWARE_TARGET
# Returns: 0 if found, 1 if no resolver
resolve_firmware() {
    local vendor="${1,,}"
    local gen="$2"
    local device_id="${3,,}"

    local entry vendor_match gen_match device_match fw_url fw_glob
    for entry in "${FIRMWARE_TABLE[@]}"; do
        IFS='|' read -r vendor_match gen_match device_match fw_url fw_glob <<< "$entry"

        # Match vendor (substring, case-insensitive)
        [[ "$vendor" == *"${vendor_match,,}"* ]] || continue
        # Match generation
        [[ "$gen" == "$gen_match" ]] || continue
        # Match device ID
        local found_id=false id
        for id in $device_match; do
            [[ "$device_id" == "$id" ]] && { found_id=true; break; }
        done
        $found_id || continue

        FIRMWARE_URL="$fw_url"
        FIRMWARE_FW_PATTERN="$fw_glob"
        FIRMWARE_TARGET="ish_${gen}_$(crc32_hex "$(read_dmi sys_vendor)").bin"
        return 0
    done
    return 1
}

# --- Platform detection ---

# Returns: "intel_ish", "amd_sfh", or "none"
detect_platform() {
    local lspci_out
    lspci_out=$(lspci -Dnn 2>/dev/null || echo "")

    # Check for Intel ISH — match by description (works across all PCI classes)
    if echo "$lspci_out" | grep -qi 'Integrated Sensor Hub'; then
        echo "intel_ish"
        return 0
    fi

    # Fallback: check sysfs for ISH (vendor 8086 + class 0700 or 0880)
    local ish_sysfs
    ish_sysfs=$(find /sys/bus/pci/devices/ -name vendor -exec sh -c '
        Vendor=$(cat "$1")
        DevClass=$(cat "$(dirname "$1")/class" 2>/dev/null)
        [[ "$Vendor" == "0x8086" && ("$DevClass" == "0x070000" || "$DevClass" == "0x088000") ]]
        && echo "$(dirname "$1")"
    ' _ {} \; 2>/dev/null | head -1 || echo "")
    if [[ -n "$ish_sysfs" ]]; then
        echo "intel_ish"
        return 0
    fi

    # Check for AMD SFH
    if lsmod 2>/dev/null | grep -q amd_sfh; then
        echo "amd_sfh"
        return 0
    fi
    if [[ -d /sys/module/amd_sfh ]]; then
        echo "amd_sfh"
        return 0
    fi

    echo "none"
    return 1
}

# --- Intel ISH platform generation ---

# Maps PCI device ID to ISH generation string (max 8 chars per kernel docs)
# Returns generation string like "lnlm", "ptl", etc.
detect_ish_gen() {
    local pci_addr
    pci_addr=$(lspci -Dnn 2>/dev/null | grep -i 'Integrated Sensor Hub' | head -1 | awk '{print $1}' || echo "")
    if [[ -z "$pci_addr" ]]; then
        # Fallback: scan sysfs
        pci_addr=$(find /sys/bus/pci/devices/ -name vendor -exec sh -c '
            Vendor=$(cat "$1")
            DevClass=$(cat "$(dirname "$1")/class" 2>/dev/null)
            [[ "$Vendor" == "0x8086" && ("$DevClass" == "0x070000" || "$DevClass" == "0x088000") ]]
            && basename "$(dirname "$1")"
        ' _ {} \; 2>/dev/null | head -1 || echo "")
    fi
    if [[ -z "$pci_addr" ]]; then
        echo ""
        return 1
    fi

    local device_id
    device_id=$(cat "/sys/bus/pci/devices/${pci_addr}/device" 2>/dev/null || echo "")
    device_id=${device_id#0x}  # strip 0x prefix if present

    case "$device_id" in
        # Cherry Trail / Apollo Lake
        "22dc") echo "ct" ;;
        # Gemini Lake
        "34a8") echo "glk" ;;
        # Ice Lake
        "34a5"|"34a4") echo "icl" ;;
        # Tiger Lake
        "a0a3"|"a0a1") echo "tgl" ;;
        # Alder Lake
        "54e3"|"54e1") echo "adl" ;;
        # Raptor Lake
        "7ae0"|"7ade") echo "rpl" ;;
        # Meteor Lake
        "7e01"|"7e03") echo "mtl" ;;
        # Lunar Lake
        "a825"|"a828"|"a845") echo "lnlm" ;;
        # Panther Lake
        "e825"|"e828") echo "ptl" ;;
        # Arrow Lake
        "b825"|"b828") echo "arl" ;;
        # Unknown — return raw device ID as fallback
        *) echo "$device_id" ;;
    esac
}

# --- Intel ISH firmware naming ---

# Generates all 9 firmware filenames the kernel tries, plus the generic fallback
# Populates: ISH_FIRMWARE_NAMES (array), ISH_FIRMWARE_GENERIC
compute_ish_firmware_names() {
    local gen
    gen=$(detect_ish_gen)
    if [[ -z "$gen" ]]; then
        ISH_FIRMWARE_NAMES=()
        ISH_FIRMWARE_GENERIC=""
        return 1
    fi

    local vendor_crc family_crc name_crc sku_crc
    vendor_crc=$(crc32_hex "$(read_dmi sys_vendor)")
    family_crc=$(crc32_hex "$(read_dmi product_family)")
    name_crc=$(crc32_hex "$(read_dmi product_name)")
    sku_crc=$(crc32_hex "$(read_dmi product_sku)")

    ISH_FIRMWARE_NAMES=(
        "ish_${gen}_${vendor_crc}_${family_crc}_${name_crc}_${sku_crc}.bin"
        "ish_${gen}_${vendor_crc}_${family_crc}_${sku_crc}.bin"
        "ish_${gen}_${vendor_crc}_${family_crc}_${name_crc}.bin"
        "ish_${gen}_${vendor_crc}_${family_crc}.bin"
        "ish_${gen}_${vendor_crc}_${name_crc}_${sku_crc}.bin"
        "ish_${gen}_${vendor_crc}_${sku_crc}.bin"
        "ish_${gen}_${vendor_crc}_${name_crc}.bin"
        "ish_${gen}_${vendor_crc}.bin"
        "ish_${gen}.bin"
    )
    ISH_FIRMWARE_GENERIC="ish_${gen}.bin"
    return 0
}

# Checks which expected firmware files exist in /lib/firmware/intel/ish/
# Populates: ISH_FIRMWARE_STATUS (array): "found" | "found_zst" | "missing"
#            ISH_FIRMWARE_PATHS (array): actual path if found, empty if missing
check_ish_firmware() {
    local fw_dir="/lib/firmware/intel/ish"
    compute_ish_firmware_names || return 1

    ISH_FIRMWARE_STATUS=()
    ISH_FIRMWARE_PATHS=()
    for fw in "${ISH_FIRMWARE_NAMES[@]}"; do
        if [[ -f "${fw_dir}/${fw}" ]]; then
            ISH_FIRMWARE_STATUS+=("found")
            ISH_FIRMWARE_PATHS+=("${fw_dir}/${fw}")
        elif [[ -f "${fw_dir}/${fw}.zst" ]]; then
            ISH_FIRMWARE_STATUS+=("found_zst")
            ISH_FIRMWARE_PATHS+=("${fw_dir}/${fw}.zst")
        else
            ISH_FIRMWARE_STATUS+=("missing")
            ISH_FIRMWARE_PATHS+=("")
        fi
    done
}

# --- IIO device enumeration ---

# Prints IIO device names and paths, one per line: "name path"
enumerate_iio_devices() {
    for dev in /sys/bus/iio/devices/iio:device*; do
        [[ -d "$dev" ]] || continue
        local name=""
        name=$(cat "$dev/name" 2>/dev/null || echo "unknown")
        echo "${name} ${dev}"
    done
}

# Returns 0 if hinge or accelerometer IIO device is present
check_sensors_present() {
    for dev in /sys/bus/iio/devices/iio:device*; do
        [[ -d "$dev" ]] || continue
        local name=""
        name=$(cat "$dev/name" 2>/dev/null || echo "")
        case "$name" in
            hinge|accel*|accel|bma250e|bmc150| bmi*)
                return 0
                ;;
        esac
        # Also check for any device with accel channels
        if ls "$dev"/in_accel_*_raw &>/dev/null; then
            return 0
        fi
    done
    return 1
}

# --- dmesg error checks ---

# Returns 0 if ISH firmware load errors found in dmesg
check_dmesg_ish_errors() {
    dmesg 2>/dev/null | grep -qi 'intel_ish.*\(failed\|error\|cmd.*failed\)' && return 0
    return 1
}

# Prints relevant dmesg lines about ISH firmware
get_dmesg_ish_lines() {
    dmesg 2>/dev/null | grep -i 'intel_ish\|ISH loader' || echo ""
}

# --- iio-sensor-proxy check ---

# Returns 0 if iio-sensor-proxy service is active
check_iio_sensor_proxy() {
    systemctl is-active iio-sensor-proxy.service &>/dev/null && return 0
    return 1
}

# Returns 0 if monitor-sensor binary exists
check_monitor_sensor() {
    command -v monitor-sensor &>/dev/null && return 0
    return 1
}

# --- GitHub issue report ---

# Outputs a markdown issue body to stdout with all hardware diagnostics
report_github_issue() {
    local sys_vendor product_family product_name product_sku
    sys_vendor=$(read_dmi sys_vendor)
    product_family=$(read_dmi product_family)
    product_name=$(read_dmi product_name)
    product_sku=$(read_dmi product_sku)

    local platform gen pci_addr device_id pci_class
    platform=$(detect_platform) || true
    gen=$(detect_ish_gen) || true

    local pci_info=""
    pci_addr=$(lspci -Dnn 2>/dev/null | grep -i 'Integrated Sensor Hub' | head -1 || echo "")
    if [[ -n "$pci_addr" ]]; then
        pci_info=$(echo "$pci_addr" | awk '{$1=""; print $0}' | sed 's/^ //')
    fi

    # System Information
    echo "## Hardware Report — hyprbend platform support request"
    echo ""
    echo "### System Information"
    echo "- **Vendor**: ${sys_vendor:-unknown}"
    echo "- **Product Family**: ${product_family:-unknown}"
    echo "- **Product Name**: ${product_name:-unknown}"
    [[ -n "$product_sku" ]] && echo "- **SKU**: ${product_sku}"

    # Platform Detection
    echo ""
    echo "### Platform Detection"
    case "$platform" in
        intel_ish)
            echo "- **Detected**: intel_ish"
            echo "- **ISH Generation**: ${gen:-unknown}"
            [[ -n "$pci_info" ]] && echo "- **PCI Device**: ${pci_info}"
            ;;
        amd_sfh)
            echo "- **Detected**: amd_sfh"
            local mod_loaded=false
            lsmod 2>/dev/null | grep -q amd_sfh && mod_loaded=true
            echo "- **Module loaded**: ${mod_loaded}"
            ;;
        none)
            echo "- **Detected**: none"
            echo "- **Note**: No Intel ISH or AMD SFH detected"
            ;;
    esac

    # ISH Firmware Status
    if [[ "$platform" == "intel_ish" ]]; then
        echo ""
        echo "### ISH Firmware Status"
        echo "| Pattern | Status | Path |"
        echo "|---------|--------|------|"
        if check_ish_firmware; then
            for i in "${!ISH_FIRMWARE_NAMES[@]}"; do
                local fw="${ISH_FIRMWARE_NAMES[$i]}"
                local status="${ISH_FIRMWARE_STATUS[$i]}"
                local path="${ISH_FIRMWARE_PATHS[$i]}"
                local pattern_num=$((i + 1))
                case "$status" in
                    found)     echo "| ${fw} | found | ${path} |" ;;
                    found_zst) echo "| ${fw}.zst | found (compressed) | ${path} |" ;;
                    missing)   echo "| ${fw} | missing | - |" ;;
                esac
            done
        else
            echo "| (cannot compute firmware names) | - | - |"
        fi
    fi

    # IIO Devices
    echo ""
    echo "### IIO Devices"
    local iio_count=0
    while IFS=' ' read -r name path; do
        [[ -n "$name" ]] || continue
        echo "- ${name}: ${path}"
        iio_count=$((iio_count + 1))
    done < <(enumerate_iio_devices)
    if [[ "$iio_count" -eq 0 ]]; then
        echo "- (none found)"
    fi

    # Services
    echo ""
    echo "### Services"
    if check_iio_sensor_proxy; then
        echo "- iio-sensor-proxy: active"
    else
        echo "- iio-sensor-proxy: inactive"
    fi
    if check_monitor_sensor; then
        echo "- monitor-sensor: available"
    else
        echo "- monitor-sensor: missing"
    fi

    # Kernel Messages
    echo ""
    echo "### Kernel Messages (ISH-related)"
    local dmesg_lines
    dmesg_lines=$(get_dmesg_ish_lines)
    if [[ -n "$dmesg_lines" ]]; then
        echo '```'
        echo "$dmesg_lines" | tail -10
        echo '```'
    else
        echo "- (none)"
    fi

    # Dependencies
    echo ""
    echo "### Dependencies"
    local deps=("hyprctl" "monitor-sensor")
    for dep in "${deps[@]}"; do
        if command -v "$dep" &>/dev/null; then
            echo "- ${dep}: available"
        else
            echo "- ${dep}: missing"
        fi
    done
    if pacman -Qi linux-firmware &>/dev/null 2>&1; then
        echo "- linux-firmware: installed"
    else
        echo "- linux-firmware: not installed"
    fi
    if command -v fwupdmgr &>/dev/null; then
        echo "- fwupd: available"
    else
        echo "- fwupd: missing"
    fi

    # Timestamp
    echo ""
    echo "---"
    echo "*Generated: $(date '+%Y-%m-%d %H:%M:%S') by hyprbend*"
}
