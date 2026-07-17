import os
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Literal, Optional

from dotstation.utils import capture_output, list_extensions

# Standard XDG/home paths — always available
HOME = Path.home()
CONFIG_DIR = HOME / ".config"
LOCAL_DIR = HOME / ".local"

# Where dotstation stores its own config
_REPO_CONFIG = HOME / ".config" / "dotstation" / "repo_path"

TargetKind = Literal["path", "glob", "generated"]


@dataclass(frozen=True)
class BackupTarget:
    """Describes one thing dotstation can back up / restore.

    kind="path"      `path` is a single file or directory (relative to HOME, or absolute like /etc/hosts).
    kind="glob"      `path` is a glob pattern (str) relative to HOME that may match multiple files/dirs
                     (e.g. per-project Cursor transcript folders).
    kind="generated" `path` is the archive filename to write; `generator` produces the text content at
                     backup time (e.g. `rpm -qa`, `cursor --list-extensions`) instead of copying a file.

    `requires_cmd` names the CLI command that must be installed for this target to actually *do*
    anything once restored (e.g. "cursor" for Cursor settings, "kubectl" for a kubeconfig). It never
    blocks backup or restore of the raw files — it only drives the readiness warnings / extension
    replay in `dotstation restore`, since the app should generally be installed first.
    """

    path: Path | str
    kind: TargetKind = "path"
    requires_cmd: Optional[str] = None
    generator: Optional[Callable[[], str]] = None


# Original targets — GPG, SSH, dotfiles, and window-manager configs.
BACKUP_TARGETS: dict[str, BackupTarget] = {
    "gpg":       BackupTarget(HOME / ".gnupg"),
    "ssh":       BackupTarget(HOME / ".ssh"),
    "gitconfig": BackupTarget(HOME / ".gitconfig"),
    "fish":      BackupTarget(CONFIG_DIR / "fish"),
    "i3":        BackupTarget(CONFIG_DIR / "i3"),
    "polybar":   BackupTarget(CONFIG_DIR / "polybar"),
    "hosts":     BackupTarget(Path("/etc/hosts")),
}

# Cursor IDE — skills/rules/transcripts are personal, so they're backup-only (never synced to the
# public git repo like i3/polybar are).
CURSOR_TARGETS: dict[str, BackupTarget] = {
    "cursor-skills":      BackupTarget(HOME / ".cursor" / "skills"),
    "cursor-rules":       BackupTarget(HOME / ".cursor" / "rules"),
    "cursor-transcripts": BackupTarget(".cursor/projects/*/agent-transcripts", kind="glob"),
    "cursor-argv":        BackupTarget(HOME / ".cursor" / "argv.json"),
    "cursor-mcp":         BackupTarget(HOME / ".cursor" / "mcp.json"),
    "cursor-settings":    BackupTarget(CONFIG_DIR / "Cursor" / "User" / "settings.json",    requires_cmd="cursor"),
    "cursor-keybindings": BackupTarget(CONFIG_DIR / "Cursor" / "User" / "keybindings.json", requires_cmd="cursor"),
    "cursor-snippets":    BackupTarget(CONFIG_DIR / "Cursor" / "User" / "snippets",         requires_cmd="cursor"),
    "cursor-extensions":  BackupTarget(
        "cursor-extensions.txt", kind="generated", requires_cmd="cursor",
        generator=lambda: list_extensions("cursor"),
    ),
}

# JetBrains — curated settings only (no VS Code; skipped per user preference).
EDITOR_TARGETS: dict[str, BackupTarget] = {
    "jetbrains": BackupTarget(".config/JetBrains/*/options", kind="glob"),
}

# Point-in-time reference manifests. These are captured as plain text and, on restore, extracted for
# you to read/diff rather than auto-reinstalled (reinstalling hundreds of rpms unattended is risky).
MANIFEST_TARGETS: dict[str, BackupTarget] = {
    "rpm-packages": BackupTarget(
        "rpm-packages.txt", kind="generated",
        generator=lambda: capture_output(["rpm", "-qa"]),
    ),
    "flatpak-apps": BackupTarget(
        "flatpak-apps.txt", kind="generated",
        generator=lambda: capture_output(["flatpak", "list", "--app", "--columns=application"]),
    ),
    "uv-tools": BackupTarget(
        "uv-tools.txt", kind="generated",
        generator=lambda: capture_output(["uv", "tool", "list"]),
    ),
    "pip-packages": BackupTarget(
        "pip-packages.txt", kind="generated",
        generator=lambda: capture_output(["pip", "list", "--user", "--format=freeze"]),
    ),
    "crontab": BackupTarget(
        "crontab.txt", kind="generated",
        generator=lambda: capture_output(["crontab", "-l"]),
    ),
}

# Everything combined — what `dotstation backup all` / `dotstation restore all` operate on.
ALL_TARGETS: dict[str, BackupTarget] = {
    **BACKUP_TARGETS,
    **CURSOR_TARGETS,
    **EDITOR_TARGETS,
    **MANIFEST_TARGETS,
}

# Default backup output directory
DEFAULT_BACKUP_DIR = HOME / "dotstation-backups"


def target_exists(target: BackupTarget) -> bool:
    """Whether a target currently has something to back up (used by `dotstation status`)."""
    if target.kind == "path":
        return Path(target.path).exists()
    if target.kind == "glob":
        return any(HOME.glob(str(target.path)))
    if target.kind == "generated":
        from dotstation.utils import is_command_available
        return target.requires_cmd is None or is_command_available(target.requires_cmd)
    return False


def get_repo_root() -> Path:
    """Return the dotstation repo root path.

    Resolution order:
      1. DOTSTATION_REPO environment variable
      2. ~/.config/dotstation/repo_path (written by `dotstation init`)
      3. Walk up from __file__ (works when running from source)
    """
    if "DOTSTATION_REPO" in os.environ:
        return Path(os.environ["DOTSTATION_REPO"]).expanduser().resolve()

    if _REPO_CONFIG.exists():
        return Path(_REPO_CONFIG.read_text().strip()).expanduser().resolve()

    # Fallback: source install (not via uv tool)
    candidate = Path(__file__).parent.parent
    if (candidate / "pyproject.toml").exists():
        return candidate

    raise RuntimeError(
        "Repo path not configured.\n"
        "Run:  dotstation init <path-to-repo>\n"
        "Or:   export DOTSTATION_REPO=<path-to-repo>"
    )


def get_repo_i3_dir() -> Path:
    return get_repo_root() / "i3"


def get_repo_polybar_dir() -> Path:
    return get_repo_root() / "polybar"


def get_repo_fonts_dir() -> Path:
    return get_repo_root() / "fonts"
