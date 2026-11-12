"""Compatibility entry point: package both current desktop builds."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name("package_release.py")),run_name="__main__")
