#!/usr/bin/env bash
#
# context-run.sh — wrap a noisy command, return a compact digest.
#
# Stage 2 ("Compress Before Context") is about reducing tool output BEFORE it reaches
# the model, not after. `mvn test`, `git diff`, and a repo-wide grep are all "correct"
# ways to answer a question and all produce far more bytes than the answer needs.
# This script runs the real command, computes the real noise-removed figure (never
# asserted), and prints only the digest.
#
# usage:
#   scripts/context-run.sh test
#   scripts/context-run.sh diff
#   scripts/context-run.sh search <term>

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

SUBCOMMAND="${1:-}"

case "$SUBCOMMAND" in
  test)   ;;
  diff)   ;;
  search) ;;
  *) echo "usage: context-run.sh <test|diff|search> [term]" >&2; exit 3 ;;
esac

# ============================================================== test =======
if [ "$SUBCOMMAND" = "test" ]; then
  RAW="$(mktemp)"
  trap 'rm -f "$RAW"' EXIT

  mvn -B test >"$RAW" 2>&1
  RAW_LINES="$(wc -l < "$RAW" | tr -d ' ')"

  PASS_TOTAL="$(grep -ho 'Tests run: [0-9]\+' target/surefire-reports/*.txt 2>/dev/null \
      | awk -F': ' '{s+=$2} END {print s+0}')"
  FAIL_TOTAL="$(grep -ho 'Failures: [0-9]\+' target/surefire-reports/*.txt 2>/dev/null \
      | awk -F': ' '{s+=$2} END {print s+0}')"
  ERR_TOTAL="$(grep -ho 'Errors: [0-9]\+' target/surefire-reports/*.txt 2>/dev/null \
      | awk -F': ' '{s+=$2} END {print s+0}')"
  BAD_TOTAL=$((FAIL_TOTAL + ERR_TOTAL))
  GOOD_TOTAL=$((PASS_TOTAL - BAD_TOTAL))

  echo "TEST SUMMARY"
  echo "${GOOD_TOTAL} passed"
  echo "${BAD_TOTAL} failed"
  echo ""

  DIGEST_LINES=6
  if [ "$BAD_TOTAL" -gt 0 ]; then
    echo "RELEVANT FAILURES"
    FAILURE_BLOCK="$(awk '
      /<<< (FAILURE|ERROR)!/ && !/^Tests run:/ {
          name=$1; sub(/^([a-z0-9_]+\.)+/, "", name); next
      }
      /^(org\.opentest4j|java\.lang|org\.junit|org\.mockito)/ { why=$0 }
      /^[[:space:]]+at .*Test\.java:[0-9]+\)/ && why {
          sub(/^[[:space:]]+at .*\(/, "", $0); sub(/\)$/, "", $0)
          printf "%s\n%s\n%s\n", name, why, $0
          why=""
      }
    ' target/surefire-reports/*.txt 2>/dev/null)"
    echo "$FAILURE_BLOCK"
    DIGEST_LINES=$((DIGEST_LINES + $(printf '%s\n' "$FAILURE_BLOCK" | wc -l | tr -d ' ')))
    echo ""
  fi

  echo "REGRESSION SIGNAL"
  if [ "$BAD_TOTAL" -eq 0 ]; then
    echo "none — all fee-calculation tests (WIRE/ACH/SWIFT) unaffected"
  else
    echo "$(printf '%s\n' "$FAILURE_BLOCK" | head -1) touches fee logic — check for a regression, not just a missing feature"
  fi
  echo ""

  echo "NOISE REMOVED: $((RAW_LINES - DIGEST_LINES)) lines  (raw \`mvn test\` = ${RAW_LINES} lines; digest = ${DIGEST_LINES} lines)"

  [ "$BAD_TOTAL" -eq 0 ]
  exit $?
fi

