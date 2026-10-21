# dotstation

Personal workstation setup, backup, and restore CLI — built around a minimal i3wm desktop on Fedora.

![bar](docs/bar.png)

---

## CLI Reference

```
dotstation [COMMAND] [SUBCOMMAND] [OPTIONS]
```

### `init` — Register repo path *(run once after cloning)*

```bash
dotstation init                        # register current directory as repo
dotstation init ~/Softwares/dotstation # or specify the path explicitly
```

### `install` — Install all packages

```bash
dotstation install             # run install.sh (skips already-installed packages)
dotstation install --dry-run   # show what would be installed, no changes
```

Handles dnf, COPR, custom repos (Docker, Chrome, Cursor, VS Code), pip, fonts, and the
battery charge-threshold setup (script + udev rule + scoped sudoers entry).

### `deploy` — Deploy configs to `~/.config`

```bash
dotstation deploy all          # deploy i3 + polybar + dunst + rofi + textforge configs + fonts
dotstation deploy i3           # deploy ~/.config/i3 only
dotstation deploy polybar      # deploy ~/.config/polybar only
dotstation deploy dunst        # deploy ~/.config/dunst only (restarts the dunst service)
dotstation deploy rofi         # deploy ~/.config/rofi only
dotstation deploy textforge    # deploy ~/.config/textforge only
dotstation deploy fonts        # install bundled fonts to ~/.local/share/fonts
```

Existing configs are automatically backed up as `.bak` before deploying.

### `sync` — Sync live changes back into the repo

```bash
dotstation sync all            # sync ~/.config/{i3,polybar,dunst,rofi,textforge} → repo
dotstation sync i3             # sync i3 only
dotstation sync polybar        # sync polybar only
dotstation sync dunst          # sync dunst only
dotstation sync rofi           # sync rofi only
dotstation sync textforge      # sync textforge only
```

Shows a git diff summary after syncing. Then commit manually when happy.

### `backup` — Create a portable backup archive

```bash
dotstation backup all          # backup everything below in one archive
dotstation backup gpg          # backup ~/.gnupg only
dotstation backup ssh          # backup ~/.ssh only (encrypted by default)
dotstation backup dotfiles     # backup .gitconfig, fish config, /etc/hosts
dotstation backup configs      # backup ~/.config/{i3,polybar,dunst,rofi,textforge}
dotstation backup cursor       # backup Cursor skills, rules, transcripts, settings, extensions (encrypted by default)
dotstation backup editors      # backup JetBrains settings
dotstation backup manifests    # capture rpm/flatpak/uv/pip/crontab lists as reference text files
```

Backups are saved as timestamped `.tar.gz` archives in `~/dotstation-backups/`.  
Pass `--encrypt`/`--no-encrypt` to control GPG-encryption (`AES256`) — `ssh` and `cursor` default to encrypted since they can contain keys or personal chat history; everything else defaults to unencrypted.

Cursor skills/rules/transcripts are personal (not shipped in this public repo like i3/polybar), so they live only in these encrypted backup archives — never in `dotstation sync`.

Cursor's settings backup is curated rather than a raw directory copy: just `settings.json`, `keybindings.json`, and `snippets/` (not the multi-GB `workspaceStorage`/cache folders), and extensions are captured as an ID list (`cursor --list-extensions`) rather than the extension binaries themselves.

> **On a fresh machine:** Encrypted backups use symmetric encryption (passphrase only — no GPG key required). `gpg` is pre-installed on Fedora. You just need the passphrase you set when backing up. Your GPG keys are restored *from* the backup itself.

### `restore` — Restore from a backup archive

```bash
dotstation restore all         # restore everything (presents a list to pick from)
dotstation restore gpg         # restore ~/.gnupg
dotstation restore ssh         # restore ~/.ssh (fixes key permissions automatically)
dotstation restore dotfiles    # restore .gitconfig, fish config, /etc/hosts
dotstation restore configs     # restore i3, polybar, dunst, rofi, and textforge configs
dotstation restore cursor      # restore Cursor skills/rules/transcripts/settings, reinstall extensions
dotstation restore editors     # restore JetBrains settings
dotstation restore manifests   # extract rpm/flatpak/uv/pip/crontab lists to ~/dotstation-manifest for manual review
```

**App-install ordering:** config *files* are restored regardless of whether the corresponding app is installed — they're inert until then, so restore never blocks on this. Run `dotstation install` first regardless, since it's what actually installs Cursor/PyCharm/etc. If an app is still missing when you restore its configs, you'll get a note telling you which command to install. The one thing that *does* require the app to be present is extension replay (`cursor --install-extension ...`) — if `cursor` isn't on `$PATH` yet, that step is skipped with instructions to re-run it once installed. Package/extension manifests (`restore manifests`) are always extracted for manual review rather than auto-installed.

### `status` — Show current state

```bash
dotstation status              # show backups, deployed configs, and key commands
```

---

## Setup (Fresh Machine)

### Step 1 — Get dotstation

