#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/.claude/commands"
TARGET_DIR="$HOME/.claude/commands"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

installed=0
updated=0

for src in "$SOURCE_DIR"/*.md; do
  [[ -f "$src" ]] || continue
  filename="$(basename "$src")"
  dest="$TARGET_DIR/$filename"

  if [[ -f "$dest" ]]; then
    if ! diff -q "$src" "$dest" > /dev/null 2>&1; then
      cp "$src" "$dest"
      echo "  updated  $filename"
      ((updated++))
    else
      echo "  unchanged $filename"
    fi
  else
    cp "$src" "$dest"
    echo "  installed $filename"
    ((installed++))
  fi
done

echo ""
echo "$installed installed, $updated updated — commands available globally in Claude Code."
