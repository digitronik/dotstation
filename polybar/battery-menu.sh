#!/bin/bash
# battery-menu.sh — Rofi picker to switch charge-threshold mode (click-left on [module/battery]).
# Delegates hardware detection to battery-threshold.sh (installed by install.sh only on
# hardware that supports it) instead of touching sysfs directly, so this menu degrades
# gracefully wherever that script isn't present.

set -euo pipefail

PROMPT=" Battery"
THRESH_BIN="/usr/local/bin/battery-threshold.sh"
CHECK=$'\uf00c'

if [[ ! -x "$THRESH_BIN" ]]; then
    notify-send -i battery "Battery" "Charge-threshold control unavailable on this machine (run install.sh)." 2>/dev/null || true
    exec "$(dirname "$0")/battery.sh" --info
fi

read -r _ end _ <<< "$("$THRESH_BIN" status --raw 2>/dev/null || echo "")"

current="daily"
[[ "$end" == "100" ]] && current="full"

daily_marker="  "
full_marker="  "
[[ "$current" == "daily" ]] && daily_marker="${CHECK} "
[[ "$current" == "full"  ]] && full_marker="${CHECK} "

menu="${daily_marker}Daily (cap 75-80%)"$'\n'
menu+="${full_marker}Full charge (100%)"$'\n'
menu+="ⓘ Battery info"

choice=$(echo -n "$menu" | rofi -dmenu -i -p "$PROMPT" -theme-str 'window {width: 28%;}')
[[ -z "$choice" ]] && exit 0

switch_to() {
    local mode="$1" label="$2"
    if sudo -n "$THRESH_BIN" "$mode" &>/dev/null; then
        notify-send -i battery "Battery" "$label" 2>/dev/null || true
    else
        notify-send -i battery "Battery" "Couldn't switch — sudoers rule missing? Re-run install.sh." 2>/dev/null || true
    fi
}

case "$choice" in
    *"Daily"*) switch_to daily "Daily mode — cap 75-80%" ;;
    *"Full"*)  switch_to full  "Full-charge mode — charges to 100%" ;;
    *"info"*)  "$(dirname "$0")/battery.sh" --info ;;
esac
