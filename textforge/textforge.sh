#!/bin/bash
# textforge.sh — System-wide AI text rewriter for i3wm.
#
# Highlight text in any app (Slack, Gmail, IDE, terminal) → hotkey → text
# is rewritten in-place via a local Ollama model. No browser extensions,
# no cloud APIs, no GUI apps — just X11 clipboard + xdotool + Ollama.
#
# Usage:
#   textforge.sh <mode>    Rewrite selected text with the given mode
#   textforge.sh --undo    Restore the original text before the last rewrite
#   textforge.sh --list    Print available modes (used by textforge-menu.sh)
#
# Modes:
#   fix           Fix grammar, spelling, and punctuation
#   professional  Rewrite in a polished workplace tone
#   casual        Rewrite in a friendly conversational tone
#   rephrase      Improve clarity and flow
#   summarize     Condense to key points
#   email         Format as a professional email
#
# Configuration — set in ~/.config/textforge/config (sourced as bash):
#   TEXTFORGE_MODEL=qwen2.5:1.5b       # Ollama model to use
#   TEXTFORGE_OLLAMA_URL=http://localhost:11434   # Ollama API endpoint
#
# Dependencies: xclip, xdotool, curl, jq, notify-send (libnotify)
# Requires:     Ollama running locally with a pulled model
#
# Part of https://github.com/digitronik/dotstation

set -euo pipefail

# --- Configuration -----------------------------------------------------------

OLLAMA_URL="${TEXTFORGE_OLLAMA_URL:-http://localhost:11434}"
OLLAMA_MODEL="${TEXTFORGE_MODEL:-qwen2.5:1.5b}"
UNDO_FILE="/tmp/textforge-undo"
WINDOW_FILE="/tmp/textforge-window"

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/textforge/config"
TARGET_WINDOW=""
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# --- Notification helper ------------------------------------------------------
# Uses the x-dunst-stack-tag hint so every TextForge notification replaces the
# previous one (processing → done / error) instead of stacking up.

notify() {
    local urgency="${1:-normal}" title="$2" body="${3:-}" timeout="${4:-3000}"
    notify-send -u "$urgency" -t "$timeout" \
        -h "string:x-dunst-stack-tag:textforge" \
        "$title" "$body"
}

# --- Mode definitions --------------------------------------------------------

declare -A PROMPTS=(
    [fix]="Fix the grammar, spelling, punctuation, and sentence flow of the following text. Preserve the original meaning, tone, formatting, and language. Do not add or remove sentences."
    [professional]="Rewrite the following text in a professional, polished tone suitable for workplace emails and Slack messages. Preserve the core meaning and key details."
    [casual]="Rewrite the following text in a casual, friendly, conversational tone. Preserve the original meaning."
    [rephrase]="Rephrase the following text to improve clarity, readability, and flow. Preserve the original meaning. Do not add new information."
    [summarize]="Summarize the following text concisely. Preserve the key points only."
    [email]="Rewrite the following text as a well-structured professional email. Include a greeting and a sign-off. Keep it concise."
)

declare -A MODE_LABELS=(
    [fix]="Grammar fixed"
    [professional]="Made professional"
    [casual]="Made casual"
    [rephrase]="Rephrased"
    [summarize]="Summarized"
    [email]="Formatted as email"
)

SYSTEM_PROMPT="You are a text editor. You receive text and an editing instruction. Follow the instruction exactly. Output ONLY the resulting text. Never add explanations, comments, markdown formatting, code blocks, or quotation marks around your output. Never start with phrases like 'Here is' or 'Sure'. Just output the raw transformed text."

# --- X11 selection capture ----------------------------------------------------
# i3 runs this script after the hotkey, so we must not trust the clipboard blindly:
# if Ctrl+C never reaches the focused app, xclip still returns whatever you copied
# earlier (e.g. "dotstation deploy textforge"). Prefer PRIMARY (mouse highlight),
# then Ctrl+C on the window that had focus when the script started, and require the
# clipboard to actually change.

paste_to_target() {
    if [[ -n "$TARGET_WINDOW" ]] && xdotool windowactivate --sync "$TARGET_WINDOW" 2>/dev/null; then
        sleep 0.05
        xdotool key --window "$TARGET_WINDOW" --clearmodifiers "$@"
    else
        xdotool key --clearmodifiers "$@"
    fi
}

