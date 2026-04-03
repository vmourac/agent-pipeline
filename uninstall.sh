#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/.claude/commands"
TARGET_DIR="$HOME/.claude/commands"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

removed=0
skipped=0

for src in "$SOURCE_DIR"/*.md; do
  [[ -f "$src" ]] || continue
  filename="$(basename "$src")"
  dest="$TARGET_DIR/$filename"

  if [[ -f "$dest" ]]; then
    rm "$dest"
    echo "  removed  $filename"
    ((removed++))
  else
    echo "  skipped  $filename (not installed)"
    ((skipped++))
  fi
done

echo ""
echo "$removed removed, $skipped skipped — commands uninstalled from Claude Code."
