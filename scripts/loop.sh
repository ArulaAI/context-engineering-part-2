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
#
# No dependencies beyond bash + shasum + the standard coreutils. State lives in
# three small plain-text files, not one JSON blob — deliberately: the verifier's
# raw output can contain quotes, backslashes, and newlines, which is exactly the
# kind of content that's fragile to embed inside hand-rolled JSON. Keeping it in
# its own file sidesteps the escaping problem instead of solving it cleverly.
#
#   .workflow/state.json           attempts, max_attempts, status — fixed-shape,
#                                   safe to hand-write because every value in it
#                                   is a number or a name from a known short list
#   .workflow/verdict-hashes.txt   one hash per line, append-only within a loop
#   .workflow/last-verdict.txt     the raw verifier output, byte for byte

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

STATE_DIR=".workflow"
STATE="$STATE_DIR/state.json"
HASHES="$STATE_DIR/verdict-hashes.txt"
LAST_VERDICT="$STATE_DIR/last-verdict.txt"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
VERIFY_CMD="${VERIFY_CMD:-scripts/verify.sh}"
mkdir -p "$STATE_DIR"

write_state() {
  # $1=attempts $2=max_attempts $3=status — all three are always a plain
  # integer or a name from a fixed set, so this is safe to hand-write.
  printf '{\n  "attempts": %s,\n  "max_attempts": %s,\n  "status": "%s"\n}\n' \
    "$1" "$2" "$3" > "$STATE"
}

read_field() {
  # $1=field name — extracts it from $STATE via the exact shape write_state
  # always produces, one field per line.
  sed -n "s/.*\"$1\": *\"\\{0,1\\}\\([^\",}]*\\)\"\\{0,1\\}.*/\\1/p" "$STATE" | head -1
}

hash_verdict() {
  # $1=text — prefers shasum, falls back to sha256sum, then cksum, so
  # hashing never hard-fails for lack of one specific tool (some minimal
  # Git-for-Windows installs lack shasum but have sha256sum). The hash is
  # only ever compared to itself for equality, never parsed, so cksum's
  # shorter numeric output is fine too.
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum | cut -c1-12
  elif command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | cut -c1-12
  else
    printf '%s' "$1" | cksum | tr -d ' \n'
  fi
}

case "${1:-check}" in

  reset)
    write_state 0 "$MAX_ATTEMPTS" READY
    : > "$HASHES"
    : > "$LAST_VERDICT"
    echo "loop reset — budget ${MAX_ATTEMPTS}"
    exit 0
    ;;

  status)
    [ -f "$STATE" ] || { echo "no loop in progress"; exit 0; }
    echo "attempt $(read_field attempts)/$(read_field max_attempts)  status=$(read_field status)"
    exit 0
    ;;

  check) ;;
  *) echo "usage: loop.sh [reset|check|status]" >&2; exit 3 ;;
esac

[ -f "$STATE" ] || bash "$0" reset >/dev/null

VERDICT="$(bash "$VERIFY_CMD" 2>&1)"; RC=$?
HASH="$(hash_verdict "$VERDICT")"
printf '%s' "$VERDICT" > "$LAST_VERDICT"

ATTEMPTS="$(read_field attempts)"
MAX="$(read_field max_attempts)"

if [ "$RC" -eq 0 ]; then
  write_state "$ATTEMPTS" "$MAX" DONE
  echo "$VERDICT"
  echo "DONE — green."
  exit 0
fi

ATTEMPTS=$((ATTEMPTS + 1))

# Thrashing: the verifier said exactly this before. Edits are landing, the
# outcome is not moving. More attempts will not help; a human must look.
if grep -qFx "$HASH" "$HASHES" 2>/dev/null; then
  echo "$HASH" >> "$HASHES"
  write_state "$ATTEMPTS" "$MAX" STOP_THRASHING
  echo "$VERDICT"
  echo "STOP — thrashing. Identical verdict at attempt ${ATTEMPTS} (hash ${HASH})."
  echo "The diff is moving; the outcome is not. Escalate, do not retry."
  exit 4
fi
echo "$HASH" >> "$HASHES"

if [ "$ATTEMPTS" -ge "$MAX" ]; then
  write_state "$ATTEMPTS" "$MAX" STOP_BUDGET
  echo "$VERDICT"
  echo "STOP — budget exhausted (${ATTEMPTS}/${MAX}). Escalate to a human."
  exit 5
fi

write_state "$ATTEMPTS" "$MAX" CONTINUE
echo "$VERDICT"
echo "CONTINUE — attempt ${ATTEMPTS}/${MAX} used."
exit 1
