#!/bin/bash
# =============================================================================
# install.sh — Setup script for Nikhil's i3wm environment.
#
# Installs all required packages using the correct method for each.
# Skips anything already installed. Reports failures at the end.
#
# Usage: bash install.sh
# =============================================================================

set -euo pipefail

# --- Terminal colors ----------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# --- Counters -----------------------------------------------------------------
INSTALLED=0
SKIPPED=0
FAILED=0
declare -a ERRORS=()

# --- Logging ------------------------------------------------------------------
info()    { echo -e "  ${BLUE}-->${NC}    $1"; }
success() { echo -e "  ${GREEN}[OK]${NC}    $1"; ((++INSTALLED)); }
skip()    { echo -e "  ${YELLOW}[SKIP]${NC}  $1 — already installed"; ((++SKIPPED)); }
fail()    { echo -e "  ${RED}[FAIL]${NC}  $1"; ((++FAILED)); ERRORS+=("$1"); }
section() { echo -e "\n${BOLD}$1${NC}\n  $(printf '%.0s─' {1..50})"; }

# --- Helpers ------------------------------------------------------------------

is_rpm()     { rpm -q "$1" &>/dev/null; }
is_flatpak() { flatpak info "$1" &>/dev/null 2>&1; }
is_cmd()     { command -v "$1" &>/dev/null; }

# Install a standard dnf package
dnf_install() {
    local pkg="$1" label="${2:-$1}"
    if is_rpm "$pkg"; then
        skip "$label"
    else
        info "Installing $label..."
        if sudo dnf install -y "$pkg" &>/dev/null; then
            success "$label"
        else
            fail "$label  (dnf install $pkg)"
        fi
    fi
}

# Enable a COPR repo and install a package
copr_install() {
    local copr="$1" pkg="$2" label="${3:-$2}"
    if is_rpm "$pkg"; then
        skip "$label"
    else
        info "Enabling COPR: $copr"
        sudo dnf copr enable -y "$copr" &>/dev/null || true
        info "Installing $label..."
        if sudo dnf install -y "$pkg" &>/dev/null; then
            success "$label"
        else
            fail "$label  (copr: $copr)"
        fi
    fi
}

# Add a custom DNF repo file and install a package
repo_install() {
    local repo_file="$1" pkg="$2" label="${3:-$2}"
    shift 3
    if is_rpm "$pkg"; then
        skip "$label"
    else
        if [ ! -f "$repo_file" ]; then
            info "Adding DNF repo for $label..."
            printf '%s\n' "$@" | sudo tee "$repo_file" > /dev/null
        fi
        info "Installing $label..."
        if sudo dnf install -y "$pkg" &>/dev/null; then
            success "$label"
        else
            fail "$label  (repo: $repo_file)"
        fi
    fi
}

# Install a Flatpak from Flathub
flatpak_install() {
    local app_id="$1" label="${2:-$1}"
    if is_flatpak "$app_id"; then
        skip "$label"
    else
        info "Installing $label (flatpak)..."
        if flatpak install -y flathub "$app_id" &>/dev/null; then
            success "$label"
        else
            fail "$label  (flatpak install $app_id)"
        fi
    fi
}

# Install a pip package
pip_install() {
    local pkg="$1" label="${2:-$1}" check_cmd="${3:-}"
    local installed=false
    [ -n "$check_cmd" ] && is_cmd "$check_cmd" && installed=true
    pip show "$pkg" &>/dev/null 2>&1 && installed=true
    if $installed; then
        skip "$label"
    else
        info "Installing $label (pip)..."
        if pip install --user "$pkg" &>/dev/null; then
            success "$label"
        else
            fail "$label  (pip install $pkg)"
        fi
    fi
}

# Copy fonts from the repo's fonts/ directory
install_font() {
    local src_dir="$1" label="$2"
    local dest="$HOME/.local/share/fonts/$(basename $src_dir)"
    if [ -d "$dest" ] && [ "$(ls -A $dest)" ]; then
        skip "Font: $label"
    else
        info "Installing font: $label..."
        mkdir -p "$dest"
        if cp -r "$src_dir"/. "$dest/"; then
            success "Font: $label"
        else
            fail "Font: $label  (copy from $src_dir)"
        fi
    fi
}

