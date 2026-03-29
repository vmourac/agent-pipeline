#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/.copilot/agents"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

# User-level agents directory — ~/.copilot/agents is the correct global location
# per VS Code documentation: https://code.visualstudio.com/docs/copilot/customization/custom-agents
TARGET_DIR="$HOME/.copilot/agents"

mkdir -p "$TARGET_DIR"

installed=0
updated=0
unchanged=0

for src in "$SOURCE_DIR"/*.agent.md; do
  [[ -f "$src" ]] || continue
  filename="$(basename "$src")"
  dest="$TARGET_DIR/$filename"

  if [[ -f "$dest" ]]; then
    if ! diff -q "$src" "$dest" > /dev/null 2>&1; then
      cp "$src" "$dest"
      echo "  updated   $filename"
      updated=$((updated + 1))
    else
      echo "  unchanged $filename"
      unchanged=$((unchanged + 1))
    fi
  else
    cp "$src" "$dest"
    echo "  installed $filename"
    installed=$((installed + 1))
  fi
done

echo ""
echo "$installed installed, $updated updated, $unchanged unchanged"
echo "Agents available in VS Code Copilot: Pipeline, PRD Agent, TechSpec Agent, Tasks Agent, Task Implementation Agent, Review Agent, QA Agent, Bugfix Agent"
echo "Target directory: $TARGET_DIR"
echo ""
echo "To use:"
echo "  1. Open VS Code in your target project"
echo "  2. Open GitHub Copilot Chat (Ctrl+Alt+I / Cmd+Alt+I)"
echo "  3. Click the agent selector (top of chat panel) → select 'Pipeline'"
echo "  4. Type your feature request: feature-name: description"
