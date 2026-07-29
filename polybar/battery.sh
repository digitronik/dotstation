#!/bin/bash
# battery.sh — Polybar battery module backed by UPower.
# internal/battery misreads charge-threshold "paused" as Discharging with a
# bogus time estimate; UPower gets both the state and the time right.
#
# Usage:
#   battery.sh          Status line for Polybar
#   battery.sh --info   Health/cycles notification (click-left)

set -uo pipefail

COLOR_GREEN="#249824"
COLOR_ORANGE="#FFAF60"
COLOR_RED="#D95B5B"
COLOR_BLUE="#60FFF7"
COLOR_DISABLED="#777777"

BAT_DEVICE=$(upower -e 2>/dev/null | grep -m1 'battery_')
if [[ -z "$BAT_DEVICE" ]]; then
    exit 0
fi

INFO=$(upower -i "$BAT_DEVICE" 2>/dev/null)

field() {
    echo "$INFO" | awk -F': *' -v k="$1" '$1 ~ "^[[:space:]]*"k"$" {print $2; exit}'
}

state=$(field "state")
percentage=$(field "percentage" | tr -d '%')
time_to_empty=$(field "time to empty")
time_to_full=$(field "time to full")
percentage=${percentage:-0}

icon_for_level() {
    local p=$1
    if   (( p >= 90 )); then printf '\uf240'   # battery-full
    elif (( p >= 65 )); then printf '\uf241'   # battery-three-quarters
    elif (( p >= 35 )); then printf '\uf242'   # battery-half
    elif (( p >= 10 )); then printf '\uf243'   # battery-quarter
    else                    printf '\uf244'    # battery-empty
    fi
}

if [[ "${1:-}" == "--info" ]]; then
    energy_full=$(field "energy-full")
    energy_design=$(field "energy-full-design")
    health=$(field "capacity")
    cycles=$(field "charge-cycles")
    rate=$(field "energy-rate")
    start_th=$(field "charge-start-threshold")
    end_th=$(field "charge-end-threshold")

    body="Health: ${health:-unknown} (${cycles:-?} cycles)"
    body+=$'\n'"Capacity: ${energy_full:-?} / ${energy_design:-?} (design)"
    [[ -n "$rate" ]] && body+=$'\n'"Rate: ${rate} (${state})"
    if [[ -n "$start_th" && -n "$end_th" ]]; then
        body+=$'\n'"Charge limit: ${start_th} - ${end_th}"
    fi

    notify-send -i battery "Battery — ${percentage}%" "$body" 2>/dev/null || true
    exit 0
fi

case "$state" in
    charging)
        icon=$'\uf0e7'
        color="$COLOR_GREEN"
        label="${percentage}%"
        [[ -n "$time_to_full" ]] && label+=" (${time_to_full})"
        ;;
    discharging)
        icon=$(icon_for_level "$percentage")
        if   (( percentage <= 20 )); then color="$COLOR_RED"
        elif (( percentage <= 50 )); then color="$COLOR_ORANGE"
        else                              color="$COLOR_GREEN"
        fi
        label="${percentage}%"
        [[ -n "$time_to_empty" ]] && label+=" (${time_to_empty})"
        ;;
    fully-charged)
        icon=$'\uf240'
        color="$COLOR_GREEN"
        label="Full"
        ;;
    pending-charge)
        # Plugged in, charging intentionally paused (charge-threshold battery care).
        icon=$'\uf1e6'
        color="$COLOR_BLUE"
        label="${percentage}% (limited)"
        ;;
    pending-discharge)
        icon=$'\uf1e6'
        color="$COLOR_BLUE"
        label="${percentage}%"
        ;;
    *)
        icon=$(icon_for_level "$percentage")
        color="$COLOR_DISABLED"
        label="${percentage}%"
        ;;
esac

echo "%{F${color}}%{T3}${icon}%{T-}%{F-} ${label}"
