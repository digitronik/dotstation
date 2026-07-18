import tarfile
import subprocess
from pathlib import Path

import click
from rich.console import Console

from dotstation.constants import (
    BackupTarget,
    CURSOR_TARGETS,
    EDITOR_TARGETS,
    ALL_TARGETS,
    DEFAULT_BACKUP_DIR,
)
from dotstation.utils import ensure_dir, is_command_available

console = Console()


def _fix_permissions(paths: list[Path]) -> None:
    """Fix file permissions for security-sensitive restored paths."""
    for path in paths:
        if not path.exists():
            continue

        # ~/.gnupg — strict: 700 dir, 600 all files
        if path.name == ".gnupg":
            path.chmod(0o700)
            for item in path.rglob("*"):
                item.chmod(0o700 if item.is_dir() else 0o600)

        # ~/.ssh — 700 dir, 600 keys, 644 public/known_hosts
        elif path.name == ".ssh":
            path.chmod(0o700)
            for item in path.rglob("*"):
                if item.is_dir():
                    item.chmod(0o700)
                elif item.suffix == ".pub" or item.name in ("known_hosts", "known_hosts.old", "authorized_keys"):
                    item.chmod(0o644)
                else:
                    item.chmod(0o600)

        # i3 and polybar — 755 dirs, 644 files, 755 scripts
        elif path.name in ("i3", "polybar"):
            for item in path.rglob("*"):
                if item.is_dir():
                    item.chmod(0o755)
                elif item.suffix == ".sh":
                    item.chmod(0o755)
                else:
                    item.chmod(0o644)

        # fish config — 755 dirs, 644 files
        elif path.name == "fish":
            for item in path.rglob("*"):
                item.chmod(0o755 if item.is_dir() else 0o644)

        # .gitconfig — 644
        elif path.name == ".gitconfig":
            path.chmod(0o644)

    console.print("  [dim]Permissions fixed.[/dim]")


def _check_app_readiness(items: dict[str, BackupTarget]) -> None:
    """Warn about any restored target whose app isn't installed yet.

    Restoring the raw config files never requires the app to be present — they just sit inert until
    it is. This only flags it so you know to run `dotstation install` before the config takes effect.
    """
    missing_apps = sorted({
        t.requires_cmd for t in items.values()
        if t.requires_cmd and not is_command_available(t.requires_cmd)
    })
    if missing_apps:
        console.print(
            "\n  [yellow]Note:[/yellow] configs were restored for apps that aren't installed on this "
            "machine yet. They'll take effect once you install them — run [bold]dotstation install[/bold] first:"
        )
        for app in missing_apps:
            console.print(f"    • {app}")


def _replay_extensions(manifest_filename: str, editor_cmd: str) -> None:
    """Reinstall an editor's extensions from its backed-up manifest, if the editor is installed."""
    manifest_path = Path.home() / "dotstation-manifest" / manifest_filename
    if not manifest_path.exists():
        return

    if not is_command_available(editor_cmd):
        console.print(
            f"  [yellow][SKIP][/yellow]  {editor_cmd} not installed — extensions not reinstalled.\n"
            f"    Install {editor_cmd} first (dotstation install), then run:\n"
            f"    [dim]cat {manifest_path} | xargs -n1 {editor_cmd} --install-extension[/dim]"
        )
        return

    extensions = [e.strip() for e in manifest_path.read_text().splitlines() if e.strip()]
    if not extensions:
        return

    console.print(f"  [dim]Reinstalling {len(extensions)} {editor_cmd} extension(s)...[/dim]")
    for ext in extensions:
        subprocess.run([editor_cmd, "--install-extension", ext], capture_output=True)
    console.print(f"  [green][OK][/green]    {editor_cmd} extensions reinstalled.")


def _list_backups(backup_dir: Path) -> list[Path]:
    if not backup_dir.exists():
        return []
    return sorted(backup_dir.glob("dotstation-backup-*.tar.gz*"), reverse=True)


def _decrypt_if_needed(archive: Path) -> Path:
    if archive.suffix == ".gpg":
        decrypted = Path(str(archive).removesuffix(".gpg"))
        console.print("  [dim]Decrypting archive (you will be prompted for the passphrase)...[/dim]")
        result = subprocess.run(
            ["gpg", "--output", str(decrypted), "--decrypt", str(archive)]
        )
        if result.returncode != 0:
            raise click.ClickException("GPG decryption failed. Check your passphrase and try again.")
        return decrypted
    return archive


def _restore_archive(archive: Path, targets: list[str] | None = None) -> None:
    archive = _decrypt_if_needed(archive)

    with tarfile.open(archive, "r:gz") as tar:
        members = tar.getmembers()
        for member in members:
            if targets:
                match = any(member.name.startswith(t.lstrip("/")) for t in targets)
                if not match:
                    continue
            dest = Path.home() / member.name
            ensure_dir(dest.parent)
            # Remove existing file/dir to avoid permission conflicts
            if dest.exists() and not dest.is_dir():
                try:
                    dest.unlink()
                except PermissionError:
                    dest.chmod(0o644)
                    dest.unlink()
            try:
                tar.extract(member, path=Path.home(), filter="data")
                console.print(f"  [green][OK][/green]    Restored {member.name}")
            except PermissionError:
                console.print(f"  [yellow][SKIP][/yellow]  {member.name} — permission denied, skipping")


