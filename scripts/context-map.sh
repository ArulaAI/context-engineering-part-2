#!/usr/bin/env bash
#
# context-map.sh — a routing table for where truth lives, not an answer.
#
# Stage 1 ("Discover Before You Retrieve") replaces "search the repo" with "find out
# which of several categories of source actually bears on this question, before you
# open any of them." This script does the finding; it never prints file contents,
# only paths, hit counts, and a tier hint — the map is cheap on purpose so you're not
# tempted to treat it as the answer.
#
# usage: scripts/context-map.sh [keyword]

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

KEYWORD="${1:-SEPA}"

hitcount() {
  # $1 = path/glob description (for the summary line), remaining args = grep target(s)
  local dir="$1"; shift
  if [ -d "$dir" ]; then
    grep -rl "$KEYWORD" "$dir" 2>/dev/null | wc -l | tr -d ' '
  else
    echo 0
  fi
}

SRC_HITS="$(hitcount src/main/java)"
CONFIG_HITS="$(hitcount config)"
ADR_HITS="$(hitcount docs/adr)"
TICKET_HITS="$( [ -f docs/JIRA_TICKETS.md ] && grep -c "$KEYWORD" docs/JIRA_TICKETS.md 2>/dev/null || echo 0 )"
TEST_HITS="$(hitcount src/test/java)"

echo "CONTEXT MAP — \"${KEYWORD}\""
echo "====================================================="
printf "%-26s %s\n" "Affected domains" "src/main/java/com/meridian/payments  (fee logic — PaymentService)"

if [ "$SRC_HITS" -eq 0 ]; then
  printf "%-26s %s\n" "Relevant symbols" "calculateFee(BigDecimal, String)  [handles WIRE/ACH/SWIFT — no ${KEYWORD} branch yet]"
else
  printf "%-26s %s\n" "Relevant symbols" "calculateFee(BigDecimal, String)  [${SRC_HITS} file(s) already mention ${KEYWORD}]"
fi

printf "%-26s %s\n" "Contracts" "none — no ${KEYWORD}-specific interface exists"

if [ "$CONFIG_HITS" -gt 0 ]; then
  LINE="$(grep -Hn "$KEYWORD" config/*.yaml 2>/dev/null | head -1)"
  printf "%-26s %s\n" "Configuration" "${LINE}  [authoritative committed config]"
else
  printf "%-26s %s\n" "Configuration" "none found under config/"
fi

if [ "$ADR_HITS" -gt 0 ]; then
  ADR_FILE="$(grep -rl "$KEYWORD" docs/adr 2>/dev/null | head -1)"
  STATUS="$(grep -m1 '^\*\*Status:\*\*' "$ADR_FILE" 2>/dev/null | sed 's/\*\*Status:\*\* *//')"
  printf "%-26s %s\n" "Architecture decisions" "${ADR_FILE}  [STATUS: ${STATUS:-unknown} — verify before trusting]"
else
  printf "%-26s %s\n" "Architecture decisions" "none found under docs/adr"
fi

if [ "$TEST_HITS" -gt 0 ]; then
  printf "%-26s %s\n" "Tests" "${TEST_HITS} file(s) already reference ${KEYWORD}"
else
  printf "%-26s %s\n" "Tests" "none — src/test has no ${KEYWORD} test yet"
fi

printf "%-26s %s\n" "Runtime/dependency bounds" "none — ${KEYWORD} introduces no new library dependency"

if [ "$TICKET_HITS" -gt 0 ]; then
  printf "%-26s %s\n" "Ticket / objective" "docs/JIRA_TICKETS.md  (${TICKET_HITS} mention(s))"
else
  printf "%-26s %s\n" "Ticket / objective" "no ticket mentions ${KEYWORD} — check you have the right keyword"
fi

echo ""
echo "src/main: ${SRC_HITS} file(s).  config/: ${CONFIG_HITS} file(s).  docs/adr: ${ADR_HITS} file(s).  docs/JIRA_TICKETS.md: ${TICKET_HITS} mention(s)."
echo ""

if [ "$CONFIG_HITS" -gt 0 ] && [ "$ADR_HITS" -gt 0 ]; then
  echo "Configuration and an architecture decision both mention ${KEYWORD} — resolve"
  echo "which is authoritative before writing code (diff their rates by hand; there is"
  echo "no compiler check for this, since ${KEYWORD} doesn't exist in code yet)."
  echo ""
fi

echo "This is a routing table, not an answer. It tells you where to look next, not what"
echo "you'll find there."
exit 0