```bash
# Clone the repo
git clone https://github.com/digitronik/dotstation.git ~/dotstation
cd ~/dotstation

# Install uv (fast Python package manager — needed to install dotstation)
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.local/bin/env    # or open a new terminal

# Install the dotstation CLI
uv tool install .

# Register the repo path (tells dotstation where the repo lives)
dotstation init
```

> **Or do it all in one shot** — `bash install.sh` handles uv, the CLI, and all packages automatically:
> ```bash
> bash install.sh
> ```

### Step 2 — Install packages

```bash
dotstation install
```

Installs everything: i3, polybar, Docker, VS Code, Cursor, fonts, dev tools — skipping anything already present.

**Do this before Step 3.** Restoring configs never fails if an app isn't installed yet (files just sit inert until it is), but replaying Cursor extensions and having Cursor actually *do* anything with its restored settings requires Cursor to already exist — hence installing first.

### Step 3 — Restore your backup *(skip on first setup)*

If you're coming from a previous machine and have a backup archive:

```bash
dotstation restore all     # pick from available backups interactively
```

This restores your GPG keys, SSH keys, dotfiles, configs, and Cursor/JetBrains settings (reinstalling Cursor extensions since Step 2 already installed it). If anything's still missing an app, `restore` tells you exactly which command to install.

### Step 4 — Deploy configs

```bash
dotstation deploy all      # deploys i3, polybar, dunst, rofi, textforge, and fonts to ~/.config
```

Reload i3 with `Mod+Shift+c`. Done.

---

## Daily Workflow

After tweaking your live i3 or Polybar config:

```bash
dotstation sync all            # copy ~/.config → repo
git add -A
git commit -m "update config"
git push
```

Before formatting or switching machines:

```bash
dotstation backup all          # creates ~/dotstation-backups/dotstation-backup-<date>.tar.gz
# copy that file to an external drive or cloud storage
```

---

## TextForge — System-Wide AI Text Rewriter

A completely invisible, system-wide grammar and text correction tool that runs
locally and works in **every application** — Slack, Gmail, your IDE, terminal,
anything with a text field. No browser extensions, no cloud APIs, no GUI apps.