def _pick_backup(backup_dir: Path) -> Path:
    backups = _list_backups(backup_dir)
    if not backups:
        raise click.ClickException(f"No backups found in {backup_dir}")

    console.print("\n  [bold]Available backups:[/bold]")
    for i, b in enumerate(backups, 1):
        console.print(f"    {i}. {b.name}")

    choice = click.prompt("\n  Select backup number", type=int, default=1)
    if choice < 1 or choice > len(backups):
        raise click.ClickException("Invalid selection.")
    return backups[choice - 1]


@click.group()
def restore():
    """Restore GPG keys, SSH keys, dotfiles, window-manager configs, Cursor, and JetBrains settings from a backup."""


@restore.command("gpg")
@click.option("--from", "source", default=str(DEFAULT_BACKUP_DIR), help="Backup directory.")
def restore_gpg(source):
    """Restore GPG keys (~/.gnupg)."""
    console.print("\n[bold]Restoring GPG keys...[/bold]")
    archive = _pick_backup(Path(source))
    _restore_archive(archive, targets=[".gnupg"])
    _fix_permissions([Path.home() / ".gnupg"])


@restore.command("ssh")
@click.option("--from", "source", default=str(DEFAULT_BACKUP_DIR), help="Backup directory.")
def restore_ssh(source):
    """Restore SSH keys and config (~/.ssh)."""
    console.print("\n[bold]Restoring SSH keys...[/bold]")
    archive = _pick_backup(Path(source))
    _restore_archive(archive, targets=[".ssh"])
    _fix_permissions([Path.home() / ".ssh"])


@restore.command("dotfiles")
@click.option("--from", "source", default=str(DEFAULT_BACKUP_DIR), help="Backup directory.")
def restore_dotfiles(source):
    """Restore dotfiles (.gitconfig, fish config, etc.)."""
    console.print("\n[bold]Restoring dotfiles...[/bold]")
    archive = _pick_backup(Path(source))
    _restore_archive(archive, targets=[".gitconfig", ".config/fish", "etc/hosts"])
    _fix_permissions([
        Path.home() / ".gitconfig",
        Path.home() / ".config" / "fish",
    ])


@restore.command("configs")
@click.option("--from", "source", default=str(DEFAULT_BACKUP_DIR), help="Backup directory.")
def restore_configs(source):
    """Restore i3 and Polybar configs."""
    console.print("\n[bold]Restoring i3 and Polybar configs...[/bold]")
    archive = _pick_backup(Path(source))
    _restore_archive(archive, targets=[".config/i3", ".config/polybar"])
    _fix_permissions([
        Path.home() / ".config" / "i3",
        Path.home() / ".config" / "polybar",
    ])


@restore.command("cursor")
@click.option("--from", "source", default=str(DEFAULT_BACKUP_DIR), help="Backup directory.")
def restore_cursor(source):
    """Restore Cursor skills, rules, transcripts, settings, and extensions.

    Skills/rules/settings are restored regardless of whether Cursor is installed — they're inert
    files until then. Extensions are only reinstalled if the `cursor` CLI is already on $PATH;
    otherwise install Cursor first (`dotstation install`) and re-run this command.
    """
    console.print("\n[bold]Restoring Cursor data...[/bold]")
    archive = _pick_backup(Path(source))
    _restore_archive(archive, targets=[
        ".cursor/skills",
        ".cursor/rules",
        ".cursor/projects",
        ".cursor/argv.json",
        ".cursor/mcp.json",
        ".config/Cursor/User",
        "dotstation-manifest/cursor-extensions.txt",
    ])
    _check_app_readiness(CURSOR_TARGETS)
    _replay_extensions("cursor-extensions.txt", "cursor")


@restore.command("editors")
@click.option("--from", "source", default=str(DEFAULT_BACKUP_DIR), help="Backup directory.")
def restore_editors(source):
    """Restore JetBrains settings."""
    console.print("\n[bold]Restoring editor configs...[/bold]")
    archive = _pick_backup(Path(source))
    _restore_archive(archive, targets=[".config/JetBrains"])
    _check_app_readiness(EDITOR_TARGETS)


@restore.command("manifests")
@click.option("--from", "source", default=str(DEFAULT_BACKUP_DIR), help="Backup directory.")
def restore_manifests(source):
    """Extract package/extension manifests for manual review (never auto-reinstalled)."""
    console.print("\n[bold]Extracting package manifests...[/bold]")
    archive = _pick_backup(Path(source))
    _restore_archive(archive, targets=["dotstation-manifest"])
    console.print(
        f"\n  [dim]Reference files extracted to {Path.home() / 'dotstation-manifest'} — "
        f"review and reinstall manually, e.g. [bold]dnf install $(cat rpm-packages.txt)[/bold].[/dim]"
    )


@restore.command("all")
@click.option("--from", "source", default=str(DEFAULT_BACKUP_DIR), help="Backup directory.")
def restore_all(source):
    """Restore everything from a backup archive."""
    console.print("\n[bold]Restoring everything...[/bold]")
    archive = _pick_backup(Path(source))
    _restore_archive(archive)
    _fix_permissions([
        Path.home() / ".gnupg",
        Path.home() / ".ssh",
        Path.home() / ".gitconfig",
        Path.home() / ".config" / "fish",
        Path.home() / ".config" / "i3",
        Path.home() / ".config" / "polybar",
    ])
    _check_app_readiness(ALL_TARGETS)
    _replay_extensions("cursor-extensions.txt", "cursor")
    console.print(
        f"\n  [dim]Package manifests (if any) were extracted to {Path.home() / 'dotstation-manifest'} "
        f"for manual review.[/dim]"
    )
