#!/usr/bin/env bash
# Sourced by launch.command and test.command. Never changes the caller's cwd.
find_godot() {
  local candidate
  if [ -n "${GODOT_BIN:-}" ] && [ -x "$GODOT_BIN" ]; then
    printf '%s\n' "$GODOT_BIN"
    return 0
  fi
  for candidate in \
    "$PROJECT_DIR/.tools/Godot.app/Contents/MacOS/Godot" \
    "/Applications/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Applications/Godot.app/Contents/MacOS/Godot"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  command -v godot || command -v godot4
}
