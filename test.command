#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$PROJECT_DIR/tools/find_godot.sh"
if ! GAME_GODOT="$(find_godot)"; then
  printf '%s\n' 'Godot 4.5+ не найден. Задайте GODOT_BIN.'
  exit 1
fi
"$GAME_GODOT" --headless --path "$PROJECT_DIR" --editor --quit
"$GAME_GODOT" --headless --path "$PROJECT_DIR" --script res://tests/test_spec.gd
"$GAME_GODOT" --headless --path "$PROJECT_DIR" --script res://tests/test_regressions.gd
"$GAME_GODOT" --headless --path "$PROJECT_DIR" --script res://tests/test_ui.gd
"$GAME_GODOT" --headless --path "$PROJECT_DIR" --script res://tests/test_block_editor.gd
"$GAME_GODOT" --headless --path "$PROJECT_DIR" --script res://tests/test_intro.gd
"$GAME_GODOT" --headless --path "$PROJECT_DIR" --script res://tests/test_improvement.gd

"$GAME_GODOT" --headless --path "$PROJECT_DIR" --script res://tests/test_localization.gd

"$GAME_GODOT" --headless --path "$PROJECT_DIR" --script res://tests/test_recovery.gd

"$GAME_GODOT" --headless --path "$PROJECT_DIR" --script res://tests/test_zero_minute_preflight.gd
"$GAME_GODOT" --headless --path "$PROJECT_DIR" --script res://tests/audit_zero_crossing.gd
"$GAME_GODOT" --headless --path "$PROJECT_DIR" --script res://tests/test_zero_minute.gd
"$GAME_GODOT" --headless --path "$PROJECT_DIR" --script res://tests/test_zero_ui.gd

"$GAME_GODOT" --headless --path "$PROJECT_DIR" --script res://tests/test_museum.gd

"$GAME_GODOT" --headless --path "$PROJECT_DIR" --script res://tests/test_submission.gd
