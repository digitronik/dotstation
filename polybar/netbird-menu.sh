#!/bin/bash
# netbird-menu.sh — Rofi NetBird connect/disconnect + peers picker (click-left
# on [module/netbird]).
# `netbird up`/`down` need root (the daemon socket is root-owned), so they run
# inside a terminal with sudo — same pattern as vpn-menu.sh's nmcli --ask.

set -euo pipefail

TERMINAL="tilix"
PROMPT=" NetBird"

json=$(timeout 4 netbird status --json 2>/dev/null || true)

if [[ -z "$json" ]] || ! jq -e . >/dev/null 2>&1 <<< "$json"; then
    notify-send "NetBird" "Daemon not reachable — is the netbird service running?" 2>/dev/null || true
    exit 0
fi

mgmt=$(jq -r '.management.connected // false' <<< "$json")

if [[ "$mgmt" == "true" ]]; then
    menu=" Disconnect"$'\n'
else
    menu=" Connect / Log in"$'\n'
fi
menu+=" Show peers"$'\n'
menu+=" Full status"$'\n'
menu+=" Open NetBird UI"

choice=$(echo -n "$menu" | rofi -dmenu -i -p "$PROMPT" -theme-str 'window {width: 30%;}')
[[ -z "$choice" ]] && exit 0

case "$choice" in
    *Disconnect)
        "$TERMINAL" -e bash -c "sudo netbird down; echo; read -n1 -s -r -p 'Press any key to close...'"
        ;;
    *"Connect / Log in")
        "$TERMINAL" -e bash -c "sudo netbird up; echo; read -n1 -s -r -p 'Press any key to close...'"
        ;;
    *"Show peers")
        peers=$(jq -r '.peers.details[]? | "\(.fqdn)  \(.netbirdIp)  \(.status)  \(.connectionType // "-")"' <<< "$json")
        [[ -z "$peers" ]] && peers="No peers"
        echo -n "$peers" | rofi -dmenu -i -p " Peers" -theme-str 'window {width: 45%;}'
        ;;
    *"Full status")
        "$TERMINAL" -e bash -c "netbird status --detail; echo; read -n1 -s -r -p 'Press any key to close...'"
        ;;
    *"Open NetBird UI")
        netbird-ui &
        ;;
esac