# --- Script root --------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
echo -e "\n${BOLD}  Nikhil's i3wm Environment — Install Script${NC}"
echo "  $(printf '%.0s═' {1..50})"
echo "  User   : $(whoami)"
echo "  Fedora : $(rpm -E %fedora 2>/dev/null || echo '?')"
echo "  $(printf '%.0s═' {1..50})"
# =============================================================================

# --- System update ------------------------------------------------------------
section "System Update"
info "Running dnf upgrade..."
if sudo dnf upgrade -y &>/dev/null; then
    info "System up to date"
else
    fail "System update (non-critical, continuing)"
fi

# --- Window Manager & Status Bar ----------------------------------------------
section "Window Manager & Status Bar"
dnf_install "i3"      "i3 Window Manager"
dnf_install "polybar" "Polybar"

# --- Terminal & Launcher ------------------------------------------------------
section "Terminal & Launcher"
dnf_install "tilix" "Tilix Terminal"
dnf_install "dmenu" "dmenu Launcher"

# --- File Management ----------------------------------------------------------
section "File Management"
dnf_install "Thunar" "Thunar File Manager"

# --- Display & Appearance -----------------------------------------------------
section "Display & Appearance"
dnf_install "feh"           "feh (Wallpaper)"
dnf_install "arandr"        "ARandR (Display Manager)"
dnf_install "brightnessctl" "brightnessctl (Brightness)"

# --- Audio --------------------------------------------------------------------
section "Audio"
dnf_install "pavucontrol" "PulseAudio Volume Control"

# --- Session & Power ----------------------------------------------------------
section "Session & Power"
dnf_install "i3lock" "i3lock (Screen Locker)"

# --- Bluetooth ----------------------------------------------------------------
section "Bluetooth"
dnf_install "blueman" "Blueman"

# bluez defaults AutoEnable=true (powers on at boot) — keep it off until used.
BLUETOOTH_CONF="/etc/bluetooth/main.conf"
if grep -q "^AutoEnable=false" "$BLUETOOTH_CONF" 2>/dev/null; then
    skip "Bluetooth AutoEnable=false"
else
    info "Disabling Bluetooth AutoEnable (stay off until you turn it on)..."
    if sudo sed -i -E 's/^#?AutoEnable=.*/AutoEnable=false/' "$BLUETOOTH_CONF" \
        && grep -q "^AutoEnable=false" "$BLUETOOTH_CONF" \
        && sudo systemctl restart bluetooth &>/dev/null; then
        success "Bluetooth AutoEnable=false"
    else
        fail "Bluetooth AutoEnable=false  (edit $BLUETOOTH_CONF manually: set AutoEnable=false under [Policy])"
    fi
fi

# --- Networking ---------------------------------------------------------------
section "Networking"
dnf_install "NetworkManager-tui" "NetworkManager TUI (nmtui)"

# --- Screenshots & Screencast -------------------------------------------------
section "Screenshots & Screencast"
dnf_install  "xfce4-screenshooter"  "Xfce4 Screenshooter"
copr_install "vishalvvr/byzanz" "byzanz" "Byzanz (GIF Recorder)"
pip_install  "python-xrectsel" "python-xrectsel (Region Selector)" "xrectsel"

# --- Menus & Dialogs ----------------------------------------------------------
section "Menus & Dialogs"
dnf_install "zenity"  "Zenity (GTK Dialogs)"
dnf_install "rofi"    "Rofi (App Launcher)"

# --- Notifications ------------------------------------------------------------
section "Notifications"
dnf_install "libnotify" "libnotify (notify-send)"

# --- Fonts --------------------------------------------------------------------
section "Fonts"
dnf_install "google-droid-sans-fonts" "Droid Sans (DNF)"

if [ -d "$SCRIPT_DIR/fonts/droid-sans" ]; then
    install_font "$SCRIPT_DIR/fonts/droid-sans"   "Droid Sans (local)"
fi
if [ -d "$SCRIPT_DIR/fonts/font-awesome" ]; then
    install_font "$SCRIPT_DIR/fonts/font-awesome" "Font Awesome 6 (local)"
