#!/bin/bash
# check-vpn.sh — Polybar VPN status module.
# Reads the active profile from NetworkManager instead of assuming a fixed
# interface like tun0, so it works with any VPN backend/profile.

COLOR_ACTIVE="#249824"
COLOR_DOWN="#D95B5B"

active=$(nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | awk -F: '$1=="vpn"{print $2; exit}')

if [[ -n "$active" ]]; then
    echo "%{F$COLOR_ACTIVE}%{T3}%{T-}%{F-} $active"
else
    echo "%{F$COLOR_DOWN}%{T3}%{T-}%{F-} VPN Off"
fi
