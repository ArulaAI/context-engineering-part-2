#!/usr/bin/env bash
#
# review-package.sh — the minimum VIABLE context for an independent review.
#
# "PaymentService.java changed; calculateFee changed" is minimum context, and a reviewer
# cannot find a wrong comparison in a file name. Minimum context is not the goal. Minimum
# viable context is: exactly what a reviewer needs to judge the change, and nothing that
# would tell it what to conclude.
#
#   INCLUDED   the ticket's acceptance criteria        what the change must do
#              the approved decision(s) and authority  the rule the code must implement
#              the actual changed hunks, with context  the code being judged
#   EXCLUDED   the builder's conversation, the investigation, the handoff, the register's
#              facts and unknowns, and any opinion about whether the change is correct
#
# usage: scripts/review-package.sh [work-unit]      (default: calculateFee-rtp)
# output: markdown on stdout, also saved to .workflow/review-package.md
# exit 0 ok · 3 missing state (no baseline, no decision, or no change to review)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

UNIT="${1:-calculateFee-rtp}"
REG=".context/context-register.yaml"
OUT=".workflow/review-package.md"

[ -f .workflow/baseline ] || { echo "review-package: no .workflow/baseline — run ./scripts/lab-start.sh" >&2; exit 3; }
[ -f "$REG" ] || { echo "review-package: no register — there is no approved decision to review against" >&2; exit 3; }
BASE="$(cat .workflow/baseline)"

DIFF="$(git diff -U4 "$BASE" -- src/main/java src/test/java)"
[ -n "$DIFF" ] || { echo "review-package: nothing has changed since the baseline — no change to review" >&2; exit 3; }

DECISIONS="$(awk -v u="$UNIT" '
  /^decisions:/ {d=1; next} /^[a-z_]+:/ {d=0}
  d && /^  - id: / { if (id != "" && (tag == "" || tag == u)) print "- **" id "** " dec " (authority: `" auth "`)"
                     id=$0; sub(/^  - id: /,"",id); gsub(/"/,"",id); dec=""; auth=""; tag="" }
  d && /^    decision: /   { dec=$0;  sub(/^    decision: /,"",dec);   gsub(/^"|"$/,"",dec) }
  d && /^    authority: /  { auth=$0; sub(/^    authority: /,"",auth); gsub(/"/,"",auth) }
  d && /^    applies_to: / { tag=$0;  sub(/^    applies_to: /,"",tag); gsub(/"/,"",tag) }
  END { if (id != "" && (tag == "" || tag == u)) print "- **" id "** " dec " (authority: `" auth "`)" }
' "$REG")"
[ -n "$DECISIONS" ] || { echo "review-package: no approved decision for $UNIT — nothing to review against" >&2; exit 3; }

AC="$(awk '/^## MFIN-2088/{t=1} t && /^### Acceptance Criteria/{a=1; next} a && /^### /{exit} a' docs/JIRA_TICKETS.md)"

{
  echo "# Review package — $UNIT"
  echo ""
  echo "You are reviewing a change. Judge it only from what is below."
  echo ""
  echo "## Acceptance criteria (MFIN-2088)"
  printf '%s\n' "$AC"
  echo ""
  echo "## Approved decision the change must implement"
  echo ""
  printf '%s\n' "$DECISIONS"
  echo ""
  echo "## The change (diff since the starting commit)"
  echo ""
  echo '```diff'
  printf '%s\n' "$DIFF"
  echo '```'
} | tee "$OUT"

echo ""
echo "Saved to $OUT — $(printf '%s\n' "$DIFF" | grep -c '^[+-][^+-]') changed line(s) in $(printf '%s\n' "$DIFF" | grep -c '^@@') hunk(s)."