fi

info "Rebuilding font cache..."
if fc-cache -fv &>/dev/null; then
    info "Font cache rebuilt"
else
    fail "Font cache rebuild"
fi

# --- Developer Tools ----------------------------------------------------------
section "Developer Tools"
dnf_install "git"          "Git"
dnf_install "vim-enhanced" "Vim"
dnf_install "fish"         "Fish Shell"

# --- IDEs & Editors -----------------------------------------------------------
section "IDEs & Editors"

# VS Code — Microsoft DNF repo
repo_install \
    "/etc/yum.repos.d/vscode.repo" \
    "code" \
    "Visual Studio Code" \
    "[code]" \
    "name=Visual Studio Code" \
    "baseurl=https://packages.microsoft.com/yumrepos/vscode" \
    "enabled=1" \
    "gpgcheck=1" \
    "gpgkey=https://packages.microsoft.com/keys/microsoft.asc"

# Cursor IDE — official DNF repo (preferred over snap — leaner, better system integration)
repo_install \
    "/etc/yum.repos.d/cursor.repo" \
    "cursor" \
    "Cursor IDE" \
    "[cursor]" \
    "name=Cursor" \
    "baseurl=https://downloads.cursor.com/yumrepo" \
    "enabled=1" \
    "gpgcheck=1" \
    "gpgkey=https://downloads.cursor.com/keys/anysphere.asc" \
    "repo_gpgcheck=1"

# PyCharm — COPR phracek/PyCharm
copr_install "phracek/PyCharm" "pycharm-community" "PyCharm Community"

# --- Browsers -----------------------------------------------------------------
section "Browsers"

# Firefox — default Fedora repo
dnf_install "firefox" "Firefox"

# Google Chrome — Google DNF repo
if ! is_rpm "google-chrome-stable"; then
    info "Setting up Google Chrome repo..."
    sudo dnf install -y fedora-workstation-repositories &>/dev/null || true
    sudo dnf config-manager --set-enabled google-chrome &>/dev/null || \
    sudo dnf config-manager setopt google-chrome.enabled=1 &>/dev/null || true
fi
dnf_install "google-chrome-stable" "Google Chrome"

# --- Media --------------------------------------------------------------------
section "Media"

# VLC — RPM Fusion free repo
if ! is_rpm "rpmfusion-free-release"; then
    info "Enabling RPM Fusion Free repo..."
    sudo dnf install -y \
        "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
        &>/dev/null || fail "RPM Fusion Free repo (VLC may fail)"
fi
dnf_install "vlc" "VLC"


# --- i3 Desktop Essentials ----------------------------------------------------
section "i3 Desktop Essentials"
dnf_install "xfce-polkit"           "Polkit Agent (xfce-polkit)"
dnf_install "lightdm"               "LightDM (Display Manager)"
dnf_install "lightdm-gtk"           "LightDM GTK Greeter"
dnf_install "dex-autostart"         "dex-autostart (XDG Autostart)"
dnf_install "dunst"                 "Dunst (Notification Daemon)"
dnf_install "xclip"                 "xclip (Clipboard)"

# --- System Utilities ---------------------------------------------------------
section "System Utilities"
dnf_install "htop"        "htop (Process Monitor)"
dnf_install "tree"        "tree (Directory Tree)"
dnf_install "curl"        "curl"
dnf_install "wget2-wget"  "wget"
dnf_install "rsync"       "rsync"
dnf_install "zip"         "zip"
dnf_install "unzip"       "unzip"
dnf_install "lsof"        "lsof"
dnf_install "net-tools"   "net-tools (ifconfig / netstat)"
dnf_install "nmap-ncat"   "nmap-ncat (nc)"

# --- Python Development -------------------------------------------------------
section "Python Development"
dnf_install "python3-pip"   "pip"
dnf_install "python3-devel" "Python Dev Headers"

# uv — fast Python package manager (official installer, self-updating)
if is_cmd "uv"; then
    skip "uv (Python Package Manager)"
