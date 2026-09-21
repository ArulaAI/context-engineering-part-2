#!/usr/bin/env bash
#
# context-map.sh — where to look, and what is still open. Never what is true.
#
#   CONTEXT MAP          tells you WHERE TO LOOK            (this script)
#   EVIDENCE MECHANISMS  tell you WHAT CAN BE PROVEN        (authority.sh, test-evidence.sh, ...)
#   CONTEXT REGISTER     tells future actors WHAT HAS BEEN VERIFIED / DECIDED   (ctx.sh)
#
# This script is a router. It names candidate context surfaces and turns what it cannot
# settle into explicit UNRESOLVED questions. It deliberately never says "authoritative",
# "correct", "dead", "superseded" or "no dependency" — those are claims, and claims are
# settled by evidence mechanisms or by people with authority, not by a map.
#
# Nothing here is specific to RTP. Candidates come from the task text and the repository's
# own layout: a ticket section that mentions the keyword; symbols that ticket names which
# exist in src/main; config, decision records, tests and docs that mention the keyword;
# and imports in the candidate files that look legacy.
#
# usage: scripts/context-map.sh <keyword> [TICKET-ID]
# output: markdown on stdout, also saved to .context/context-map-<keyword>.md

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

KEYWORD="${1:-}"
TICKET_ID="${2:-}"
if [ -z "$KEYWORD" ]; then
  echo "usage: context-map.sh <keyword> [TICKET-ID]" >&2
  exit 3
fi

OUT_DIR=".context"
SAFE="$(printf '%s' "$KEYWORD" | tr -c 'A-Za-z0-9_-' '_')"
OUT_FILE="$OUT_DIR/context-map-${SAFE}.md"
mkdir -p "$OUT_DIR"

TICKETS="docs/JIRA_TICKETS.md"
MAIN="src/main/java"
TEST="src/test/java"

# Lab machinery is not repository context. Excluding it keeps the map honest.
is_machinery() {
  case "$1" in
    .github/*|.context/*|.workflow/*|scripts/*|fixtures/*|docs/facilitator/*|target/*) return 0 ;;
    docs/INTELLIJ_PATH.md|docs/TROUBLESHOOTING.md|docs/LAB_WALKTHROUGH.html) return 0 ;;
    LAB_ACTION_GUIDE.md|README.md|AGENTS.md) return 0 ;;
  esac
  return 1
}

# ---- TASK: ticket sections that mention the keyword --------------------------------
TASK_ROWS=""
TASK_TEXT=""
if [ -f "$TICKETS" ]; then
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if [ -n "$TICKET_ID" ] && [ "$id" != "$TICKET_ID" ]; then continue; fi
    section="$(awk -v id="$id" '
      /^## / { on = (index($0, "## " id) == 1) }
      on { print }' "$TICKETS")"
    if printf '%s' "$section" | grep -qiw -- "$KEYWORD"; then
      title="$(printf '%s\n' "$section" | head -1 | sed 's/^## *//')"
      TASK_ROWS="${TASK_ROWS}| Task / work item | \`${TICKETS}\` — ${title} |"$'\n'
      TASK_TEXT="${TASK_TEXT}${section}"$'\n'
    fi
  done < <(grep -oE '^## [A-Z][A-Z0-9]+-[0-9]+' "$TICKETS" | sed 's/^## //')
fi

# ---- IMPLEMENTATION CANDIDATES --------------------------------------------------------
# (a) symbols the task names, e.g. `PaymentService.calculateFee()`, that exist in src/main
# (b) main-source files that already mention the keyword
IMPL_ROWS=""
CANDIDATE_CLASSES=""
while IFS= read -r sym; do
  [ -n "$sym" ] || continue
  cls="${sym%%.*}"
  meth=""
  case "$sym" in *.*) meth="${sym#*.}"; meth="${meth%()}" ;; esac
  file="$(find "$MAIN" -name "${cls}.java" 2>/dev/null | head -1)"
  [ -n "$file" ] || continue
  if [ -n "$meth" ]; then
    grep -qE "[[:space:]]${meth}[[:space:]]*\(" "$file" || continue
    IMPL_ROWS="${IMPL_ROWS}| Implementation candidate | \`${cls}.${meth}\` in \`${file}\` — named by the task |"$'\n'
    CANDIDATE_CLASSES="${CANDIDATE_CLASSES} ${cls}"
  fi
done < <(printf '%s' "$TASK_TEXT" | grep -oE '`[A-Z][A-Za-z0-9]*(\.[a-z][A-Za-z0-9]*\(\))?`' | tr -d '`' | sort -u)

while IFS= read -r f; do
  [ -n "$f" ] || continue
  cls="$(basename "$f" .java)"
  case " $CANDIDATE_CLASSES " in *" $cls "*) continue ;; esac
  IMPL_ROWS="${IMPL_ROWS}| Implementation candidate | \`${f}\` — mentions \"${KEYWORD}\" |"$'\n'
  CANDIDATE_CLASSES="${CANDIDATE_CLASSES} ${cls}"
done < <(grep -rliw -- "$KEYWORD" "$MAIN" 2>/dev/null | sort)

# ---- CONFIGURATION: files and the keys that mention the keyword (keys, not values) -----
CONFIG_ROWS=""
CONFIG_FILES=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  keys="$(grep -iw -- "$KEYWORD" "$f" | grep -oE '^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*:' \
          | sed 's/[[:space:]:]//g' | sort -u | paste -sd, - | sed 's/,/, /g')"
  CONFIG_ROWS="${CONFIG_ROWS}| Configuration candidate | \`${f}\`${keys:+ — keys: \`${keys}\`} |"$'\n'
  CONFIG_FILES="${CONFIG_FILES} ${f}"
