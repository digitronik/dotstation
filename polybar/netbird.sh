#!/bin/bash
# netbird.sh — Polybar NetBird (WireGuard mesh VPN) status module.
# Parses `netbird status --json` since the plain-text label format has changed
# across client versions, while the JSON schema (managementState/peers) hasn't.

COLOR_ACTIVE="#249824"
COLOR_WARN="#FFAF60"
COLOR_OFF="#777777"
ICON=$'%{T3}\uf3ed%{T-}'

json=$(timeout 4 netbird status --json 2>/dev/null)

if [[ -z "$json" ]] || ! jq -e . >/dev/null 2>&1 <<< "$json"; then
    echo "%{F$COLOR_OFF}$ICON%{F-} Daemon Off"
    exit 0
fi

mgmt=$(jq -r '.management.connected // false' <<< "$json")
ip=$(jq -r '.netbirdIp // empty' <<< "$json" | cut -d/ -f1)
total=$(jq -r '.peers.total // 0' <<< "$json")
connected=$(jq -r '.peers.connected // 0' <<< "$json")

if [[ "$mgmt" == "true" ]]; then
    echo "%{F$COLOR_ACTIVE}$ICON%{F-} ${ip:-Connected} (${connected:-0}/${total:-0})"
else
    echo "%{F$COLOR_WARN}$ICON%{F-} Logged Out"
fi