else
    info "Installing uv..."
    if curl -LsSf https://astral.sh/uv/install.sh | sh &>/dev/null; then
        success "uv (Python Package Manager)"
    else
        fail "uv  (curl -LsSf https://astral.sh/uv/install.sh | sh)"
    fi
fi

# --- Node.js ------------------------------------------------------------------
section "Node.js"
dnf_install "nodejs-npm" "Node.js + npm"

# --- Java ---------------------------------------------------------------------
section "Java"
dnf_install "java-latest-openjdk" "Java Latest (OpenJDK)"

# --- Containers ---------------------------------------------------------------
section "Containers"

# Docker — official Docker DNF repo
repo_install \
    "/etc/yum.repos.d/docker-ce.repo" \
    "docker-ce" \
    "Docker CE" \
    "[docker-ce-stable]" \
    "name=Docker CE Stable - \$basearch" \
    "baseurl=https://download.docker.com/linux/fedora/\$releasever/\$basearch/stable" \
    "enabled=1" \
    "gpgcheck=1" \
    "gpgkey=https://download.docker.com/linux/fedora/gpg"
dnf_install "docker-ce-cli"           "Docker CLI"
dnf_install "docker-compose-plugin"   "Docker Compose Plugin"
dnf_install "docker-buildx-plugin"    "Docker Buildx Plugin"
dnf_install "podman"                  "Podman"
dnf_install "podman-compose"          "Podman Compose"

# --- File Systems -------------------------------------------------------------
section "File Systems"
dnf_install "ntfs-3g"     "NTFS support"
dnf_install "exfatprogs"  "exFAT support"
dnf_install "gvfs-mtp"    "MTP support (Android)"
dnf_install "android-tools" "Android Tools (adb / fastboot)"
dnf_install "jmtpfs"      "jmtpfs (MTP Filesystem)"

# --- VPN & Network ------------------------------------------------------------
section "VPN & Network"
dnf_install "openvpn"                "OpenVPN"
dnf_install "NetworkManager-openvpn" "NetworkManager OpenVPN Plugin"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "  $(printf '%.0s═' {1..50})"
echo -e "  ${BOLD}Summary${NC}"
echo "  $(printf '%.0s─' {1..50})"
echo -e "  ${GREEN}Installed : $INSTALLED${NC}"
echo -e "  ${YELLOW}Skipped   : $SKIPPED${NC}  (already present)"
echo -e "  ${RED}Failed    : $FAILED${NC}"

if [ ${#ERRORS[@]} -gt 0 ]; then
    echo ""
    echo -e "  ${RED}${BOLD}Failed packages:${NC}"
    for err in "${ERRORS[@]}"; do
        echo -e "    ${RED}•${NC} $err"
    done
    echo ""
    echo -e "  ${YELLOW}Tip:${NC} Re-run after fixing the above issues."
    echo "  $(printf '%.0s═' {1..50})"
    exit 1
fi

echo ""
echo -e "  ${GREEN}${BOLD}All packages installed successfully!${NC}"
echo -e "  Reload i3 with ${BOLD}Mod+Shift+c${NC} to apply changes."
echo "  $(printf '%.0s═' {1..50})"

# =============================================================================
# Bootstrap dotstation CLI
# =============================================================================
section "dotstation CLI"

if ! is_cmd "uv"; then
    info "Installing uv..."
    if curl -LsSf https://astral.sh/uv/install.sh | sh &>/dev/null; then
        success "uv"
        export PATH="$HOME/.local/bin:$PATH"
    else
        fail "uv  (curl -LsSf https://astral.sh/uv/install.sh | sh)"
    fi
else
    skip "uv"
fi

if is_cmd "uv"; then
    if uv tool list 2>/dev/null | grep -q "^dotstation"; then
        skip "dotstation CLI"
    else
        info "Installing dotstation CLI..."
        if uv tool install "$SCRIPT_DIR" &>/dev/null; then
            success "dotstation CLI installed"
            dotstation init "$SCRIPT_DIR" &>/dev/null || true
            echo ""
            echo "  Run [dotstation --help] to get started."
        else
            fail "dotstation CLI  (uv tool install $SCRIPT_DIR)"
        fi
    fi
fi

echo "  $(printf '%.0s═' {1..50})"
