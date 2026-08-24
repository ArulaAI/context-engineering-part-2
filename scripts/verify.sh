#!/usr/bin/env bash
# verify.sh — the exit code IS the signal.
#
# Build output is the largest thing that enters an agent's context, and almost
# none of it is information. This emits the minimum a repair loop needs to act
# on, and nothing else.
#
#   exit 0  green            "PASS n tests"
#   exit 1  test failure     assertion + file:line
#   exit 2  compile failure   deduped error list
#   exit 3  harness error     (wrong directory, etc.)
#
# Note: `mvn -q` alone is NOT the answer — on success it deletes the two lines
# you actually want, and on failure it keeps nine frames of JUnit internals.
# Branching on the return code is what makes the output honest.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

# ---- compile ---------------------------------------------------------------
if ! mvn -B -q test-compile >"$LOG" 2>&1; then
  # Maven prints every compile error twice. `sort -u` is substantive here,
  # not cosmetic — it halves the payload.
  grep -E '^\[ERROR\].*\.java:\[[0-9]+' "$LOG" \
    | sed -E 's#^\[ERROR\] .*/src/(main|test)/java/##; s/[[:space:]]*$//' \
    | sort -u \
    | head -5
  echo "COMPILE FAIL"
  exit 2
fi

# ---- test ------------------------------------------------------------------
if mvn -B -q test >"$LOG" 2>&1; then
  n=$(grep -ho 'Tests run: [0-9]\+' target/surefire-reports/*.txt 2>/dev/null \
      | awk -F': ' '{s+=$2} END {print s+0}')
  echo "PASS ${n} tests"
  exit 0
fi

# ---- first failing assertion only -----------------------------------------
# One failure is enough to act on. Reporting all of them is padding.
awk '
  # the per-test failure line, not the "Tests run:" summary line
  /<<< (FAILURE|ERROR)!/ && !/^Tests run:/ {
      name=$1; sub(/^([a-z0-9_]+\.)+/, "", name); next
  }
  /^(org\.opentest4j|java\.lang|org\.junit|org\.mockito)/ { why=$0 }
  /^[[:space:]]+at .*Test\.java:[0-9]+\)/ && why {
      sub(/^[[:space:]]+at .*\(/, "", $0); sub(/\)$/, "", $0)
      printf "%s\n%s\n%s\n", name, why, $0
      exit
  }
' target/surefire-reports/*.txt 2>/dev/null | head -3

echo "TEST FAIL"
exit 1
