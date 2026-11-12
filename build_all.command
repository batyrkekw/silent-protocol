#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$PROJECT_DIR/tools/find_godot.sh"
GAME_GODOT="$(find_godot)"
"$GAME_GODOT" --headless --path "$PROJECT_DIR" --editor --quit
"$GAME_GODOT" --headless --path "$PROJECT_DIR" --export-release 'Windows Desktop' "$PROJECT_DIR/../SilentProtocol.exe"
"$GAME_GODOT" --headless --path "$PROJECT_DIR" --export-release macOS "$PROJECT_DIR/../Silent Protocol.app"
python3 "$PROJECT_DIR/tools/finalize_macos.py"
python3 "$PROJECT_DIR/tools/package_release.py"
