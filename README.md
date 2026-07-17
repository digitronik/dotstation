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

Handles dnf, COPR, custom repos (Docker, Chrome, Cursor, VS Code), pip, and fonts.

### `deploy` — Deploy configs to `~/.config`

```bash
dotstation deploy all          # deploy i3 + polybar configs + fonts
dotstation deploy i3           # deploy ~/.config/i3 only
dotstation deploy polybar      # deploy ~/.config/polybar only
dotstation deploy fonts        # install bundled fonts to ~/.local/share/fonts
```

Existing configs are automatically backed up as `.bak` before deploying.

### `sync` — Sync live changes back into the repo

```bash
dotstation sync all            # sync ~/.config/i3 + ~/.config/polybar → repo
dotstation sync i3             # sync i3 only
dotstation sync polybar        # sync polybar only
```

Shows a git diff summary after syncing. Then commit manually when happy.

### `backup` — Create a portable backup archive

```bash
dotstation backup all          # backup everything below in one archive
dotstation backup gpg          # backup ~/.gnupg only
dotstation backup ssh          # backup ~/.ssh only (encrypted by default)
dotstation backup dotfiles     # backup .gitconfig, fish config, /etc/hosts
dotstation backup configs      # backup ~/.config/i3 and ~/.config/polybar
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
dotstation restore configs     # restore i3 and polybar configs
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
dotstation deploy all      # deploys i3, polybar, and fonts to ~/.config
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

## Keybindings

The modifier key is **Super** (Windows key), referred to as `$mod`.

| Keybinding | Action |
| :--- | :--- |
| `$mod+Shift+c` | Reload i3 config |
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
| `polybar/bluetooth.sh` | Bluetooth status module — left-click toggles power |
| `polybar/check-vpn.sh` | VPN status module (checks `tun0` interface) |
| `polybar/powermenu.sh` | Zenity-based power menu |
| `polybar/settings.sh` | Zenity-based settings menu |
