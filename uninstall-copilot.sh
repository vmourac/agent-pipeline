#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/.copilot/agents"
TARGET_DIR="$HOME/.copilot/agents"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

removed=0
skipped=0

for src in "$SOURCE_DIR"/*.agent.md; do
  [[ -f "$src" ]] || continue
  filename="$(basename "$src")"
  dest="$TARGET_DIR/$filename"

  if [[ -f "$dest" ]]; then
    rm "$dest"
    echo "  removed   $filename"
    removed=$((removed + 1))
  else
    echo "  skipped   $filename (not installed)"
    skipped=$((skipped + 1))
  fi
done

echo ""
echo "$removed removed, $skipped skipped — agents uninstalled from VS Code Copilot."
