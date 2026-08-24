#!/usr/bin/env bash
# mutation.sh — how much of your green suite is actually checking anything?
#
# Coverage tells you a line EXECUTED. Mutation testing changes the line and asks
# whether any test NOTICED. Those are very different questions, and only one of
# them is evidence.
#
# PIT deliberately corrupts the code (flips a conditional, swaps * for /, returns
# null) and re-runs the suite. A mutant that survives is a change no test caught.
#
# usage: scripts/mutation.sh [--quiet]

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

QUIET="${1:-}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

# The goal is unbound, so compile first — otherwise PIT finds 0 mutation units.
mvn -B -q test-compile >"$LOG" 2>&1 || { echo "compile failed"; exit 2; }
mvn -B org.pitest:pitest-maven:mutationCoverage >"$LOG" 2>&1 || {
  echo "pitest failed — see $LOG"; tail -5 "$LOG"; exit 2;
}

REPORT=target/pit-reports/mutations.xml
[ -f "$REPORT" ] || { echo "no report at $REPORT"; exit 2; }

python3 - "$REPORT" "$QUIET" <<'PY'
import sys, xml.etree.ElementTree as ET
from collections import Counter

report, quiet = sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else ""
muts = ET.parse(report).getroot().findall("mutation")
total = len(muts)
st = Counter(m.get("status") for m in muts)
killed = st.get("KILLED", 0)
score = round(100 * killed / total) if total else 0

print(f"mutation score: {score}%  ({killed}/{total} killed)")
for k, v in st.most_common():
    print(f"  {k:<14}{v}")

if quiet == "--quiet":
    sys.exit(0)

print("\nfee logic — the rates this whole codebase is about:")
for m in muts:
    if m.findtext("mutatedMethod") == "calculateFee":
        cls = m.findtext("mutatedClass", "").split(".")[-1]
        print(f"  [{m.get('status'):<12}] {cls}:{m.findtext('lineNumber')}  {m.findtext('description')}")
PY
