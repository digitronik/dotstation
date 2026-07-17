import subprocess
from pathlib import Path

import click
from rich.console import Console
from rich.table import Table

from dotstation.constants import (
    BACKUP_TARGETS,
    CURSOR_TARGETS,
    EDITOR_TARGETS,
    DEFAULT_BACKUP_DIR,
    CONFIG_DIR,
    target_exists,
)
from dotstation.utils import path_exists, is_command_available

console = Console()

REQUIRED_COMMANDS = [
    "i3", "polybar", "tilix", "feh", "arandr", "brightnessctl",
    "pavucontrol", "i3lock", "blueman-applet", "dunst", "xclip",
    "rofi", "zenity", "git", "fish", "vim", "docker", "uv",
    "cursor",
]


@click.command("status")
def status():
    """Show backup status, installed packages, and deployed configs."""

    # --- Backup status --------------------------------------------------------
    console.print("\n[bold]Backup Status[/bold]")
    backups = sorted(DEFAULT_BACKUP_DIR.glob("dotstation-backup-*"), reverse=True) if DEFAULT_BACKUP_DIR.exists() else []
    if backups:
        console.print(f"  [green]Found {len(backups)} backup(s)[/green] in {DEFAULT_BACKUP_DIR}")
        console.print(f"  Latest: [bold]{backups[0].name}[/bold]")
    else:
        console.print(f"  [yellow]No backups found[/yellow] in {DEFAULT_BACKUP_DIR}")
        console.print("  Run [bold]dotstation backup all[/bold] to create one.")

    # --- Backup targets -------------------------------------------------------
    console.print("\n[bold]Backup Targets[/bold]")
    table = Table(show_header=False, box=None, padding=(0, 2))
    for label, target in BACKUP_TARGETS.items():
        status_str = "[green]✓[/green]" if target_exists(target) else "[red]✗[/red]"
        table.add_row(status_str, f"[bold]{label}[/bold]", str(target.path))
    console.print(table)

    # --- Additional backup targets (Cursor, JetBrains) -------------------------
    console.print("\n[bold]Additional Backup Targets[/bold]  [dim](cursor/editors)[/dim]")
    table = Table(show_header=False, box=None, padding=(0, 2))
    extra_targets = {**CURSOR_TARGETS, **EDITOR_TARGETS}
    for label, target in extra_targets.items():
        exists = target_exists(target)
        status_str = "[green]✓[/green]" if exists else "[red]✗[/red]"
        note = ""
        if exists and target.requires_cmd and not is_command_available(target.requires_cmd):
            note = f"  [yellow](needs {target.requires_cmd} to be useful)[/yellow]"
        table.add_row(status_str, f"[bold]{label}[/bold]", f"{target.path}{note}")
    console.print(table)

    # --- Deployed configs -----------------------------------------------------
    console.print("\n[bold]Deployed Configs[/bold]")
    configs = {"i3": CONFIG_DIR / "i3", "polybar": CONFIG_DIR / "polybar"}
    for name, path in configs.items():
        status_str = "[green]✓[/green]" if path_exists(path) else "[red]✗[/red]"
        console.print(f"  {status_str}  [bold]{name}[/bold]  ({path})")

    # --- Installed commands ---------------------------------------------------
    console.print("\n[bold]Key Commands[/bold]")
    table = Table(show_header=False, box=None, padding=(0, 2))
    for cmd in REQUIRED_COMMANDS:
        avail = is_command_available(cmd)
        status_str = "[green]✓[/green]" if avail else "[red]✗ not found[/red]"
        table.add_row(status_str, f"[bold]{cmd}[/bold]")
    console.print(table)
    console.print()
