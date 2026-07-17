import io
import tarfile
import datetime
from pathlib import Path

import click
from rich.console import Console

from dotstation.constants import (
    BackupTarget,
    BACKUP_TARGETS,
    CURSOR_TARGETS,
    EDITOR_TARGETS,
    MANIFEST_TARGETS,
    ALL_TARGETS,
    DEFAULT_BACKUP_DIR,
)
from dotstation.utils import ensure_dir, path_exists

console = Console()


def _timestamp() -> str:
    # Microsecond precision avoids silently overwriting a previous archive when two backups
    # run within the same second (e.g. scripted `backup all` immediately followed by another).
    return datetime.datetime.now().strftime("%Y-%m-%d_%H%M%S_%f")


def _add_generated(tar: tarfile.TarFile, arcname: str, content: str) -> None:
    """Write generated text content (e.g. `rpm -qa` output) into the tar without a temp file."""
    data = content.encode()
    info = tarfile.TarInfo(name=arcname)
    info.size = len(data)
    info.mtime = int(datetime.datetime.now().timestamp())
    tar.addfile(info, io.BytesIO(data))


def _backup_items(items: dict[str, BackupTarget], output_dir: Path, encrypt: bool) -> None:
    ensure_dir(output_dir)
    archive_name = f"dotstation-backup-{_timestamp()}.tar.gz"
    archive_path = output_dir / archive_name

    missing = []

    with tarfile.open(archive_path, "w:gz") as tar:
        for label, target in items.items():
            if target.kind == "generated":
                content = ""
                try:
                    content = target.generator() if target.generator else ""
                except Exception as e:
                    console.print(f"  [red][FAIL][/red]  {label} — generator error ({e})")
                if not content:
                    missing.append((label, str(target.path)))
                    console.print(f"  [yellow][SKIP][/yellow]  {label} — nothing to capture")
                    continue
                arcname = f"dotstation-manifest/{target.path}"
                _add_generated(tar, arcname, content)
                console.print(f"  [green][OK][/green]    Captured [bold]{label}[/bold]  ({arcname})")

            elif target.kind == "glob":
                matches = sorted(Path.home().glob(str(target.path)))
                if not matches:
                    missing.append((label, str(target.path)))
                    console.print(f"  [yellow][SKIP][/yellow]  {label} — no matches ({target.path})")
                    continue
                for m in matches:
                    tar.add(m, arcname=str(m.relative_to(Path.home())))
                console.print(f"  [green][OK][/green]    Backed up [bold]{label}[/bold]  ({len(matches)} match(es))")

            else:  # "path"
                path = Path(target.path)
                if path_exists(path):
                    arcname = str(path.relative_to(Path.home())) if path.is_relative_to(Path.home()) else str(path).lstrip("/")
                    tar.add(path, arcname=arcname)
                    console.print(f"  [green][OK][/green]    Backed up [bold]{label}[/bold]  ({path})")
                else:
                    missing.append((label, str(path)))
                    console.print(f"  [yellow][SKIP][/yellow]  {label} — not found ({path})")

    if encrypt:
        _gpg_encrypt(archive_path)
        archive_path.unlink()
        archive_path = Path(str(archive_path) + ".gpg")

    console.print(f"\n  [bold green]Archive saved:[/bold green] {archive_path}")
    if missing:
        console.print(f"  [yellow]Skipped {len(missing)} missing/empty item(s).[/yellow]")


def _gpg_encrypt(path: Path) -> None:
    import subprocess
    console.print("  [dim]Encrypting archive (you will be prompted to set a passphrase)...[/dim]")
    result = subprocess.run(
        ["gpg", "--symmetric", "--cipher-algo", "AES256", str(path)]
    )
    if result.returncode != 0:
        console.print("  [red][FAIL][/red]  GPG encryption failed — keeping unencrypted archive.")


@click.group()
def backup():
    """Backup GPG keys, SSH keys, dotfiles, window-manager configs, Cursor, and JetBrains settings."""


