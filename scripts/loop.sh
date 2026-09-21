#!/usr/bin/env bash
# loop.sh — the repair loop's bookkeeper and gate.
#
# A shell script cannot drive Copilot, so this does not run the loop. Whoever is repairing
# (you, or an agent) runs the loop; this decides whether another attempt is worth making.
#
# "Try at most three times" written in an instructions file is a REQUEST. An attempt counter
# on disk, checked by a script, is a BOUND.
#
# Each check records two fingerprints and classifies what actually happened:
#   code hash       everything under src/ that differs from the lab's starting commit
#   failure hash    the verifier's output
#
#   same code  + any verdict          REDUNDANT RETRY    nothing changed, so nothing can change.
#                                                        Not counted against the budget.
#   new code   + same failure as the  UNSUCCESSFUL       the code moved, the outcome did not.
#                previous attempt     REPAIR
#   ...twice in a row                 THRASHING          stop: more edits are not converging.
#   attempts reach the budget         BUDGET EXHAUSTED   stop and escalate.
#
#   scripts/loop.sh reset    start a new loop, clear state
#   scripts/loop.sh check    run the verifier, classify, decide
#   scripts/loop.sh status   print state without running anything
#
# exit codes from `check`:
#   0  DONE              verifier passed
#   1  CONTINUE          failed, attempts remain (a new failure, or a first unsuccessful repair)
#   4  STOP_THRASHING    the same failure survived two consecutive code changes
#   5  STOP_BUDGET       attempt budget exhausted
#   6  REDUNDANT         no code change since the last attempt — make a change, or stop
#
# VERIFY_CMD selects the verifier (default scripts/verify.sh); Stage 5 uses
#   VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
# MAX_ATTEMPTS sets the budget (default 3). The number is a judgment made before you start,
# not after you are tired — pick it deliberately.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

STATE_DIR=".workflow"
STATE="$STATE_DIR/state.json"
HISTORY="$STATE_DIR/attempts.tsv"
LAST_VERDICT="$STATE_DIR/last-verdict.txt"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
VERIFY_CMD="${VERIFY_CMD:-scripts/verify.sh}"
mkdir -p "$STATE_DIR"

hash12() {
  if command -v shasum >/dev/null 2>&1; then shasum | cut -c1-12
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -c1-12
  else cksum | tr -d ' \n' | cut -c1-12; fi
}

write_state() { # attempts max status
  printf '{\n  "attempts": %s,\n  "max_attempts": %s,\n  "status": "%s"\n}\n' "$1" "$2" "$3" > "$STATE"
}
read_field() { sed -n "s/.*\"$1\": *\"\\{0,1\\}\\([^\",}]*\\)\"\\{0,1\\}.*/\\1/p" "$STATE" | head -1; }

code_hash() {
  local base="HEAD"
  [ -f "$STATE_DIR/baseline" ] && base="$(cat "$STATE_DIR/baseline")"
  { git diff "$base" -- src 2>/dev/null
    git ls-files --others --exclude-standard -- src 2>/dev/null | while IFS= read -r f; do echo "== $f"; cat "$f"; done
  } | hash12
}

case "${1:-check}" in
  reset)
    write_state 0 "$MAX_ATTEMPTS" READY
    : > "$HISTORY"
    : > "$LAST_VERDICT"
    echo "loop reset — budget ${MAX_ATTEMPTS} attempt(s)"
    exit 0 ;;
  status)
    [ -f "$STATE" ] || { echo "no loop in progress"; exit 0; }
    echo "attempt $(read_field attempts)/$(read_field max_attempts)  status=$(read_field status)"
    exit 0 ;;
  check) ;;
  *) echo "usage: loop.sh [reset|check|status]" >&2; exit 3 ;;
esac

