#!/bin/bash
# =============================================================================
# lock.sh — Central handler for session and power operations.
#
# Called by both i3 keybindings and the Polybar power menu to ensure a
# single, consistent code path for all lock/power actions.
#
# Usage: lock.sh {lock|logout|suspend|hibernate|reboot|shutdown}
# =============================================================================

case "$1" in
    lock)
        i3lock -c 111111
        ;;
    logout)
        i3-msg exit
        ;;
    suspend)
        i3lock -c 111111 && systemctl suspend
        ;;
    hibernate)
        i3lock -c 111111 && systemctl hibernate
        ;;
    reboot)
        systemctl reboot
        ;;
    shutdown)
        systemctl poweroff
        ;;
    *)
        echo "Usage: $(basename "$0") {lock|logout|suspend|hibernate|reboot|shutdown}" >&2
        exit 2
        ;;
esac
