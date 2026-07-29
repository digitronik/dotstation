#!/bin/bash
# ethernet.sh — Polybar wired Ethernet status module.
# Backed by nmcli/sysfs instead of internal/network, which hides the whole
# module when %local_ip% is briefly empty (USB dongle + DHCP delay).

COLOR_ON="#249824"
COLOR_OFF="#777777"
ICON=$'%{T3}\uf6ff%{T-}'

iface=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2=="ethernet"{print $1; exit}')

if [[ -z "$iface" ]]; then
    echo "%{F$COLOR_OFF}$ICON%{F-} Unplugged"
    exit 0
fi

carrier=$(cat "/sys/class/net/$iface/carrier" 2>/dev/null)

if [[ "$carrier" == "1" ]]; then
    ip=$(ip -4 -o addr show "$iface" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1)
    if [[ -n "$ip" ]]; then
        echo "%{F$COLOR_ON}$ICON%{F-} $ip"
    else
        echo "%{F$COLOR_ON}$ICON%{F-} Connecting…"
    fi
else
    echo "%{F$COLOR_OFF}$ICON%{F-} Unplugged"
fi