[ -f "$STATE" ] || bash "$0" reset >/dev/null
ATTEMPTS="$(read_field attempts)"; MAX="$(read_field max_attempts)"
STATUS="$(read_field status)"
case "$STATUS" in
  STOP_THRASHING|STOP_BUDGET)
    echo "STOPPED ($STATUS) — this loop already ended. Escalate, or run ./scripts/loop.sh reset to"
    echo "start a new bounded loop deliberately."
    exit $([ "$STATUS" = STOP_THRASHING ] && echo 4 || echo 5) ;;
esac

CODE="$(code_hash)"
PREV="$(tail -1 "$HISTORY" 2>/dev/null)"
PREV_N="$(printf '%s' "$PREV" | cut -f1)"
PREV_CODE="$(printf '%s' "$PREV" | cut -f2)"
PREV_FAIL="$(printf '%s' "$PREV" | cut -f3)"
PREV_KIND="$(printf '%s' "$PREV" | cut -f4)"

if [ -n "$PREV" ] && [ "$CODE" = "$PREV_CODE" ]; then
  echo "REDUNDANT RETRY — nothing under src/ has changed since attempt ${PREV_N} (code ${CODE})."
  echo "Re-running the verifier on identical code cannot produce a different result, so this was"
  echo "not counted. Make a change, or stop and escalate. Last verdict: .workflow/last-verdict.txt"
  exit 6
fi

VERDICT="$(bash "$VERIFY_CMD" 2>&1)"; RC=$?
printf '%s' "$VERDICT" > "$LAST_VERDICT"
# The failure fingerprint covers HOW it failed: the failing checks and their detail lines.
# Text from passing checks (e.g. a changed hunk count) must not make an identical failure look
# new. A verifier with no ✗ lines is fingerprinted whole.
SIG="$(printf '%s\n' "$VERDICT" | awk '/^✗/{p=1; print; next} p && /^    /{print; next} {p=0}')"
[ -n "$SIG" ] || SIG="$VERDICT"
FAIL_HASH="$(printf '%s' "$SIG" | hash12)"

if [ "$RC" -eq 0 ]; then
  write_state "$ATTEMPTS" "$MAX" DONE
  echo "$VERDICT"
  echo ""
  echo "DONE — green at attempt $((ATTEMPTS + 1)) (code ${CODE})."
  exit 0
fi

ATTEMPTS=$((ATTEMPTS + 1))
KIND="new-failure"
[ -n "$PREV" ] && [ "$FAIL_HASH" = "$PREV_FAIL" ] && KIND="unsuccessful-repair"
printf '%s\t%s\t%s\t%s\n' "$ATTEMPTS" "$CODE" "$FAIL_HASH" "$KIND" >> "$HISTORY"
echo "$VERDICT"
echo ""

if [ "$KIND" = "unsuccessful-repair" ] && [ "$PREV_KIND" = "unsuccessful-repair" ]; then
  write_state "$ATTEMPTS" "$MAX" STOP_THRASHING
  echo "STOP — thrashing. Attempt ${ATTEMPTS}: the code changed again (code ${PREV_CODE} -> ${CODE}) and the"
  echo "verifier failed in exactly the same way for the second time in a row (failure ${FAIL_HASH})."
  echo "Edits are not converging. Escalate with .workflow/last-verdict.txt; do not keep editing."
  exit 4
fi

if [ "$ATTEMPTS" -ge "$MAX" ]; then
  write_state "$ATTEMPTS" "$MAX" STOP_BUDGET
  echo "STOP — budget exhausted (${ATTEMPTS}/${MAX} attempts) and still failing. Escalate to a human."
  exit 5
fi

write_state "$ATTEMPTS" "$MAX" CONTINUE
if [ "$KIND" = "unsuccessful-repair" ]; then
  echo "UNSUCCESSFUL REPAIR — attempt ${ATTEMPTS}/${MAX}: the code changed (code ${PREV_CODE} -> ${CODE}) but the"
  echo "verifier failed exactly as it did at attempt ${PREV_N}. One more identical outcome stops the loop."
else
  echo "CONTINUE — attempt ${ATTEMPTS}/${MAX} failed (failure ${FAIL_HASH}, code ${CODE})."
fi
exit 1
