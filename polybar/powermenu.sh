#!/bin/bash
# =============================================================================
# powermenu.sh — Rofi power menu (click-left on [module/powermenu]).
# Delegates all actions to lock.sh for a single, consistent code path.
# =============================================================================

set -euo pipefail

FA_LOCK=$'\uf023'
FA_SIGNOUT=$'\uf2f5'
FA_MOON=$'\uf186'
FA_REBOOT=$'\uf021'
FA_POWEROFF=$'\uf011'

PROMPT="${FA_POWEROFF} Power"

menu="${FA_LOCK}  Lock Screen
${FA_SIGNOUT}  Log Out
${FA_MOON}  Suspend
${FA_MOON}  Hibernate
${FA_REBOOT}  Reboot
${FA_POWEROFF}  Shut Down"

choice=$(echo -n "$menu" | rofi -dmenu -i -p "$PROMPT" -theme-str 'window {width: 22%;}')
[[ -z "$choice" ]] && exit 0

case "$choice" in
    *"Lock"*)      sh ~/.config/i3/lock.sh lock      ;;
    *"Log Out"*)   sh ~/.config/i3/lock.sh logout     ;;
    *"Suspend"*)   sh ~/.config/i3/lock.sh suspend    ;;
    *"Hibernate"*) sh ~/.config/i3/lock.sh hibernate  ;;
    *"Reboot"*)    sh ~/.config/i3/lock.sh reboot     ;;
    *"Shut Down"*) sh ~/.config/i3/lock.sh shutdown   ;;
esac