done < <(grep -rliw -- "$KEYWORD" config 2>/dev/null | sort)

# ---- DECISION RECORDS: ADRs that mention the keyword, with their own Status field -----
ADR_ROWS=""
ADR_FILES=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  status="$(grep -m1 -E '^\*\*Status:\*\*' "$f" | sed 's/^\*\*Status:\*\* *//')"
  ADR_ROWS="${ADR_ROWS}| Decision record | \`${f}\` — its Status field reads \"${status:-none}\" |"$'\n'
  ADR_FILES="${ADR_FILES} ${f}"
done < <(grep -rliw -- "$KEYWORD" docs/adr 2>/dev/null | sort)

# ---- TEST SURFACES: tests for the candidate classes, and any test mentioning the keyword
TEST_ROWS=""
UNPROVEN_TESTS=""
for cls in $CANDIDATE_CLASSES; do
  tf="$(find "$TEST" -name "${cls}Test.java" 2>/dev/null | head -1)"
  [ -n "$tf" ] || continue
  n="$(grep -ciw -- "$KEYWORD" "$tf" || true)"
  TEST_ROWS="${TEST_ROWS}| Test surface | \`${tf}\` — lines mentioning \"${KEYWORD}\": ${n} |"$'\n'
  [ "$n" -eq 0 ] && UNPROVEN_TESTS="${UNPROVEN_TESTS} ${tf}"
done
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$TEST_ROWS" in *"\`${f}\`"*) continue ;; esac
  TEST_ROWS="${TEST_ROWS}| Test surface | \`${f}\` — mentions \"${KEYWORD}\" |"$'\n'
done < <(grep -rliw -- "$KEYWORD" "$TEST" 2>/dev/null | sort)

# ---- DEPENDENCY / LEGACY SIGNALS: legacy-looking imports in candidate files -------------
LEGACY_ROWS=""
LEGACY_PAIRS=""
for cls in $CANDIDATE_CLASSES; do
  f="$(find "$MAIN" -name "${cls}.java" 2>/dev/null | head -1)"
  [ -n "$f" ] || continue
  while IFS= read -r imp; do
    [ -n "$imp" ] || continue
    short="${imp##*.}"
    LEGACY_ROWS="${LEGACY_ROWS}| Legacy / dependency signal | \`${short}\` — imported by \`${cls}\` (text signal only) |"$'\n'
    LEGACY_PAIRS="${LEGACY_PAIRS} ${cls}:${short}"
  done < <(grep -oE '^import [a-zA-Z0-9_.]+;' "$f" | sed 's/^import //; s/;$//' \
           | grep -iE '\.(legacy|deprecated|compat|old)\.|Legacy|Deprecated' | sort -u)
done

# ---- OTHER RELEVANT CONTEXT: remaining docs that mention the keyword ------------------
OTHER_ROWS=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  f="${f#./}"
  is_machinery "$f" && continue
  case "$f" in "$TICKETS"|docs/adr/*) continue ;; esac
  OTHER_ROWS="${OTHER_ROWS}| Other context | \`${f}\` |"$'\n'
done < <(git ls-files -- '*.md' 2>/dev/null | while IFS= read -r t; do
           grep -qiw -- "$KEYWORD" "$t" 2>/dev/null && echo "$t"; done | sort)

# ---- UNRESOLVED: what this map cannot settle ------------------------------------------
UNRESOLVED=""
n_sources=0
for _ in $CONFIG_FILES $ADR_FILES; do n_sources=$((n_sources + 1)); done
if [ "$n_sources" -ge 2 ]; then
  UNRESOLVED="${UNRESOLVED}- Which source currently governs ${KEYWORD}? Candidates:$(for s in $CONFIG_FILES $ADR_FILES; do printf ' `%s`' "$s"; done). A map cannot settle this.\n"
fi
for pair in $LEGACY_PAIRS; do
  UNRESOLVED="${UNRESOLVED}- Is \`${pair#*:}\` a real compiled dependency of \`${pair%%:*}\`? So far this is only a text signal.\n"
done
for tf in $UNPROVEN_TESTS; do
  UNRESOLVED="${UNRESOLVED}- Is ${KEYWORD} behavior proven by any test? No line in \`${tf}\` mentions \"${KEYWORD}\".\n"
done
[ -z "$IMPL_ROWS" ] && UNRESOLVED="${UNRESOLVED}- Where would ${KEYWORD} be implemented? No candidate found.\n"

# ---- render ----------------------------------------------------------------------------
ALL_ROWS="${TASK_ROWS}${IMPL_ROWS}${CONFIG_ROWS}${ADR_ROWS}${TEST_ROWS}${LEGACY_ROWS}${OTHER_ROWS}"
{
  echo "# Context Map — \"${KEYWORD}\""
  echo ""
  if [ -z "$ALL_ROWS" ]; then
    echo "No candidate context surfaces found for \"${KEYWORD}\". Check the keyword."
  else
    echo "| Surface | Where to look |"
    echo "|---|---|"
    printf '%s' "$ALL_ROWS"
    echo ""
    echo "## Unresolved"
    echo ""
    if [ -n "$UNRESOLVED" ]; then printf '%b' "$UNRESOLVED"; else echo "- none identified by the map"; fi
  fi
  echo ""
  echo "_A routing table, not an answer. Settle each unresolved question with an evidence_"
  echo "_mechanism, or with someone who has the authority to decide it._"
} | tee "$OUT_FILE"

echo ""
echo "Saved to ${OUT_FILE}"
exit 0