@backup.command("gpg")
@click.option("--output", "-o", default=str(DEFAULT_BACKUP_DIR), help="Output directory.")
@click.option("--encrypt/--no-encrypt", default=False, help="GPG-encrypt the archive.")
def backup_gpg(output, encrypt):
    """Backup GPG keys (~/.gnupg)."""
    console.print("\n[bold]Backing up GPG keys...[/bold]")
    _backup_items({"gpg": BACKUP_TARGETS["gpg"]}, Path(output), encrypt)


@backup.command("ssh")
@click.option("--output", "-o", default=str(DEFAULT_BACKUP_DIR), help="Output directory.")
@click.option("--encrypt/--no-encrypt", default=True, help="GPG-encrypt the archive.")
def backup_ssh(output, encrypt):
    """Backup SSH keys and config (~/.ssh)."""
    console.print("\n[bold]Backing up SSH keys...[/bold]")
    _backup_items({"ssh": BACKUP_TARGETS["ssh"]}, Path(output), encrypt)


@backup.command("dotfiles")
@click.option("--output", "-o", default=str(DEFAULT_BACKUP_DIR), help="Output directory.")
@click.option("--encrypt/--no-encrypt", default=False, help="GPG-encrypt the archive.")
def backup_dotfiles(output, encrypt):
    """Backup dotfiles (.gitconfig, fish config, etc.)."""
    console.print("\n[bold]Backing up dotfiles...[/bold]")
    targets = {k: v for k, v in BACKUP_TARGETS.items() if k in ("gitconfig", "fish", "hosts")}
    _backup_items(targets, Path(output), encrypt)


@backup.command("configs")
@click.option("--output", "-o", default=str(DEFAULT_BACKUP_DIR), help="Output directory.")
@click.option("--encrypt/--no-encrypt", default=False, help="GPG-encrypt the archive.")
def backup_configs(output, encrypt):
    """Backup i3 and Polybar configs."""
    console.print("\n[bold]Backing up i3 and Polybar configs...[/bold]")
    targets = {k: v for k, v in BACKUP_TARGETS.items() if k in ("i3", "polybar")}
    _backup_items(targets, Path(output), encrypt)


@backup.command("cursor")
@click.option("--output", "-o", default=str(DEFAULT_BACKUP_DIR), help="Output directory.")
@click.option("--encrypt/--no-encrypt", default=True, help="GPG-encrypt the archive (on by default — may contain personal transcripts/tokens).")
def backup_cursor(output, encrypt):
    """Backup Cursor skills, rules, transcripts, settings, and extensions list."""
    console.print("\n[bold]Backing up Cursor data...[/bold]")
    _backup_items(CURSOR_TARGETS, Path(output), encrypt)


@backup.command("editors")
@click.option("--output", "-o", default=str(DEFAULT_BACKUP_DIR), help="Output directory.")
@click.option("--encrypt/--no-encrypt", default=False, help="GPG-encrypt the archive.")
def backup_editors(output, encrypt):
    """Backup JetBrains settings."""
    console.print("\n[bold]Backing up editor configs...[/bold]")
    _backup_items(EDITOR_TARGETS, Path(output), encrypt)


@backup.command("manifests")
@click.option("--output", "-o", default=str(DEFAULT_BACKUP_DIR), help="Output directory.")
@click.option("--encrypt/--no-encrypt", default=False, help="GPG-encrypt the archive.")
def backup_manifests(output, encrypt):
    """Capture package/extension manifests (rpm, flatpak, uv, pip, crontab) as reference text files."""
    console.print("\n[bold]Capturing package manifests...[/bold]")
    _backup_items(MANIFEST_TARGETS, Path(output), encrypt)


@backup.command("all")
@click.option("--output", "-o", default=str(DEFAULT_BACKUP_DIR), help="Output directory.")
@click.option("--encrypt/--no-encrypt", default=True, help="GPG-encrypt the archive.")
def backup_all(output, encrypt):
    """Backup everything — GPG, SSH, dotfiles, configs, Cursor, editors, and manifests."""
    console.print("\n[bold]Backing up everything...[/bold]")
    _backup_items(ALL_TARGETS, Path(output), encrypt)
