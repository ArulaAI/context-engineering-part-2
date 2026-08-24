#!/usr/bin/env bash
# loop.sh — the repair loop's bookkeeper and gate.
#
# A shell script cannot drive Copilot, so this does not run the loop. The agent
# runs the loop; this decides whether the agent is allowed to keep going.
#
# That distinction is the whole point. "Try at most three times" written in an
# instructions file is a REQUEST — the weakest rung of the enforcement ladder.
# An attempt counter on disk, checked by a script, is a BOUND.
#
#   scripts/loop.sh reset    start a new loop, clear state
#   scripts/loop.sh check    run the verifier, record the attempt, decide
#   scripts/loop.sh status   print state without running anything
#
# exit codes from `check`:
#   0  DONE      green, stop because you succeeded
#   1  CONTINUE  failed, attempts remain
#   4  STOP      thrashing — the same verdict twice, the diff is moving but
#                the outcome is not
#   5  STOP      budget exhausted
#
# Why bound at three: across three independent studies, repair steps 1-3 deliver
# nearly all the available gain; step 4 and beyond adds under 2%. The curves are
# concave, so over-running wastes spend without degrading quality — which makes
# the bound an economic decision, not a safety one.
#
# VERIFY_CMD (env var, default scripts/verify.sh): which verifier this loop is
# bounding. Stage 5 of this lab overrides it —
#   VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
# — so the same attempt-budget/thrashing bookkeeper governs a task-specific
# verifier without duplicating any of this file's logic.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

STATE_DIR=".workflow"
STATE="$STATE_DIR/state.json"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
VERIFY_CMD="${VERIFY_CMD:-scripts/verify.sh}"
mkdir -p "$STATE_DIR"

case "${1:-check}" in

  reset)
    python3 - "$STATE" "$MAX_ATTEMPTS" <<'PY'
import json, sys
json.dump({"attempts": 0, "max_attempts": int(sys.argv[2]),
           "verdict_hashes": [], "last_verdict": "", "status": "READY"},
          open(sys.argv[1], "w"), indent=2)
PY
    echo "loop reset — budget ${MAX_ATTEMPTS}"
    exit 0
    ;;

  status)
    [ -f "$STATE" ] || { echo "no loop in progress"; exit 0; }
    python3 -c "import json,sys;s=json.load(open(sys.argv[1]));print(f\"attempt {s['attempts']}/{s['max_attempts']}  status={s['status']}\")" "$STATE"
    exit 0
    ;;

  check) ;;
  *) echo "usage: loop.sh [reset|check|status]" >&2; exit 3 ;;
esac

[ -f "$STATE" ] || bash "$0" reset >/dev/null

VERDICT="$(bash "$VERIFY_CMD" 2>&1)"; RC=$?
HASH="$(printf '%s' "$VERDICT" | shasum | cut -c1-12)"

python3 - "$STATE" "$RC" "$HASH" "$VERDICT" <<'PY'
import json, sys
state_path, rc, h, verdict = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
s = json.load(open(state_path))

if rc == 0:
    s.update(status="DONE", last_verdict=verdict)
    json.dump(s, open(state_path, "w"), indent=2)
    print(verdict); print("DONE — green.")
    sys.exit(0)

s["attempts"] += 1
repeat = h in s["verdict_hashes"]
s["verdict_hashes"].append(h)
s["last_verdict"] = verdict

# Thrashing: the verifier said exactly this before. Edits are landing, the
# outcome is not moving. More attempts will not help; a human must look.
if repeat:
    s["status"] = "STOP_THRASHING"
    json.dump(s, open(state_path, "w"), indent=2)
    print(verdict)
    print(f"STOP — thrashing. Identical verdict at attempt {s['attempts']} (hash {h}).")
    print("The diff is moving; the outcome is not. Escalate, do not retry.")
    sys.exit(4)

if s["attempts"] >= s["max_attempts"]:
    s["status"] = "STOP_BUDGET"
    json.dump(s, open(state_path, "w"), indent=2)
    print(verdict)
    print(f"STOP — budget exhausted ({s['attempts']}/{s['max_attempts']}). Escalate to a human.")
    sys.exit(5)

s["status"] = "CONTINUE"
json.dump(s, open(state_path, "w"), indent=2)
print(verdict)
print(f"CONTINUE — attempt {s['attempts']}/{s['max_attempts']} used.")
sys.exit(1)
PY
