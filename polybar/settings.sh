#!/bin/bash
# =============================================================================
# settings.sh — Rofi settings menu (click-left on [module/settings]).
# =============================================================================

set -euo pipefail

FA_VOLUME=$'\uf028'
FA_DISPLAY=$'\uf108'
FA_GLOBE=$'\uf0ac'
FA_WIFI=$'\uf1eb'
FA_GEAR=$'\uf085'

PROMPT="${FA_GEAR} Settings"

menu="${FA_VOLUME}  Audio
${FA_DISPLAY}  Display
${FA_GLOBE}  Network Connections
${FA_WIFI}  Wi-Fi
${FA_GEAR}  Polybar Config
${FA_GEAR}  i3 Config"

choice=$(echo -n "$menu" | rofi -dmenu -i -p "$PROMPT" -theme-str 'window {width: 25%;}')
[[ -z "$choice" ]] && exit 0

case "$choice" in
    *"Audio"*)        pavucontrol ;;
    *"Display"*)      arandr ;;
    *"Network"*)      nm-connection-editor ;;
    *"Wi-Fi"*)        ~/.config/polybar/wifi-menu.sh ;;
    *"Polybar"*)      xdg-open ~/.config/polybar/config.ini ;;
    *"i3 Config"*)    xdg-open ~/.config/i3/config ;;
esac
