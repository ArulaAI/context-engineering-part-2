#!/usr/bin/env bash
# quiet-build.sh — PreToolUse gate: the verbose build is not available.
#
# READ THIS FIRST — the mistake everyone makes:
#   VS Code IGNORES the "matcher" field in hooks.json. This script is invoked on
#   EVERY tool call, not just terminal ones. You must filter on tool_name yourself,
#   from stdin. A hook copied from a Claude Code example will appear to work and
#   will silently gate the wrong things.
#
# What this gate does:
#   It DENYs. PreToolUse hooks can also rewrite tool input (via updatedInput),
#   but this lab deliberately denies rather than rewrites — a denial is auditable
#   and makes the participant reach for the quiet recipe themselves, which is the
#   lesson. That gap between "requested" and "enforced" is the teaching point.
#
# No Python: the hook payload's shape is fixed and known (a flat "tool_name"
# string, a "command" or "commandLine" string one level down in "tool_input"),
# so a plain grep/sed extraction is enough — a full JSON parser would be solving
# a harder problem than this input actually poses.

set -uo pipefail
INPUT="$(cat)"

allow() { printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}\n'; exit 0; }
deny()  { printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$1"; exit 0; }

field() {
  printf '%s' "$INPUT" \
    | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 \
    | sed -E "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"([^\"]*)\"/\\1/"
}

TOOL="$(field tool_name)"

# --- the filter VS Code will not do for you --------------------------------
case "$TOOL" in
  *[Tt]erminal*|*[Bb]ash*|*run_in_terminal*|*runCommands*) ;;
  *) allow ;;
esac

CMD="$(field command)"
[ -n "$CMD" ] || CMD="$(field commandLine)"
[ -n "$CMD" ] || allow

# Allow the sanctioned recipes.
case "$CMD" in
  *scripts/verify.sh*|*scripts/verify-change.sh*|*scripts/loop.sh*|*scripts/mutation.sh*|*scripts/digest.sh*|*scripts/authority.sh*|*scripts/context-map.sh*|*scripts/context-run.sh*|*scripts/context-for.sh*) allow ;;
esac

# Deny raw Maven test/compile invocations that bypass the verifier.
if printf '%s' "$CMD" | grep -Eq '(^|[^-[:alnum:]])mvn([[:space:]]|$)' \
   && printf '%s' "$CMD" | grep -Eq '(test|compile|verify|install)'; then
  deny '"Raw Maven output is noisy and re-read on every later turn. Use ./scripts/verify-change.sh (a ✓/✗ checklist, exit code is the signal). If a repair loop is running, use VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check so the attempt counts against the budget."'
fi

allow