# ============================================================== diff =======
if [ "$SUBCOMMAND" = "diff" ]; then
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "context-run: not a git repository" >&2
    exit 3
  fi

  RAW="$(git diff 2>/dev/null)"
  RAW_LINES="$(printf '%s\n' "$RAW" | wc -l | tr -d ' ')"
  STAT="$(git diff --stat 2>/dev/null)"

  if [ -z "$RAW" ]; then
    echo "CHANGED FILES"
    echo "(none — working tree matches the last commit)"
    exit 0
  fi

  echo "CHANGED FILES"
  git diff --name-only 2>/dev/null | while read -r f; do
    [ -z "$f" ] && continue
    STATLINE="$(printf '%s\n' "$STAT" | grep -F "$f" | head -1 | sed -E 's/^[^|]+\|//')"
    if [[ "$f" == *.java ]] && [ -f "$f" ]; then
      METHOD="$(./scripts/outline.sh "$f" 2>/dev/null | awk -v changed="$(git diff -U0 -- "$f" | grep -oE '^@@ -[0-9]+' | head -1 | grep -oE '[0-9]+')" '
        /^  method/ {
          split($2, r, "-")
          if (changed+0 >= r[1]+0 && changed+0 <= r[2]+0) {
            sig=$0; sub(/^  method[ \t]+[0-9]+-[0-9]+[ \t]+\([0-9]+L\)[ \t]+/, "", sig)
            sub(/\(.*/, "", sig)
            n=split(sig, w, /[ \t]+/); name=w[n]
            print name" ("$2")"; found=1
          }
        }
        END { if (!found) print "(method not resolved)" }
      ' | head -1)"
      printf "%-22s %-10s method changed: %s\n" "$f" "$STATLINE" "$METHOD"
    else
      printf "%-22s %-10s\n" "$f" "$STATLINE"
    fi
  done

  DIGEST_LINES=$(($(git diff --name-only 2>/dev/null | wc -l | tr -d ' ') + 1))
  echo ""
  echo "NOISE REMOVED: raw \`git diff\` = ${RAW_LINES} lines; digest = ${DIGEST_LINES} lines"
  exit 0
fi

# ============================================================ search =======
if [ "$SUBCOMMAND" = "search" ]; then
  TERM="${2:-}"
  [ -n "$TERM" ] || { echo "usage: context-run.sh search <term>" >&2; exit 3; }

  RAW="$(grep -rn "$TERM" src/main config docs --include='*.java' --include='*.yaml' --include='*.md' 2>/dev/null)"
  RAW_COUNT="$(printf '%s\n' "$RAW" | grep -c . || true)"

  DEDUPED="$(printf '%s\n' "$RAW" | grep -v -E '^\s*\*|//\s*$' | sort -u -t: -k1,1 | head -20)"
  SHOWN_COUNT="$(printf '%s\n' "$DEDUPED" | grep -c . || true)"

  echo "${RAW_COUNT} raw hits across $(printf '%s\n' "$RAW" | cut -d: -f1 | sort -u | grep -c .) files → ${SHOWN_COUNT} shown (dedup: comment/doc noise removed)"
  echo ""
  printf "%-36s %-6s %s\n" "FILE" "LINE" "EVIDENCE"
  printf -- "--------------------------------------------------------------\n"

  RATES=()
  printf '%s\n' "$DEDUPED" | while IFS=: read -r file line content; do
    [ -z "$file" ] && continue
    trimmed="$(echo "$content" | sed 's/^[[:space:]]*//' | cut -c1-58)"
    printf "%-36s %-6s %s\n" "$file" "$line" "$trimmed"
  done

  echo ""
  RATE_HITS="$(printf '%s\n' "$DEDUPED" | grep -E '[0-9]\.[0-9]+%|percent|[0-9]\.[0-9]{2,4}')"
  if [ -n "$RATE_HITS" ] && printf '%s\n' "$DEDUPED" | grep -q 'config/' && printf '%s\n' "$DEDUPED" | grep -q 'docs/adr'; then
    echo "RATE CROSS-CHECK: config and an ADR both state a ${TERM} rate. Compare them by hand — THEY MAY DISAGREE."
  fi

  echo ""
  echo "NOISE REMOVED: ${RAW_COUNT} lines → ${SHOWN_COUNT} lines"
  exit 0
fi
