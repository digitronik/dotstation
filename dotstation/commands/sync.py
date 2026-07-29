import subprocess
from pathlib import Path

import click
from rich.console import Console

from dotstation.constants import (
    get_repo_i3_dir,
    get_repo_polybar_dir,
    get_repo_dunst_dir,
    get_repo_rofi_dir,
    get_repo_root,
    CONFIG_DIR,
)

console = Console()


def _sync_dir(src: Path, dst: Path, label: str) -> bool:
    """Copy src → dst, preserving all files. Returns True on success."""
    import shutil
    if not src.exists():
        console.print(f"  [yellow][SKIP][/yellow]  {label} — source not found ({src})")
        return False

    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)
    console.print(f"  [green][OK][/green]    {label}  ({src} → {dst})")
    return True


@click.group("sync")
def sync():
    """Sync live ~/.config changes back into the repository."""


@sync.command("i3")
def sync_i3():
    """Sync ~/.config/i3 → repo i3/."""
    console.print("\n[bold]Syncing i3 config...[/bold]")
    _sync_dir(CONFIG_DIR / "i3", get_repo_i3_dir(), "i3")
    console.print("\n  [dim]Run [bold]git add -A && git commit[/bold] to save the changes.[/dim]")


@sync.command("polybar")
def sync_polybar():
    """Sync ~/.config/polybar → repo polybar/."""
    console.print("\n[bold]Syncing Polybar config...[/bold]")
    _sync_dir(CONFIG_DIR / "polybar", get_repo_polybar_dir(), "polybar")
    console.print("\n  [dim]Run [bold]git add -A && git commit[/bold] to save the changes.[/dim]")


@sync.command("dunst")
def sync_dunst():
    """Sync ~/.config/dunst → repo dunst/."""
    console.print("\n[bold]Syncing Dunst config...[/bold]")
    _sync_dir(CONFIG_DIR / "dunst", get_repo_dunst_dir(), "dunst")
    console.print("\n  [dim]Run [bold]git add -A && git commit[/bold] to save the changes.[/dim]")


@sync.command("rofi")
def sync_rofi():
    """Sync ~/.config/rofi → repo rofi/."""
    console.print("\n[bold]Syncing Rofi config...[/bold]")
    _sync_dir(CONFIG_DIR / "rofi", get_repo_rofi_dir(), "rofi")
    console.print("\n  [dim]Run [bold]git add -A && git commit[/bold] to save the changes.[/dim]")


@sync.command("all")
def sync_all():
    """Sync all live configs back into the repository."""
    console.print("\n[bold]Syncing all configs to repo...[/bold]")

    _sync_dir(CONFIG_DIR / "i3",      get_repo_i3_dir(),      "i3")
    _sync_dir(CONFIG_DIR / "polybar", get_repo_polybar_dir(), "polybar")
    _sync_dir(CONFIG_DIR / "dunst",   get_repo_dunst_dir(),   "dunst")
    _sync_dir(CONFIG_DIR / "rofi",    get_repo_rofi_dir(),    "rofi")

    # Show git diff summary
    console.print("\n[bold]Git diff summary:[/bold]")
    result = subprocess.run(
        ["git", "diff", "--stat"],
        cwd=get_repo_root(),
        capture_output=True, text=True
    )
    if result.stdout.strip():
        console.print(f"[dim]{result.stdout.strip()}[/dim]")
    else:
        console.print("  [green]No changes — repo already up to date.[/green]")

    console.print("\n  [dim]Run [bold]git add -A && git commit[/bold] to save the changes.[/dim]")
