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

OUT_DIR=".context"
mkdir -p "$OUT_DIR"

# Escape a literal pipe so a grepped line can never break a markdown table row.
esc() { printf '%s' "$1" | sed 's/|/\\|/g'; }

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
  MVN_RC=$?
  RAW_LINES="$(wc -l < "$RAW" | tr -d ' ')"

  HAVE_REPORTS=0
  ls target/surefire-reports/*.txt >/dev/null 2>&1 && HAVE_REPORTS=1

  PASS_TOTAL="$(grep -ho 'Tests run: [0-9]\+' target/surefire-reports/*.txt 2>/dev/null \
      | awk -F': ' '{s+=$2} END {print s+0}')"
  FAIL_TOTAL="$(grep -ho 'Failures: [0-9]\+' target/surefire-reports/*.txt 2>/dev/null \
      | awk -F': ' '{s+=$2} END {print s+0}')"
  ERR_TOTAL="$(grep -ho 'Errors: [0-9]\+' target/surefire-reports/*.txt 2>/dev/null \
      | awk -F': ' '{s+=$2} END {print s+0}')"
  BAD_TOTAL=$((FAIL_TOTAL + ERR_TOTAL))
  GOOD_TOTAL=$((PASS_TOTAL - BAD_TOTAL))

  # R1 — make Maven exit code authoritative; prevent stale-report false-green.
  #
  # Three early-exit guards, in order of severity:
  #
  # (a) Maven failed AND stale reports are on disk.
  #     The reports we just parsed belong to a prior successful run; reading
  #     them would produce a false PASS.  Bail out immediately.
  if [ "$MVN_RC" -ne 0 ] && [ "$HAVE_REPORTS" -eq 1 ]; then
    echo "TEST SUMMARY"
    echo "BUILD FAILED — mvn -B test exited ${MVN_RC} (stale surefire reports on disk ignored)"
    echo ""
    echo "last 20 lines of \`mvn -B test\` output:"
    tail -20 "$RAW" | sed 's/^/  /'
    echo ""
    echo "NOISE REMOVED: n/a — build failed, stale reports not used"
    exit 1
  fi
  #
  # (b) Maven failed AND no reports exist at all.
  #     Build or compile error before surefire even ran — also a hard failure.
  if [ "$MVN_RC" -ne 0 ] && [ "$HAVE_REPORTS" -eq 0 ]; then
    echo "TEST SUMMARY"
    echo "BUILD FAILED — mvn -B test exited ${MVN_RC} before producing any surefire report"
    echo ""
    echo "last 20 lines of \`mvn -B test\` output:"
    tail -20 "$RAW" | sed 's/^/  /'
    echo ""
    echo "NOISE REMOVED: n/a — build did not complete, nothing to compress"
    exit 1
  fi
  #
  # (c) Maven exited 0 but no reports were generated.
  #     Surefire was skipped or a plugin misconfiguration suppressed output;
  #     treat as failure so "0 tests / 0 failures" is never a silent green.
  if [ "$MVN_RC" -eq 0 ] && [ "$HAVE_REPORTS" -eq 0 ]; then
    echo "TEST SUMMARY"
    echo "BUILD FAILED — mvn -B test exited 0 but produced no surefire reports (surefire skipped?)"
    echo ""
    echo "NOISE REMOVED: n/a — no reports to parse"
    exit 1
  fi
  #
  # (d) Reports exist but contain no parseable test data — covers zero-byte,
  #     binary-garbage, or permission-denied files.
  if [ "$PASS_TOTAL" -eq 0 ] && [ "$FAIL_TOTAL" -eq 0 ] && [ "$ERR_TOTAL" -eq 0 ]; then
    echo "TEST SUMMARY"
    echo "BUILD FAILED — surefire reports exist but contain no parseable test data"
    echo ""
    echo "NOISE REMOVED: n/a — reports unreadable"
    exit 1
  fi

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
    echo "none — existing test suite remains green"
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
  # --numstat (not --stat): tab-separated "added\tremoved\tpath", full path, never
  # abbreviated. `git diff --stat` truncates long paths (e.g. to ".../PaymentService.java")
  # once several files are in the diff, which silently breaks a full-path grep match —
  # exactly the file Stage 5.1 most needs a correct stat for.
  STAT="$(git diff --numstat 2>/dev/null)"
  OUT_FILE="${OUT_DIR}/context-run-diff.md"

  if [ -z "$RAW" ]; then
    { echo "# Context Run — diff"; echo ""; echo "**CHANGED FILES**"; echo ""; echo "(none — working tree matches the last commit)"; } | tee "$OUT_FILE"
    echo ""
    echo "Saved to ${OUT_FILE}"
    exit 0
  fi

  {
    echo "# Context Run — diff"
    echo ""
    echo "| File | Diff Stat | Method Changed |"
    echo "|---|---|---|"
    git diff --name-only 2>/dev/null | while read -r f; do
      [ -z "$f" ] && continue
      STATLINE="$(printf '%s\n' "$STAT" | awk -F'\t' -v f="$f" '$3==f {print "+"$1" -"$2; exit}')"
      if [[ "$f" == *.java ]] && [ -f "$f" ]; then
        METHOD="$(./scripts/outline.sh "$f" 2>/dev/null | awk -v changed="$(git diff -U0 -- "$f" | grep -oE '^@@ -[0-9]+' | head -1 | grep -oE '[0-9]+')" '
          /^\| method \|/ {
            split($0, cols, "|")
            range = cols[3]; gsub(/^[ \t]+|[ \t]+$/, "", range); sub(/ .*/, "", range)
            split(range, r, "-")
            if (changed+0 >= r[1]+0 && changed+0 <= r[2]+0) {
              sig = cols[4]; gsub(/^[ \t]+|[ \t]+$/, "", sig); gsub(/`/, "", sig)
              sub(/\(.*/, "", sig)
              n = split(sig, w, /[ \t]+/); name = w[n]
              print name" ("range")"; found=1
            }
          }
          END { if (!found) print "(method not resolved)" }
        ' | head -1)"
        echo "| \`${f}\` | $(esc "$STATLINE") | ${METHOD} |"
      else
        echo "| \`${f}\` | $(esc "$STATLINE") | — |"
      fi
    done

    DIGEST_LINES=$(($(git diff --name-only 2>/dev/null | wc -l | tr -d ' ') + 1))
    echo ""
    echo "NOISE REMOVED: raw \`git diff\` = ${RAW_LINES} lines; digest = ${DIGEST_LINES} lines"
  } | tee "$OUT_FILE"

  echo ""
  echo "Saved to ${OUT_FILE}"
  exit 0
fi

# ============================================================ search =======
if [ "$SUBCOMMAND" = "search" ]; then
  TERM="${2:-}"
  [ -n "$TERM" ] || { echo "usage: context-run.sh search <term>" >&2; exit 3; }

  TERM_SAFE="$(printf '%s' "$TERM" | tr -c 'A-Za-z0-9_-' '_')"
  OUT_FILE="${OUT_DIR}/context-run-search-${TERM_SAFE}.md"

  RAW="$(grep -rn "$TERM" src/main config docs/adr docs/JIRA_TICKETS.md --include='*.java' --include='*.yaml' --include='*.md' 2>/dev/null)"
  RAW_COUNT="$(printf '%s\n' "$RAW" | grep -c . || true)"

  DEDUPED="$(printf '%s\n' "$RAW" | grep -v -E '^\s*\*|//\s*$' | sort -u -t: -k1,1 | head -20)"
  SHOWN_COUNT="$(printf '%s\n' "$DEDUPED" | grep -c . || true)"

  {
    echo "# Context Run — search \"${TERM}\""
    echo ""
    echo "${RAW_COUNT} raw hits across $(printf '%s\n' "$RAW" | cut -d: -f1 | sort -u | grep -c .) files → ${SHOWN_COUNT} shown (dedup: comment/doc noise removed)"
    echo ""
    echo "| File | Line | Evidence |"
    echo "|---|---|---|"

    printf '%s\n' "$DEDUPED" | while IFS=: read -r file line content; do
      [ -z "$file" ] && continue
      trimmed="$(echo "$content" | sed 's/^[[:space:]]*//' | cut -c1-70)"
      echo "| \`${file}\` | ${line} | \`$(esc "$trimmed")\` |"
    done

    echo ""
    RATE_HITS="$(printf '%s\n' "$DEDUPED" | grep -E '[0-9]\.[0-9]+%|percent|[0-9]\.[0-9]{2,4}')"
    if [ -n "$RATE_HITS" ] && printf '%s\n' "$DEDUPED" | grep -q 'config/' && printf '%s\n' "$DEDUPED" | grep -q 'docs/adr'; then
      echo "> **RATE CROSS-CHECK:** config and an ADR both state a ${TERM} rate. Compare them by hand — THEY MAY DISAGREE."
      echo ""
    fi

    echo "NOISE REMOVED: ${RAW_COUNT} lines → ${SHOWN_COUNT} lines"
  } | tee "$OUT_FILE"

  echo ""
  echo "Saved to ${OUT_FILE}"
  exit 0
fi
