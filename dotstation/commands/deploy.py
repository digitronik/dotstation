import shutil
import subprocess
from pathlib import Path

import click
from rich.console import Console

from dotstation.constants import (
    get_repo_i3_dir,
    get_repo_polybar_dir,
    get_repo_dunst_dir,
    get_repo_rofi_dir,
    get_repo_textforge_dir,
    get_repo_fonts_dir,
    CONFIG_DIR,
)

console = Console()


def _backup_existing(path: Path) -> None:
    if path.exists():
        bak = Path(str(path) + ".bak")
        if bak.exists():
            shutil.rmtree(bak) if bak.is_dir() else bak.unlink()
        shutil.move(str(path), str(bak))
        console.print(f"  [dim]Backed up existing {path.name} → {bak.name}[/dim]")


def _copy_and_chmod(src: Path, dst: Path) -> None:
    if dst.exists():
        shutil.rmtree(dst) if dst.is_dir() else dst.unlink()
    shutil.copytree(src, dst) if src.is_dir() else shutil.copy2(src, dst)
    # Make all .sh files executable
    for sh in dst.glob("*.sh") if dst.is_dir() else []:
        sh.chmod(sh.stat().st_mode | 0o111)


@click.group("deploy")
def deploy():
    """Deploy i3, Polybar, Dunst, and Rofi configs to ~/.config."""


@deploy.command("i3")
@click.option("--backup/--no-backup", default=True, help="Backup existing config before deploying.")
def deploy_i3(backup):
    """Deploy i3 config to ~/.config/i3."""
    console.print("\n[bold]Deploying i3 config...[/bold]")
    dst = CONFIG_DIR / "i3"
    if backup:
        _backup_existing(dst)
    _copy_and_chmod(get_repo_i3_dir(), dst)
    for sh in dst.glob("*.sh"):
        sh.chmod(sh.stat().st_mode | 0o111)
    console.print(f"  [green][OK][/green]    i3 config deployed to {dst}")


@deploy.command("polybar")
@click.option("--backup/--no-backup", default=True, help="Backup existing config before deploying.")
def deploy_polybar(backup):
    """Deploy Polybar config to ~/.config/polybar."""
    console.print("\n[bold]Deploying Polybar config...[/bold]")
    dst = CONFIG_DIR / "polybar"
    if backup:
        _backup_existing(dst)
    _copy_and_chmod(get_repo_polybar_dir(), dst)
    for sh in dst.glob("*.sh"):
        sh.chmod(sh.stat().st_mode | 0o111)
    console.print(f"  [green][OK][/green]    Polybar config deployed to {dst}")


@deploy.command("dunst")
@click.option("--backup/--no-backup", default=True, help="Backup existing config before deploying.")
def deploy_dunst(backup):
    """Deploy Dunst config to ~/.config/dunst."""
    console.print("\n[bold]Deploying Dunst config...[/bold]")
    dst = CONFIG_DIR / "dunst"
    if backup:
        _backup_existing(dst)
    _copy_and_chmod(get_repo_dunst_dir(), dst)
    console.print(f"  [green][OK][/green]    Dunst config deployed to {dst}")
    subprocess.run(["systemctl", "--user", "restart", "dunst"], capture_output=True)


@deploy.command("rofi")
@click.option("--backup/--no-backup", default=True, help="Backup existing config before deploying.")
def deploy_rofi(backup):
    """Deploy Rofi theme to ~/.config/rofi."""
    console.print("\n[bold]Deploying Rofi config...[/bold]")
    dst = CONFIG_DIR / "rofi"
    if backup:
        _backup_existing(dst)
    _copy_and_chmod(get_repo_rofi_dir(), dst)
    console.print(f"  [green][OK][/green]    Rofi config deployed to {dst}")


@deploy.command("textforge")
@click.option("--backup/--no-backup", default=True, help="Backup existing config before deploying.")
def deploy_textforge(backup):
    """Deploy TextForge scripts to ~/.config/textforge."""
    console.print("\n[bold]Deploying TextForge...[/bold]")
    dst = CONFIG_DIR / "textforge"
    if backup:
        _backup_existing(dst)
    _copy_and_chmod(get_repo_textforge_dir(), dst)
    for sh in dst.glob("*.sh"):
        sh.chmod(sh.stat().st_mode | 0o111)
    console.print(f"  [green][OK][/green]    TextForge deployed to {dst}")


@deploy.command("fonts")
def deploy_fonts():
    """Install bundled fonts to ~/.local/share/fonts."""
    console.print("\n[bold]Installing fonts...[/bold]")
    fonts_dir = Path.home() / ".local" / "share" / "fonts"
    for src in get_repo_fonts_dir().iterdir():
        if src.is_dir():
            dst = fonts_dir / src.name
            if dst.exists():
                console.print(f"  [yellow][SKIP][/yellow]  Font {src.name} already installed")
                continue
            shutil.copytree(src, dst)
            console.print(f"  [green][OK][/green]    Installed font: {src.name}")
    subprocess.run(["fc-cache", "-fv"], capture_output=True)
    console.print("  [dim]Font cache rebuilt.[/dim]")


@deploy.command("all")
@click.option("--backup/--no-backup", default=True, help="Backup existing configs before deploying.")
@click.pass_context
def deploy_all(ctx, backup):
    """Deploy all configs and fonts."""
    ctx.invoke(deploy_i3, backup=backup)
    ctx.invoke(deploy_polybar, backup=backup)
    ctx.invoke(deploy_dunst, backup=backup)
    ctx.invoke(deploy_rofi, backup=backup)
    ctx.invoke(deploy_textforge, backup=backup)
    ctx.invoke(deploy_fonts)
    console.print("\n  [bold green]All configs deployed.[/bold green]")
    console.print("  Reload i3 with [bold]Mod+Shift+c[/bold]")
