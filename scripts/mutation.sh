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
# Not used by any of this lab's 7 stages — ported for tooling parity, available
# if you want it.
#
# No Python: PIT's mutations.xml is line-oriented in practice — every <mutation>
# element PIT emits is self-contained on one line — so this is a plain awk pass
# over grep-filtered lines, not a general XML parser.
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

MUT_LINES="$(grep '<mutation ' "$REPORT")"
TOTAL="$(printf '%s\n' "$MUT_LINES" | grep -c '<mutation ')"
[ "$TOTAL" -gt 0 ] || { echo "no mutations found in $REPORT"; exit 2; }

KILLED="$(printf '%s\n' "$MUT_LINES" | grep -c "status='KILLED'")"
SCORE="$(awk -v k="$KILLED" -v t="$TOTAL" 'BEGIN{printf "%.0f", 100*k/t}')"

echo "mutation score: ${SCORE}%  (${KILLED}/${TOTAL} killed)"

printf '%s\n' "$MUT_LINES" \
  | grep -o "status='[A-Z_]*'" \
  | sed "s/status='//;s/'//" \
  | sort | uniq -c | sort -rn \
  | awk '{printf "  %-14s%s\n", $2, $1}'

if [ "$QUIET" = "--quiet" ]; then
  exit 0
fi

echo ""
echo "fee logic — the rates this whole codebase is about:"
printf '%s\n' "$MUT_LINES" | awk '
function tagval(line, tag,    pat, s, rest, e) {
    pat = "<" tag ">"
    s = index(line, pat)
    if (s == 0) return ""
    s += length(pat)
    rest = substr(line, s)
    e = index(rest, "</" tag ">")
    if (e == 0) return ""
    return substr(rest, 1, e - 1)
}
function unescape(s,    sq) {
    sq = sprintf("%c", 39)
    gsub(/&quot;/, "\"", s)
    gsub(/&apos;/, sq, s)
    gsub(/&lt;/, "<", s)
    gsub(/&gt;/, ">", s)
    gsub(/&amp;/, "\\&", s)
    return s
}
{
    if (tagval($0, "mutatedMethod") != "calculateFee") next
    match($0, /status=.[A-Z_]*./)
    status = substr($0, RSTART + 8, RLENGTH - 9)
    cls = tagval($0, "mutatedClass")
    n = split(cls, parts, ".")
    clsShort = parts[n]
    line = tagval($0, "lineNumber")
    desc = unescape(tagval($0, "description"))
    printf "  [%-12s] %s:%s  %s\n", status, clsShort, line, desc
}
'
