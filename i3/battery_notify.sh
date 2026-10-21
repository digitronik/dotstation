#!/bin/bash
# =============================================================================
# battery_notify.sh — Desktop notifications for low and full battery states.
#
# Runs as a background daemon launched by i3 on login. Uses a PID file to
# ensure only one instance runs at a time, and a state file to suppress
# duplicate notifications when the battery level stays within a threshold.
# =============================================================================

PIDFILE="/tmp/battery_notify.pid"

if [ -f "$PIDFILE" ] && kill -0 "$(cat $PIDFILE)" 2>/dev/null; then
    exit 0
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

# --- Configuration ---
# Auto-detect first battery device (BAT0, BAT1, etc.) instead of hardcoding.
BATTERY_PATH=""
for bat in /sys/class/power_supply/BAT*; do
    if [ -e "$bat/status" ] && [ -e "$bat/capacity" ]; then
        BATTERY_PATH="$bat"
        break
    fi
done

if [ -z "$BATTERY_PATH" ]; then
    # No battery found — desktop or unsupported hardware. Exit silently.
    rm -f "$PIDFILE"
    exit 0
fi

STATUS_PATH="$BATTERY_PATH/status"
CAPACITY_PATH="$BATTERY_PATH/capacity"
STATE_FILE="/tmp/battery_notification.state"
LOW_LEVEL=20
FULL_LEVEL=98

while true; do
    STATUS=$(cat "$STATUS_PATH")
    CAPACITY=$(cat "$CAPACITY_PATH")

    if [ "$STATUS" = "Discharging" ] && [ "$CAPACITY" -le "$LOW_LEVEL" ]; then
        if [ ! -f "$STATE_FILE" ] || [ "$(cat $STATE_FILE)" != "low" ]; then
            notify-send -u critical -i "battery-low" \
                "Battery Low!" "Plug in your charger. Remaining: ${CAPACITY}%"
            echo "low" > "$STATE_FILE"
        fi

    elif [ "$STATUS" = "Charging" ] && [ "$CAPACITY" -ge "$FULL_LEVEL" ]; then
        if [ ! -f "$STATE_FILE" ] || [ "$(cat $STATE_FILE)" != "full" ]; then
            notify-send -u normal -i "battery-full-charged" \
                "Battery Full" "You can unplug your charger now. Level: ${CAPACITY}%"
            echo "full" > "$STATE_FILE"
        fi

    elif [ "$STATUS" = "Charging" ] || [ "$STATUS" = "Full" ]; then
        [ -f "$STATE_FILE" ] && [ "$(cat $STATE_FILE)" = "low" ]  && rm -f "$STATE_FILE"

    elif [ "$STATUS" = "Discharging" ]; then
        [ -f "$STATE_FILE" ] && [ "$(cat $STATE_FILE)" = "full" ] && rm -f "$STATE_FILE"
    fi

    sleep 60
done
