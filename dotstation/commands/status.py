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
    "pavucontrol", "i3lock", "blueman-manager", "dunst", "xclip",
    "xdotool", "rofi", "notify-send", "jq", "git", "fish", "vim",
    "docker", "uv", "cursor", "ollama",
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
    configs = {
        "i3": CONFIG_DIR / "i3", "polybar": CONFIG_DIR / "polybar",
        "dunst": CONFIG_DIR / "dunst", "rofi": CONFIG_DIR / "rofi",
        "textforge": CONFIG_DIR / "textforge",
    }
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

    # --- Battery charge threshold -----------------------------------------------
    console.print("\n[bold]Battery Charge Threshold[/bold]")
    thresh_script = Path("/usr/local/bin/battery-threshold.sh")
    udev_rule = Path("/etc/udev/rules.d/99-battery-threshold.rules")
    sudoers_file = Path("/etc/sudoers.d/battery-threshold")
    script_ok, udev_ok = thresh_script.exists(), udev_rule.exists()
    # /etc/sudoers.d is 750 root:root — a regular user can't stat inside it, so
    # Path.exists() always reports False here. Test the actual behavior instead:
    # a working NOPASSWD rule lets `sudo -n` succeed without prompting.
    sudoers_ok = False
    if script_ok:
        try:
            result = subprocess.run(
                ["sudo", "-n", str(thresh_script), "status"],
                capture_output=True, text=True, timeout=3,
            )
            sudoers_ok = result.returncode == 0
        except Exception:
            sudoers_ok = False
    table = Table(show_header=False, box=None, padding=(0, 2))
    table.add_row("[green]✓[/green]" if script_ok else "[red]✗[/red]", "[bold]battery-threshold.sh[/bold]", str(thresh_script))
    table.add_row("[green]✓[/green]" if udev_ok else "[red]✗[/red]", "[bold]udev rule[/bold]", str(udev_rule))
    table.add_row("[green]✓[/green]" if sudoers_ok else "[red]✗[/red]", "[bold]sudoers rule (passwordless sudo)[/bold]", str(sudoers_file))
    console.print(table)
    if script_ok:
        try:
            result = subprocess.run([str(thresh_script), "status"], capture_output=True, text=True, timeout=2)
            if result.returncode == 0 and result.stdout.strip():
                console.print(f"  [dim]{result.stdout.strip()}[/dim]")
        except Exception:
            pass
    if not (script_ok and udev_ok and sudoers_ok):
        console.print("  [yellow]Run[/yellow] [bold]bash install.sh[/bold] [yellow]to finish setup.[/yellow]")
    console.print()
