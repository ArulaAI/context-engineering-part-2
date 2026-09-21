#!/usr/bin/env bash
#
# stage0-baseline.sh — build a genuinely cold workspace for Stage 0.
#
# Why this exists: Copilot loads workspace instructions automatically. Opening THIS
# repository means AGENTS.md, .github/ (agents, skills, hooks) and .vscode/ settings are in
# play before you type a word, and a prompt saying "don't use .github/" cannot unload them.
# A baseline measured inside this repo is not a baseline.
#
# So this exports only the engineering evidence — source, config, the ticket, the ADRs,
# the build file — into a sibling folder with none of the lab's machinery, and then checks
# that nothing that auto-loads came along.
#
# usage: scripts/stage0-baseline.sh [target-dir]      (default: ../meridian-stage0-baseline)
# exit 0 ready · 2 the target exists and is not a previous baseline · 3 contamination found

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

TARGET="${1:-../meridian-stage0-baseline}"
MARKER=".stage0-baseline"

if [ -e "$TARGET" ] && [ ! -f "$TARGET/$MARKER" ]; then
  echo "stage0-baseline: $TARGET exists and was not created by this script — refusing to" >&2
  echo "overwrite it. Pass a different directory as the first argument." >&2
  exit 2
fi
rm -rf "$TARGET"
mkdir -p "$TARGET"

# Copy from the working tree (not HEAD), so the baseline matches the files in front of you.
tar -cf - pom.xml src config docs/JIRA_TICKETS.md docs/adr \
  | tar -x -C "$TARGET" || { echo "stage0-baseline: export failed" >&2; exit 3; }
touch "$TARGET/$MARKER"

# Anything that Copilot would load automatically must be absent.
contaminated=""
for p in AGENTS.md CLAUDE.md .github .vscode .context .workflow scripts fixtures \
         LAB_ACTION_GUIDE.md docs/facilitator; do
  [ -e "$TARGET/$p" ] && contaminated="$contaminated $p"
done
if [ -n "$contaminated" ]; then
  echo "stage0-baseline: contamination in $TARGET:$contaminated" >&2
  exit 3
fi

ABS="$(cd "$TARGET" && pwd)"
echo "Stage 0 baseline ready: $ABS"
echo ""
echo "Contains:  pom.xml  src/  config/  docs/JIRA_TICKETS.md  docs/adr/"
echo "Absent:    AGENTS.md  .github/  .vscode/  .context/  .workflow/  scripts/  the lab guide"
echo ""
echo "Open it in a NEW VS Code window:   code \"$ABS\""
