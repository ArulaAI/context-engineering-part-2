#!/usr/bin/env bash
#
# request-approval.sh — ask the owning organization for its approved record.
#
# Some questions cannot be settled from inside a repository. "Which of these two rates is
# the one Meridian actually approved?" is a business-authority question: the compiler cannot
# answer it, the tests cannot answer it, and a model reading both files cannot answer it —
# it can only pick one. The answer lives with whoever owns the decision.
#
# In this lab the Pricing Committee's approval system is simulated by a git ref,
# `pricing-approvals`, that is NOT part of the working tree. That is deliberate: nothing you
# or an agent can search or read in the workspace contains the approval until a person asks
# for it here, at the human gate.
#
# usage: scripts/request-approval.sh <WORK-ITEM>        e.g. MFIN-2088
# writes: docs/approvals/<RECORD>.md
# exit 0 retrieved · 2 bad usage · 3 no approval exists for that work item

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

ITEM="${1:-}"
[ -n "$ITEM" ] || { echo "usage: request-approval.sh <WORK-ITEM>" >&2; exit 2; }

REF=""
for candidate in origin/pricing-approvals pricing-approvals; do
  git rev-parse --verify --quiet "${candidate}^{commit}" >/dev/null && { REF="$candidate"; break; }
done
[ -n "$REF" ] || {
  echo "request-approval: the approval system is unreachable (no pricing-approvals ref)." >&2
  echo "Run: git fetch origin pricing-approvals   — then retry." >&2
  exit 3
}

RECORD="$(git show "${REF}:index.txt" 2>/dev/null | awk -v i="$ITEM" '$1 == i {print $2; exit}')"
[ -n "$RECORD" ] || {
  echo "request-approval: no approved pricing record exists for ${ITEM}." >&2
  echo "Nothing has been approved — the question stays open. Do not proceed as if it were." >&2
  exit 3
}

mkdir -p docs/approvals
git show "${REF}:${RECORD}" > "docs/approvals/${RECORD}" || { echo "request-approval: retrieval failed" >&2; exit 3; }

echo "Retrieved the approved record for ${ITEM} from the Pricing Committee's approval system."
echo "  -> docs/approvals/${RECORD}"
echo ""
echo "Read it before you decide anything. It is the authority; your job is to apply it"
echo "correctly — including exactly what it does and does not supersede."
