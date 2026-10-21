#!/bin/bash
# wifi-menu.sh — Rofi Wi-Fi picker (click-left on [module/wifi]).

set -euo pipefail

PROMPT=" Wi-Fi"

if ! nmcli radio wifi | grep -q enabled; then
    nmcli radio wifi on
    sleep 1
fi

current_ssid=$(nmcli -t -f active,ssid dev wifi list --rescan no | awk -F: '$1=="yes"{print $2; exit}')

# Cached results (--rescan no) load instantly; --rescan yes takes 5-8s.
# "Rescan" below triggers a fresh scan on demand.
mapfile -t networks < <(
    nmcli -t -f ssid,signal,security dev wifi list --rescan no 2>/dev/null \
        | sort -t: -k2,2 -nr \
        | awk -F: '$1 != "" && !seen[$1]++'
)

menu=""
for line in "${networks[@]}"; do
    ssid="${line%%:*}"
    rest="${line#*:}"
    signal="${rest%%:*}"
    security="${rest#*:}"

    marker="  "
    [[ "$ssid" == "$current_ssid" ]] && marker=" "

    lock=""
    [[ -n "$security" && "$security" != "--" ]] && lock=" "

    menu+="${marker}${ssid}${lock} (${signal}%)"$'\n'
done

menu+="⟳ Rescan"$'\n'
menu+="✕ Turn Wi-Fi off"

choice=$(echo -n "$menu" | rofi -dmenu -i -p "$PROMPT" -theme-str 'window {width: 30%;}')
[[ -z "$choice" ]] && exit 0

case "$choice" in
    "⟳ Rescan")
        nmcli device wifi rescan >/dev/null 2>&1
        sleep 2
        exec "$0"
        ;;
    "✕ Turn Wi-Fi off")
        nmcli radio wifi off
        exit 0
        ;;
esac

# Strip 2-char marker prefix (icon+space or space+space), trailing signal
# strength, and optional Font Awesome lock icon (\uf023).
FA_LOCK=$'\uf023'
ssid=$(sed -E "s/^..//; s/ \([0-9]+%\)$//; s/ ${FA_LOCK}$//" <<< "$choice")

if nmcli -t -f NAME connection show | grep -qxF "$ssid"; then
    nmcli connection up "$ssid" >/dev/null 2>&1 \
        && notify-send "Wi-Fi" "Connected to $ssid" 2>/dev/null || true
else
    password=$(rofi -dmenu -p "Password for $ssid" -password)
    if [[ -n "$password" ]]; then
        nmcli device wifi connect "$ssid" password "$password" >/dev/null 2>&1 \
            && notify-send "Wi-Fi" "Connected to $ssid" 2>/dev/null \
            || notify-send "Wi-Fi" "Failed to connect to $ssid" 2>/dev/null || true
    else
        nmcli device wifi connect "$ssid" >/dev/null 2>&1 || true
    fi
fi
