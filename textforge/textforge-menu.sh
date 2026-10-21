#!/bin/bash
# textforge-menu.sh — Rofi mode picker for TextForge.
#
# Opens a Rofi menu with all available text transformation modes.
# Triggered by $mod+Shift+g (see i3/config).
#
# Flow: user has text highlighted → presses hotkey → picks a mode from the
# Rofi menu → menu closes, focus returns to the original window → textforge.sh
# copies the highlighted text, rewrites it, and pastes it back.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEXTFORGE="$SCRIPT_DIR/textforge.sh"

# Prompt icon: pen-to-square (Font Awesome 6 Free Solid \uf044)
PROMPT=$'\uf044'" TextForge"

# Font Awesome 6 Free Solid icons for menu entries
FA_PEN=$'\uf044'        # pen-to-square
FA_BRIEFCASE=$'\uf0b1'  # briefcase
FA_COMMENT=$'\uf075'    # comment
FA_SYNC=$'\uf021'       # arrows-rotate
FA_COMPRESS=$'\uf066'   # compress
FA_ENVELOPE=$'\uf0e0'   # envelope
FA_UNDO=$'\uf0e2'       # rotate-left

menu="${FA_PEN}  Fix Grammar & Spelling
${FA_BRIEFCASE}  Make Professional
${FA_COMMENT}  Make Casual
${FA_SYNC}  Rephrase / Improve
${FA_COMPRESS}  Summarize
${FA_ENVELOPE}  Format as Email
${FA_UNDO}  Undo Last Change"

choice=$(echo -n "$menu" | rofi -dmenu -i -p "$PROMPT" \
    -theme-str 'window {width: 28%;}')
[[ -z "$choice" ]] && exit 0

case "$choice" in
    *"Fix Grammar"*)     "$TEXTFORGE" fix ;;
    *"Professional"*)    "$TEXTFORGE" professional ;;
    *"Casual"*)          "$TEXTFORGE" casual ;;
    *"Rephrase"*)        "$TEXTFORGE" rephrase ;;
    *"Summarize"*)       "$TEXTFORGE" summarize ;;
    *"Email"*)           "$TEXTFORGE" email ;;
    *"Undo"*)            "$TEXTFORGE" --undo ;;
esac
