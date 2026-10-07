"""Product version shared by source and frozen desktop entry points."""
from pathlib import Path
import sys


def _find_version() -> str:
    candidates = [
        Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent)) / "VERSION",
        Path(__file__).resolve().parent / "VERSION",
        Path.cwd() / "VERSION",
    ]
    if getattr(sys, "frozen", False):
        # On macOS PyInstaller .app bundles, resources can be under Contents/Resources
        executable_dir = Path(sys.executable).resolve().parent
        candidates.extend([
            executable_dir / "VERSION",
            executable_dir.parent / "Resources" / "VERSION",
            executable_dir.parent / "MacOS" / "VERSION",
        ])
    for candidate in candidates:
        if candidate.is_file():
            try:
                return candidate.read_text(encoding="utf-8").strip()
            except OSError:
                pass
    return "0.0.7"

APP_VERSION = _find_version()
