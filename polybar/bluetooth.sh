#!/bin/bash
# bluetooth.sh — Polybar Bluetooth status module (icon only, no on/off text).
# AutoEnable=false is set in install.sh, so power stays off until toggled here.
#
# Usage: bluetooth.sh [--toggle]

COLOR_CONNECTED="#249824"
COLOR_IDLE="#60FFF7"
COLOR_OFF="#777777"
ICON=$'%{T4}\uf294%{T-}'

if [[ "${1:-}" == "--toggle" ]]; then
    if bluetoothctl show | grep -q "Powered: yes"; then
        bluetoothctl power off > /dev/null
    else
        bluetoothctl power on > /dev/null
    fi
    exit 0
fi

if bluetoothctl show | grep -q "Powered: yes"; then
    connected=$(bluetoothctl devices Connected)

    if echo "$connected" | grep -q "/org/bluez/hci0"; then
        # Startup race condition: controller path returned instead of device
        echo "%{F$COLOR_IDLE}$ICON%{F-}"
    elif [[ -n "$connected" ]]; then
        device_name=$(echo "$connected" | head -n1 | cut -d ' ' -f 3-)
        echo "%{F$COLOR_CONNECTED}$ICON%{F-} $device_name"
    else
        echo "%{F$COLOR_IDLE}$ICON%{F-}"
    fi
else
    echo "%{F$COLOR_OFF}$ICON%{F-}"
fi
