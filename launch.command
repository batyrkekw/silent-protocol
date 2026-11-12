#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$PROJECT_DIR/tools/find_godot.sh"
if ! GAME_GODOT="$(find_godot)"; then
  printf '%s\n' 'Godot 4.5+ не найден. Установите Godot или задайте GODOT_BIN.'
  exit 1
fi
# A fresh checkout needs the script-class and asset import cache.
if [ ! -f "$PROJECT_DIR/.godot/global_script_class_cache.cfg" ]; then
  "$GAME_GODOT" --headless --path "$PROJECT_DIR" --editor --quit
fi
exec "$GAME_GODOT" --path "$PROJECT_DIR" "$@"
