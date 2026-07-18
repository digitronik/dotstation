import subprocess
from pathlib import Path
from rich.console import Console

console = Console()


def run(cmd: list[str], check: bool = True, silent: bool = False) -> subprocess.CompletedProcess:
    """Run a shell command, optionally silencing output."""
    result = subprocess.run(cmd, capture_output=silent, text=True)
    if check and result.returncode != 0:
        err = result.stderr.strip() if result.stderr else ""
        console.print(f"  [red][FAIL][/red]  {' '.join(cmd)}" + (f"\n  {err}" if err else ""))
    return result


def path_exists(p: Path) -> bool:
    return p.exists()


def ensure_dir(p: Path) -> None:
    p.mkdir(parents=True, exist_ok=True)


def is_command_available(cmd: str) -> bool:
    return subprocess.run(["which", cmd], capture_output=True).returncode == 0


def capture_output(cmd: list[str], timeout: int = 15) -> str:
    """Run a command and return its stdout, or "" if it fails/is missing/times out."""
    if not is_command_available(cmd[0]):
        return ""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def list_extensions(editor_cmd: str) -> str:
    """Return newline-separated extension IDs for a VS Code-family editor (Cursor, Code)."""
    return capture_output([editor_cmd, "--list-extensions"])