capture_selection_text() {
    local win primary before after

    win=$(xdotool getactivewindow 2>/dev/null || true)
    TARGET_WINDOW="$win"

    primary=$(xclip -o -selection primary 2>/dev/null || true)
    if [[ -n "$primary" ]]; then
        printf '%s' "$primary"
        return 0
    fi

    before=$(xclip -o -selection clipboard 2>/dev/null || true)

    if [[ -n "$win" ]]; then
        xdotool windowactivate --sync "$win" 2>/dev/null || true
        sleep 0.05
        xdotool key --window "$win" --clearmodifiers ctrl+c
    else
        xdotool key --clearmodifiers ctrl+c
    fi
    sleep 0.2

    after=$(xclip -o -selection clipboard 2>/dev/null || true)

    if [[ -z "$after" ]]; then
        notify critical "TextForge" "No text selected — highlight text first"
        return 1
    fi

    if [[ "$after" == "$before" ]]; then
        notify critical "TextForge" "Could not copy selection\nKeep the text highlighted, or select with the mouse.\n(Ctrl+C did not change the clipboard — avoiding stale paste.)"
        return 1
    fi

    printf '%s' "$after"
    return 0
}

# --- Subcommands --------------------------------------------------------------

# --list: print available modes (used by textforge-menu.sh)
if [[ "${1:-}" == "--list" ]]; then
    for mode in fix professional casual rephrase summarize email; do
        echo "$mode"
    done
    exit 0
fi

# --undo: paste back the original text from before the last rewrite
if [[ "${1:-}" == "--undo" ]]; then
    if [[ -f "$UNDO_FILE" ]]; then
        [[ -f "$WINDOW_FILE" ]] && TARGET_WINDOW=$(cat "$WINDOW_FILE" 2>/dev/null || true)
        xclip -selection clipboard < "$UNDO_FILE"
        sleep 0.1
        paste_to_target ctrl+v
        notify normal "TextForge" "↩ Reverted to original"
        rm -f "$UNDO_FILE" "$WINDOW_FILE"
    else
        notify critical "TextForge" "Nothing to undo"
    fi
    exit 0
fi

# --- Validate mode ------------------------------------------------------------

MODE="${1:-fix}"

if [[ -z "${PROMPTS[$MODE]+set}" ]]; then
    notify critical "TextForge" "Unknown mode: $MODE"
    exit 1
fi

# --- Preflight checks ---------------------------------------------------------

for cmd in xclip xdotool curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
        notify critical "TextForge" "Missing dependency: $cmd\nRun: sudo dnf install $cmd"
        exit 1
    fi
done

if ! curl -sf --max-time 2 "$OLLAMA_URL/api/tags" &>/dev/null; then
    notify critical "TextForge" "Ollama is not running\nStart it: ollama serve"
    exit 1
fi

# --- Copy selected text -------------------------------------------------------

TEXT=$(capture_selection_text) || exit 1

# --- Save original for undo ---------------------------------------------------

printf '%s' "$TEXT" > "$UNDO_FILE"
[[ -n "$TARGET_WINDOW" ]] && printf '%s' "$TARGET_WINDOW" > "$WINDOW_FILE"

# --- Notify processing --------------------------------------------------------

notify low "TextForge" "✦ ${MODE^}…" 30000

# --- Call Ollama API ----------------------------------------------------------
# Build the request with jq so the user's text is properly JSON-escaped (handles
# newlines, quotes, backslashes, Unicode — anything you'd find in real text).

USER_PROMPT="${PROMPTS[$MODE]}

${TEXT}"

REQUEST=$(jq -n \
    --arg model "$OLLAMA_MODEL" \
    --arg system "$SYSTEM_PROMPT" \
    --arg user "$USER_PROMPT" \
    '{
        model:   $model,
        stream:  false,
        messages: [
            {role: "system", content: $system},
            {role: "user",   content: $user}
        ]
    }')

RESPONSE=$(curl -sf --max-time 120 "$OLLAMA_URL/api/chat" \
    -H "Content-Type: application/json" \
    -d "$REQUEST" 2>/dev/null) || {
    notify critical "TextForge" "Ollama request failed\nIs model '${OLLAMA_MODEL}' pulled?"
    exit 1
}

CORRECTED=$(echo "$RESPONSE" | jq -r '.message.content // empty')

if [[ -z "$CORRECTED" ]]; then
    ERROR=$(echo "$RESPONSE" | jq -r '.error // "Unknown error"')
    notify critical "TextForge" "Ollama error: $ERROR"
    exit 1
fi

# --- Paste corrected text back ------------------------------------------------

printf '%s' "$CORRECTED" | xclip -selection clipboard
sleep 0.1
paste_to_target ctrl+v

# --- Done ---------------------------------------------------------------------

notify normal "TextForge" "✓ ${MODE_LABELS[$MODE]}" 2000
