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
# Output is a GFM markdown table, printed to stdout (so it renders as a table in
# Copilot Chat, not a monospace blob) and saved to .context/context-map-<keyword>.md
# so it's still there after the chat scrolls.
#
# usage: scripts/context-map.sh [keyword]

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

KEYWORD="${1:-RTP}"
OUT_DIR=".context"
KEYWORD_SAFE="$(printf '%s' "$KEYWORD" | tr -c 'A-Za-z0-9_-' '_')"
OUT_FILE="${OUT_DIR}/context-map-${KEYWORD_SAFE}.md"

# Escape a literal pipe so a grepped line can never break a markdown table row.
esc() { printf '%s' "$1" | sed 's/|/\\|/g'; }

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
TICKET_HITS="${TICKET_HITS##*$'\n'}"  # strip any multiline; keep last number
TEST_HITS="$(hitcount src/test/java)"

TOTAL_EVIDENCE=$((SRC_HITS + CONFIG_HITS + ADR_HITS + TICKET_HITS + TEST_HITS))

mkdir -p "$OUT_DIR"

{
  echo "# Context Map — \"${KEYWORD}\""
  echo ""

  if [ "$TOTAL_EVIDENCE" -eq 0 ]; then
    echo "| Location | Hits |"
    echo "|---|---|"
    echo "| \`src/main\` | 0 file(s) |"
    echo "| \`config/\` | 0 file(s) |"
    echo "| \`docs/adr\` | 0 file(s) |"
    echo "| \`docs/JIRA_TICKETS.md\` | 0 mention(s) |"
    echo ""
    echo "No routing evidence found for \"${KEYWORD}\"."
    echo ""
    echo "_This mapper is a Meridian worked-example utility; inspect the repo topology_"
    echo "_before adapting it to another domain._"
  else
    echo "| Category | Finding |"
    echo "|---|---|"
    echo "| Affected domains | \`src/main/java/com/meridian/payments\` (fee logic — PaymentService) |"

    if [ "$SRC_HITS" -eq 0 ]; then
      echo "| Relevant symbols | \`calculateFee(BigDecimal, String)\` — handles WIRE/ACH/SWIFT, no ${KEYWORD} branch yet |"
    else
      echo "| Relevant symbols | \`calculateFee(BigDecimal, String)\` — ${SRC_HITS} file(s) already mention ${KEYWORD} |"
    fi

    echo "| Contracts | none — no ${KEYWORD}-specific interface exists |"

    if [ "$CONFIG_HITS" -gt 0 ]; then
      LINE="$(grep -Hn "$KEYWORD" config/*.yaml 2>/dev/null | head -1)"
      echo "| Configuration | \`$(esc "$LINE")\` — **authoritative committed config** |"
    else
      echo "| Configuration | none found under \`config/\` |"
    fi

    if [ "$ADR_HITS" -gt 0 ]; then
      ADR_FILE="$(grep -rl "$KEYWORD" docs/adr 2>/dev/null | head -1)"
      STATUS="$(grep -m1 '^\*\*Status:\*\*' "$ADR_FILE" 2>/dev/null | sed 's/\*\*Status:\*\* *//')"
      echo "| Architecture decisions | \`${ADR_FILE}\` — **STATUS: $(esc "${STATUS:-unknown}")** — verify before trusting |"
    else
      echo "| Architecture decisions | none found under \`docs/adr\` |"
    fi

    if [ "$TEST_HITS" -gt 0 ]; then
      echo "| Tests | ${TEST_HITS} file(s) already reference ${KEYWORD} |"
    else
      echo "| Tests | none — \`src/test\` has no ${KEYWORD} test yet |"
    fi

    echo "| Runtime/dependency bounds | none — ${KEYWORD} introduces no new library dependency |"

    if [ "$TICKET_HITS" -gt 0 ]; then
      echo "| Ticket / objective | \`docs/JIRA_TICKETS.md\` — ${TICKET_HITS} mention(s) |"
    else
      echo "| Ticket / objective | no ticket mentions ${KEYWORD} — check you have the right keyword |"
    fi

    echo ""
    echo "**Hit counts:** \`src/main\`: ${SRC_HITS} &middot; \`config/\`: ${CONFIG_HITS} &middot; \`docs/adr\`: ${ADR_HITS} &middot; \`docs/JIRA_TICKETS.md\`: ${TICKET_HITS} mention(s)"
    echo ""

    if [ "$CONFIG_HITS" -gt 0 ] && [ "$ADR_HITS" -gt 0 ]; then
      echo "> **Configuration and an architecture decision both mention ${KEYWORD}** — resolve"
      echo "> which is authoritative before writing code (diff their rates by hand; there is"
      echo "> no compiler check for this, since ${KEYWORD} doesn't exist in code yet)."
      echo ""
    fi

    echo "_This is a routing table, not an answer. It tells you where to look next, not what_"
    echo "_you'll find there._"
  fi
} | tee "$OUT_FILE"

echo ""
echo "Saved to ${OUT_FILE}"
exit 0
