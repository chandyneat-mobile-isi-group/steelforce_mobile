"""Facts about the app under test, recorded with every execution."""

import re
import subprocess
from pathlib import Path


def app_version(flutter_dir: Path) -> str:
    pubspec = flutter_dir / "pubspec.yaml"
    if not pubspec.is_file():
        return ""
    match = re.search(r"^version:\s*(\S+)", pubspec.read_text(encoding="utf-8"), re.MULTILINE)
    return match.group(1) if match else ""


def _git(repo_dir: Path, *args: str) -> str:
    try:
        completed = subprocess.run(
            ["git", *args],
            cwd=repo_dir,
            capture_output=True,
            text=True,
            timeout=10,
            check=True,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return completed.stdout.strip()


def git_revision(repo_dir: Path) -> str:
    """``uat @ 644056f`` — plus ``(modified)`` when the working tree has changes."""
    branch = _git(repo_dir, "rev-parse", "--abbrev-ref", "HEAD")
    commit = _git(repo_dir, "rev-parse", "--short", "HEAD")
    dirty = " (modified)" if _git(repo_dir, "status", "--porcelain", "--untracked-files=no") else ""
    return f"{branch} @ {commit}{dirty}" if commit else ""
