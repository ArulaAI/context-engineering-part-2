#!/usr/bin/env bash
# loop-bound.sh — PreToolUse gate: no edits past the repair budget.
#
# The bound already exists in scripts/loop.sh, which refuses to report CONTINUE
# past three attempts. This hook is the *upgrade*: it stops the agent editing at
# all once the loop has said STOP, instead of trusting it to comply.
#
# Script-level bound  = the agent is told to stop.
# Hook-level bound    = the agent cannot proceed.
#
# Same rule, two rungs of the enforcement ladder. Everything still works without
# this hook — that is deliberate, because hook availability is not guaranteed.
#
# Reminder: VS Code ignores "matcher". Filter on tool_name yourself.

set -uo pipefail
INPUT="$(cat)"
STATE=".workflow/state.json"

allow() { printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}\n'; exit 0; }
deny()  { printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$1"; exit 0; }

TOOL="$(printf '%s' "$INPUT" | python3 -c "import json,sys;print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)"

# Only gate mutating tools.
case "$TOOL" in
  *[Ee]dit*|*[Ww]rite*|*apply_patch*|*create_file*|*insert_edit*|*replace_string*) ;;
  *) allow ;;
esac

[ -f "$STATE" ] || allow

STATUS="$(python3 -c "
import json,sys
try: print(json.load(open('$STATE')).get('status',''))
except Exception: print('')
" 2>/dev/null)"

case "$STATUS" in
  STOP_THRASHING)
    deny '"The repair loop detected thrashing: the verifier returned an identical verdict twice, so edits are landing but the outcome is not moving. Another attempt spends tokens to learn nothing. Escalate to a human with the last verdict, or run ./scripts/loop.sh reset to start a new bounded loop deliberately."'
    ;;
  STOP_BUDGET)
    deny '"The repair loop budget is exhausted (3 attempts). Steps 1-3 deliver nearly all the available gain; step 4+ adds under 2%. Escalate to a human, or run ./scripts/loop.sh reset if you are starting genuinely new work."'
    ;;
esac

allow
