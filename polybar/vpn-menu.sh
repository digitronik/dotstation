#!/bin/bash
# vpn-menu.sh — Rofi VPN connect/disconnect picker (click-left on [module/vpn]).
# Connects inside a terminal since most VPNs need an interactive password/OTP
# prompt that `nmcli --ask` can only show on a tty.

set -euo pipefail

TERMINAL="tilix"
PROMPT=" VPN"

active=$(nmcli -t -f TYPE,NAME connection show --active | awk -F: '$1=="vpn"{print $2; exit}')

mapfile -t vpns < <(nmcli -t -f TYPE,NAME connection show | awk -F: '$1=="vpn"{print $2}')

if [[ ${#vpns[@]} -eq 0 ]]; then
    notify-send "VPN" "No VPN connections configured in NetworkManager" 2>/dev/null || true
    exit 0
fi

menu=""
for name in "${vpns[@]}"; do
    if [[ "$name" == "$active" ]]; then
        menu+=" ${name}  (connected — click to disconnect)"$'\n'
    else
        menu+="  ${name}"$'\n'
    fi
done

choice=$(echo -n "$menu" | rofi -dmenu -i -p "$PROMPT" -theme-str 'window {width: 35%;}')
[[ -z "$choice" ]] && exit 0

name=$(sed -E 's/^. //; s/  \(connected.*\)$//' <<< "$choice")

if [[ "$name" == "$active" ]]; then
    nmcli connection down "$name" >/dev/null 2>&1
    notify-send "VPN" "Disconnected from $name" 2>/dev/null || true
else
    [[ -n "$active" ]] && nmcli connection down "$active" >/dev/null 2>&1
    "$TERMINAL" -e bash -c "nmcli connection up '$name' --ask; echo; read -n1 -s -r -p 'Press any key to close...'"
fi
