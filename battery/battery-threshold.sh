#!/bin/bash
# battery-threshold.sh — Sets the battery charge-threshold (thinkpad_acpi or similar
# vendor ACPI extension). ThinkPad-specific hardware feature — auto-detects the first
# battery that actually exposes charge_control thresholds, so it degrades gracefully
# (clear error, no crash) on desktops or laptops without this support, and works with
# BAT0/BAT1/etc. rather than assuming a fixed device name.
# Installed to /usr/local/bin by install.sh; run via sudo (menu) or udev (boot).
#
# Usage: battery-threshold.sh {daily|full|status} [--raw]
#   daily   Cap charging at 75-80%  — everyday use, docked/plugged in most of the day.
#   full    Remove the cap (0-100%) — travel/trip, need maximum runtime.
#   status  Print the current thresholds and live capacity ("--raw": space-separated).

set -euo pipefail

DAILY_START=75
DAILY_END=80
FULL_START=0
FULL_END=100

# First BAT* with charge_control thresholds — empty if none (no support on this hardware).
find_battery() {
    local bat
    for bat in /sys/class/power_supply/BAT*; do
        if [[ -e "$bat/charge_control_start_threshold" ]]; then
            echo "$bat"
            return 0
        fi
    done
    return 1
}

BAT_PATH="$(find_battery || true)"

require_supported() {
    if [[ -z "$BAT_PATH" ]]; then
        echo "error: no battery with charge_control thresholds found on this system" >&2
        echo "       (ThinkPad-only feature — desktops and non-ThinkPad laptops are unaffected)." >&2
        exit 1
    fi
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "error: must run as root (sudo)." >&2
        exit 1
    fi
}

# Writes start/end in whichever order keeps start<=end valid at every step,
# so the kernel never rejects an intermediate (start > end) combination.
set_thresholds() {
    local start="$1" end="$2" current_end
    current_end=$(cat "$BAT_PATH/charge_control_end_threshold")
    if (( start <= current_end )); then
        echo "$start" > "$BAT_PATH/charge_control_start_threshold"
        echo "$end"   > "$BAT_PATH/charge_control_end_threshold"
    else
        echo "$end"   > "$BAT_PATH/charge_control_end_threshold"
        echo "$start" > "$BAT_PATH/charge_control_start_threshold"
    fi
    # Nudge upowerd to refresh immediately instead of showing stale thresholds.
    echo change > "$BAT_PATH/uevent" 2>/dev/null || true
}

status() {
    if [[ -z "$BAT_PATH" ]]; then
        [[ "${1:-}" == "--raw" ]] && echo "" || echo "Charge limit: unsupported on this hardware"
        return 0
    fi
    local start end capacity
    start=$(cat "$BAT_PATH/charge_control_start_threshold" 2>/dev/null || echo "?")
    end=$(cat "$BAT_PATH/charge_control_end_threshold" 2>/dev/null || echo "?")
    capacity=$(cat "$BAT_PATH/capacity" 2>/dev/null || echo "?")
    if [[ "${1:-}" == "--raw" ]]; then
        echo "${start} ${end} ${capacity}"
    else
        echo "Charge limit: ${start}% - ${end}%  (current: ${capacity}%)"
    fi
}

case "${1:-}" in
    daily)
        require_root
        require_supported
        set_thresholds "$DAILY_START" "$DAILY_END"
        echo "Daily mode: cap ${DAILY_START}-${DAILY_END}%"
        ;;
    full)
        require_root
        require_supported
        set_thresholds "$FULL_START" "$FULL_END"
        echo "Full-charge mode: cap ${FULL_START}-${FULL_END}%"
        ;;
    status)
        status "${2:-}"
        ;;
    *)
        echo "Usage: $(basename "$0") {daily|full|status}" >&2
        exit 2
        ;;
esac
