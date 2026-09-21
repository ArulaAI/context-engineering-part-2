#!/usr/bin/env bash
#
# test-evidence.sh — does any test actually exercise THIS behavior?
#
# "Is method X covered?" and "is behavior Y of method X proven?" are different claims.
# A method can be referenced by tests that never touch the case you care about, so method
# coverage cannot settle a behavior claim. This answers the narrower question directly:
#
#   Which @Test methods call <method>, and which of those also use <token>?
#   If any do, run exactly those tests and report whether they pass.
#
# A source scan can show that NO test exercises a behavior. It cannot show that one does
# pass — that needs execution, so when matching tests exist, this runs them.
#
# usage: scripts/test-evidence.sh <method> <token> [test-root]
#   e.g. scripts/test-evidence.sh calculateFee RTP
# exit 0 answered · 2 bad input · 3 the tests could not be run (evidence unavailable)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

METHOD="${1:-}"
TOKEN="${2:-}"
ROOT="${3:-src/test/java}"
if [ -z "$METHOD" ] || [ -z "$TOKEN" ]; then
  echo "usage: test-evidence.sh <method> <token> [test-root]" >&2
  exit 2
fi
[ -d "$ROOT" ] || { echo "test-evidence: no test root at $ROOT" >&2; exit 2; }

# One row per @Test method: file<TAB>class<TAB>test<TAB>calls_method<TAB>uses_token<TAB>asserts
ROWS="$(find "$ROOT" -name '*.java' | sort | while IFS= read -r f; do
  awk -v file="$f" -v meth="$METHOD" -v tok="$TOKEN" '
    function flush() {
      if (name != "") {
        calls = (body ~ ("[^A-Za-z0-9_]" meth "[[:space:]]*\\(")) ? 1 : 0
        uses  = (index(body, tok) > 0) ? 1 : 0
        n = gsub(/assert[A-Za-z]*[[:space:]]*\(/, "&", body)
        printf "%s\t%s\t%s\t%d\t%d\t%d\n", file, cls, name, calls, uses, n
      }
      name = ""; body = ""; depth = 0; started = 0
    }
    /^[[:space:]]*(public[[:space:]]+)?(final[[:space:]]+)?class[[:space:]]+/ {
      for (i = 1; i <= NF; i++) if ($i == "class") { cls = $(i+1); sub(/[^A-Za-z0-9_].*/, "", cls) }
    }
    /@Test/ { pending = 1; next }
    pending && /void[[:space:]]+[A-Za-z0-9_]+[[:space:]]*\(/ {
      flush(); pending = 0
      name = $0; sub(/.*void[[:space:]]+/, "", name); sub(/[[:space:]]*\(.*/, "", name)
    }
    name != "" {
      body = body "\n" $0
      o = gsub(/\{/, "{"); c = gsub(/\}/, "}")
      depth += o - c
      if (o > 0) started = 1
      if (started && depth <= 0) flush()
    }
    END { flush() }
  ' "$f"
done)"

TOTAL="$(printf '%s\n' "$ROWS" | grep -c . || true)"
CALLING="$(printf '%s\n' "$ROWS" | awk -F'\t' '$4==1' | grep -c . || true)"
MATCHING="$(printf '%s\n' "$ROWS" | awk -F'\t' '$4==1 && $5==1')"
N_MATCH="$(printf '%s\n' "$MATCHING" | grep -c . || true)"

echo "Q: does any test exercise ${METHOD}() with \"${TOKEN}\"?"
echo ""
echo "| Evidence | Count |"
echo "|---|---|"
echo "| @Test methods scanned | ${TOTAL} |"
echo "| call \`${METHOD}()\` | ${CALLING} |"
echo "| call \`${METHOD}()\` AND use \"${TOKEN}\" | ${N_MATCH} |"
echo ""

if [ "$N_MATCH" -eq 0 ]; then
  echo "VERDICT: NOT PROVEN — no test exercises ${METHOD}() with \"${TOKEN}\"."
  if [ "$CALLING" -gt 0 ]; then
    echo "  ${CALLING} test(s) call ${METHOD}(), none with \"${TOKEN}\" — method coverage is not"
    echo "  evidence for this behavior."
  fi
  echo ""
  echo "EVIDENCE: claim=\"tests exercise ${METHOD} with ${TOKEN}\" status=unproven mechanism=test-source-scan matching_tests=0"
  exit 0
fi

echo "| Test | Assertions |"
echo "|---|---|"
printf '%s\n' "$MATCHING" | awk -F'\t' '{printf "| `%s#%s` | %s |\n", $2, $3, $6}'
echo ""

# Execution evidence: run exactly the matching tests.
FILTER="$(printf '%s\n' "$MATCHING" | awk -F'\t' '{printf "%s%s#%s", sep, $2, $3; sep=","}')"
LOG="$(mktemp)"; trap 'rm -f "$LOG"' EXIT
mvn -B -q test -Dtest="$FILTER" -Dsurefire.failIfNoSpecifiedTests=false >"$LOG" 2>&1; RC=$?
RUN="$(grep -ho 'Tests run: [0-9]\+' target/surefire-reports/*.txt 2>/dev/null | awk -F': ' '{s+=$2} END{print s+0}')"
if [ "$RC" -ne 0 ] && ! grep -q 'FAILURE\|Tests run:.*Failures: [1-9]' "$LOG" target/surefire-reports/*.txt 2>/dev/null; then
  echo "test-evidence: the matching tests could not be run (mvn exit ${RC}) — evidence unavailable." >&2
  tail -5 "$LOG" >&2
  exit 3
fi
FAILED="$(grep -hoE 'Failures: [0-9]+, Errors: [0-9]+' target/surefire-reports/*.txt 2>/dev/null \
          | awk -F'[:,] *' '{s+=$2+$4} END{print s+0}')"
if [ "$RC" -eq 0 ]; then
  echo "VERDICT: ${N_MATCH} test(s) exercise ${METHOD}() with \"${TOKEN}\" — ran ${RUN}, all passed."
  echo "  Whether they cover a specific boundary of that behavior is a separate, narrower claim."
  STATUS=verified
else
  echo "VERDICT: ${N_MATCH} test(s) exercise ${METHOD}() with \"${TOKEN}\" — ran ${RUN}, ${FAILED} FAILED."
  grep -h '<<< \(FAILURE\|ERROR\)!' target/surefire-reports/*.txt 2>/dev/null | grep -v '^Tests run' \
    | sed 's/ *--.*//; s/.*\.\([A-Za-z0-9_]*Test\.\)/\1/; s/^/  failing: /'
  STATUS=failing
fi
echo ""
echo "EVIDENCE: claim=\"tests exercise ${METHOD} with ${TOKEN}\" status=${STATUS} mechanism=test-execution matching_tests=${N_MATCH} executed=${RUN}"
exit 0