**How it works:** highlight text → press `$mod+g` → text rewrites itself in-place.
Under the hood, it copies the selection via `xdotool`/`xclip`, sends it to a local
[Ollama](https://ollama.com) model, and pastes the corrected text back — all in
about a second.

### Modes

| Hotkey | Mode | What it does |
| :--- | :--- | :--- |
| `$mod+g` | **Fix** | Fix grammar, spelling, and punctuation (the one-key default) |
| `$mod+Shift+g` → menu | **Professional** | Rewrite in a polished workplace tone |
| | **Casual** | Rewrite in a friendly conversational tone |
| | **Rephrase** | Improve clarity and flow without changing meaning |
| | **Summarize** | Condense to key points |
| | **Email** | Format as a professional email with greeting/sign-off |
| | **Undo** | Revert the last rewrite (restores the original text) |

### Setup

TextForge requires [Ollama](https://ollama.com) running locally with a fast model:

```bash
# Install Ollama (one-time)
curl -fsSL https://ollama.com/install.sh | sh

# Pull a fast model (1.5B — runs well even on CPU)
ollama pull qwen2.5:1.5b

# Start the server (or enable the systemd service)
ollama serve
```

Then deploy the scripts and reload i3:

```bash
dotstation deploy textforge    # or: dotstation deploy all
# Press Mod+Shift+c to reload i3
```

### Configuration

Create `~/.config/textforge/config` to override defaults:

```bash
# Change model (default: qwen2.5:1.5b)
TEXTFORGE_MODEL=llama3.2:3b

# Change Ollama URL (default: http://localhost:11434)
TEXTFORGE_OLLAMA_URL=http://localhost:11434
```

Dependencies (`xclip`, `xdotool`, `curl`, `jq`) are all installed by `bash install.sh`.

---

## Battery Charge Management

ThinkPads can cap charging at a threshold instead of always charging to 100% — since the
workstation is USB-C-connected most of the day, this keeps the battery resting around
75-80% (much healthier long-term than sitting at 100% under constant trickle-charge)
instead of degrading it for no benefit.

**Modes**, switched from the Polybar battery module (left-click):

| Mode | Threshold | When |
| :--- | :--- | :--- |
| **Daily** *(default)* | 75-80% | Docked/plugged in most of the day — the everyday setting |
| **Full** | 0-100% | Before a trip — need maximum runtime, no cap |

Switching is instant — no reboot needed. The kernel enforces the threshold live: in
**Daily** mode, once the battery hits 80% it stops charging and coasts on AC power
(showing as "limited" on the bar) until it drops back to 75%, and in **Full** mode it
charges straight to 100% like a normal laptop. This works with *any* charger (USB-C dock,
wall adapter, etc.) — the threshold lives in the battery controller, not tied to a
specific power source.

A udev rule re-applies **Daily** once per boot, so if you switch to **Full** for a trip
and forget to switch back, the next reboot self-heals to the protective default —
**Full** otherwise persists for the rest of the session.

Set up once via `bash install.sh` (see the "Battery Charge Threshold" section) — it
installs `battery-threshold.sh` to `/usr/local/bin`, the udev rule, and a narrowly-scoped
passwordless-sudo rule (only for that one script) so the Rofi menu can flip modes without
a password prompt. Check it's all in place with `dotstation status`.

This is a ThinkPad-specific hardware feature (`thinkpad_acpi` charge_control thresholds),
so `install.sh` detects support first (`/sys/class/power_supply/BAT*/charge_control_start_threshold`)
and skips the whole section cleanly on desktops or laptops without it — nothing gets
installed unless the hardware actually supports it. `battery-threshold.sh` and the udev
rule detect the battery device dynamically (`BAT0`, `BAT1`, ...) rather than assuming one.

---

## Keybindings

The modifier key is **Super** (Windows key), referred to as `$mod`.

| Keybinding | Action |
| :--- | :--- |
| `$mod+Shift+c` | Reload i3 config and restart Polybar |
| `$mod+Shift+e` | Log out (with confirmation) |
| `$mod+l` | Lock screen |
| `$mod+Shift+h` | Hibernate |
| `$mod+Shift+r` | Reboot |
| `$mod+Shift+s` | Shutdown |
| `$mod+d` | dmenu launcher |
| `$mod+Return` / `$mod+t` | Open terminal (tilix) |
| `$mod+h` | Open file manager (thunar) |
| `$mod+Shift+q` | Kill window |
| `$mod+f` | Fullscreen toggle |
| `$mod+r` | Resize mode |
| `$mod+Shift+minus` | Move to scratchpad |
| `$mod+minus` | Show scratchpad |
| `$mod+1-0` | Switch workspace |
| `$mod+Shift+1-0` | Move window to workspace |
| `PrintScreen` | Screenshot |
| `$mod+PrintScreen` | Start/stop GIF screen recording |
| `$mod+g` | **TextForge** — fix grammar on selected text (instant, one-key) |
| `$mod+Shift+g` | **TextForge** — open AI rewrite menu (fix, professional, casual, rephrase, summarize, email) |
| `$mod+m` | Display manager (arandr) |
| `$mod+Shift+v` | Audio controls (pavucontrol) |

---

## Scripts

| Script | Description |
| :--- | :--- |
| `i3/lock.sh` | Central handler for lock, logout, suspend, hibernate, reboot, shutdown |
| `i3/battery_notify.sh` | Background daemon — notifies on low (≤20%) and full (≥98%) battery |
| `i3/screencast.sh` | GIF screen recorder via `byzanz` — toggle with `$mod+PrintScreen` |
| `polybar/launch.sh` | Kills existing bar instances and starts Polybar fresh |
| `polybar/battery.sh` | Battery status module (UPower-backed — handles charge-threshold "battery care" states correctly) — right-click shows a health/cycles notification |
| `polybar/battery-menu.sh` | Rofi picker for the battery module — left-click to switch charge-threshold mode (Daily 75-80% / Full 100%) or open battery info |
| `battery/battery-threshold.sh` | Sets the ThinkPad charge-threshold via `sysfs` (`daily`/`full`/`status`) — installed to `/usr/local/bin` by `install.sh` |
| `battery/99-battery-threshold.rules` | udev rule that re-applies the daily cap once per boot — installed to `/etc/udev/rules.d` by `install.sh` |
| `polybar/bluetooth.sh` | Bluetooth status module (icon-only, no on/off text) — left-click toggles power, right-click opens Blueman to pair a device |
| `polybar/ethernet.sh` | Wired Ethernet status module (nmcli/sysfs-backed — shows a status immediately instead of hiding when USB dongles misreport link state or DHCP hasn't assigned an IP yet) |
| `polybar/calendar.sh` | Month-calendar notification popup for the date module — right-click (left-click toggles the built-in short/long date format) |
| `polybar/check-vpn.sh` | VPN status module — shows the active NetworkManager VPN profile name (works with OpenConnect, OpenVPN, WireGuard, etc.), or "VPN Off" |
| `polybar/vpn-menu.sh` | Rofi picker for the VPN module — left-click to connect/disconnect any configured VPN profile |
| `polybar/wifi-menu.sh` | Rofi picker for the Wi-Fi module — left-click to scan and connect to nearby networks |
| `polybar/netbird.sh` | NetBird (WireGuard mesh VPN) status module — shows connection state, IP, and connected peers |
| `polybar/netbird-menu.sh` | Rofi picker for the NetBird module — connect/disconnect, show peers, open UI |
| `polybar/powermenu.sh` | Rofi power menu — lock, log out, suspend, hibernate, reboot, shut down |
| `polybar/settings.sh` | Rofi settings menu — audio, display, network, Wi-Fi, config files |
| `textforge/textforge.sh` | System-wide AI text rewriter — copies selected text, rewrites via local Ollama, pastes back in-place |
| `textforge/textforge-menu.sh` | Rofi picker for TextForge — choose a rewrite mode (fix, professional, casual, rephrase, summarize, email, undo) |
| `dunst/dunstrc` | Notification theme matching the bar's palette (dark background, blue/red accent frames) |
| `rofi/config.rasi` | Rofi theme matching the bar's palette — used by the Wi-Fi, VPN, and TextForge pickers |
