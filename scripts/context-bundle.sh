#!/usr/bin/env bash
#
# context-bundle.sh — build an exact context window as text, for a controlled comparison.
#
# A comparison between two context windows is only controlled if each side sees exactly its
# window and nothing else. An agent that can open files can always wander outside the window
# it was given, whatever its instructions say — so the probes in this lab have NO tools, and
# their entire context is text you paste. This script produces that text.
#
#   broad     every source a reasonable engineer would attach before sorting anything:
#             the ticket, the fee config, the ADR, and the legacy fee class
#   package   the durable, curated package for a work unit (./scripts/ctx.sh package)
#   durable   the complete durable state: register + handoff + outcome
#   cold      what an actor has with no durable state at all: the ticket and the current code
#
# usage: scripts/context-bundle.sh <broad|package|durable|cold> [work-unit]
# output: stdout, also saved to .context/bundles/<name>.md
# exit 0 ok · 2 bad usage · 3 a required source is missing

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

KIND="${1:-}"
UNIT="${2:-calculateFee-rtp}"
OUT_DIR=".context/bundles"
mkdir -p "$OUT_DIR"

file_block() { # file_block PATH
  [ -f "$1" ] || { echo "context-bundle: missing $1" >&2; exit 3; }
  echo "### FILE: $1"
  echo '```'
  cat "$1"
  echo '```'
  echo ""
}

ticket() { awk '/^## MFIN-2088/{t=1} t && /^---$/{exit} t' docs/JIRA_TICKETS.md; }

case "$KIND" in
  broad)
    {
      echo "## CONTEXT: broad — every source that mentions RTP or a fee rate"
      echo ""
      echo "### FILE: docs/JIRA_TICKETS.md (MFIN-2088)"; echo '```'; ticket; echo '```'; echo ""
      file_block config/fee-schedule.yaml
      file_block docs/adr/ADR-0007-fee-schedule.md
      file_block src/main/java/com/meridian/payments/legacy/LegacyPaymentUtils.java
    } > "$OUT_DIR/broad.md" ;;
  package)
    { echo "## CONTEXT: package — durable, curated state for $UNIT"; echo ""
      bash scripts/ctx.sh package "$UNIT" || exit 3; } > "$OUT_DIR/package.md" || exit 3 ;;
  durable)
    { echo "## CONTEXT: durable — everything persisted, nothing from any conversation"; echo ""
      file_block .context/context-register.yaml
      file_block .workflow/HANDOFF.md
      file_block .workflow/outcome.yaml; } > "$OUT_DIR/durable.md" || exit 3 ;;
  cold)
    F="src/main/java/com/meridian/payments/PaymentService.java"
    R="$(bash scripts/lib/methods.sh "$F" | awk -F'\t' '$1=="calculateFee"{print $2","$3; exit}')"
    { echo "## CONTEXT: cold — no durable state; only the ticket and the current code"; echo ""
      echo "### FILE: docs/JIRA_TICKETS.md (MFIN-2088)"; echo '```'; ticket; echo '```'; echo ""
      echo "### FILE: $F (calculateFee, current)"; echo '```java'; sed -n "${R}p" "$F"; echo '```'; } > "$OUT_DIR/cold.md" ;;
  *) echo "usage: context-bundle.sh <broad|package|durable|cold> [work-unit]" >&2; exit 2 ;;
esac

cat "$OUT_DIR/${KIND}.md"
echo ""
echo "Saved to $OUT_DIR/${KIND}.md ($(wc -l < "$OUT_DIR/${KIND}.md" | tr -d ' ') lines). Paste it whole."
