#!/usr/bin/env bash
#
# test-gap.sh — answer two questions about the codebase without sending the codebase.
#
#   1. Which public methods on a class have no test referencing them?
#   2. Where is fee logic computed anywhere in the tree?
#
# Stage 2 ("Compress Before Context") contrasts this with the naive approach of attaching
# every source and test file and asking the model to work it out. The model orchestrates;
# the script does the data processing; only this digest re-enters the context window.
#
# Output is GFM markdown (renders as real tables in Copilot Chat), printed to stdout and
# saved to .context/test-gap-<ClassName>.md so it survives after the chat scrolls.
#
# Usage:
#   ./scripts/test-gap.sh
#   ./scripts/test-gap.sh src/main/java/com/meridian/payments/PaymentService.java
#
# No dependencies beyond bash + awk + grep. Works on macOS and Linux.

set -euo pipefail

TARGET="${1:-src/main/java/com/meridian/payments/PaymentService.java}"
MAIN_DIR="src/main/java"
TEST_DIR="src/test/java"
OUT_DIR=".context"

if [ ! -f "$TARGET" ]; then
  echo "test-gap: no such file: $TARGET" >&2
  exit 2
fi

CLASS_NAME="$(basename "$TARGET" .java)"
OUT_FILE="${OUT_DIR}/test-gap-${CLASS_NAME}.md"

# Escape a literal pipe so a grepped line can never break a markdown table row.
esc() { printf '%s' "$1" | sed 's/|/\\|/g'; }

mkdir -p "$OUT_DIR"

# ---------------------------------------------------------------- public methods
# Reuse the same brace-depth walk as outline.sh, but keep only public members
# and emit "name<TAB>lines".
methods="$(
  awk '
    function tidy(s) {
      gsub(/^[ \t]+/, "", s); gsub(/[ \t]+$/, "", s)
      gsub(/[ \t]*\{[ \t]*$/, "", s); gsub(/[ \t]+/, " ", s)
      return s
    }
    BEGIN { depth = 0; in_method = 0; in_comment = 0; pending = 0 }
    { line = $0; gsub(/"([^"\\]|\\.)*"/, "\"\"", line); sub(/\/\/.*/, "", line) }
    in_comment { if (line ~ /\*\//) in_comment = 0; next }
    line ~ /\/\*/ && line !~ /\*\// { in_comment = 1; next }
    {
      opens = gsub(/\{/, "{", line); closes = gsub(/\}/, "}", line)
      if (pending) {
        sig = sig " " tidy(line)
        if (opens > 0) { in_method = 1; pending = 0 }
        else if (line ~ /;[ \t]*$/) pending = 0
      }
      else if (depth == 1 && !in_method && line ~ /^[ \t]*public[ \t]/ && line ~ /\(/ &&
               line !~ /^[ \t]*(if|for|while|switch|catch|try|else|do|return|new)[ \t(]/) {
        if (opens > 0)                 { sig = tidy(line); start = NR; in_method = 1 }
        else if (line !~ /;[ \t]*$/)   { sig = tidy(line); start = NR; pending = 1 }
      }
      depth += opens - closes
      if (in_method && depth <= 1 && closes > 0) {
        # method name = last identifier before the "("
        head = sig; sub(/\(.*/, "", head)
        n = split(head, parts, /[ \t]+/); name = parts[n]
        printf "%s\t%s-%s\n", name, start, NR
        in_method = 0
      }
    }
  ' "$TARGET"
)"

# Strip line and block comments from the test sources ONCE, so that a method name
# merely mentioned in a comment is not mistaken for a test that exercises it.
# (This is not a hypothetical: the baseline suite lists the uncovered methods in a
# trailing comment block, which naive grep counts as coverage.)
TEST_SRC="$(
  find "$TEST_DIR" -name '*.java' -exec cat {} + 2>/dev/null \
    | sed 's,//.*,,' \
    | awk '/\/\*/ {inc=1} inc {if (/\*\//) inc=0; next} {print}'
)"

{
  echo "# Test Coverage Gap — ${CLASS_NAME}"
  echo ""
  echo "| Method | Lines | Refs | Status |"
  echo "|---|---|---|---|"

  uncovered=0
  total=0
  while IFS=$'\t' read -r name lines; do
    [ -z "$name" ] && continue
    # A constructor is not a behaviour to cover; skip it.
    [ "$name" = "$CLASS_NAME" ] && continue
    total=$((total + 1))
    # `|| true` matters: grep exits 1 on zero matches, which under `set -o pipefail`
    # would abort the script at the first uncovered method — silently hiding the gaps.
    refs=$(printf '%s\n' "$TEST_SRC" | { grep -o -E "[^A-Za-z0-9_]${name}[[:space:]]*\(" || true; } | wc -l | tr -d ' ')
    if [ "$refs" -eq 0 ]; then
      status="**NO COVERAGE**"
      uncovered=$((uncovered + 1))
    else
      status="covered"
    fi
    echo "| \`${name}\` | ${lines} | ${refs} | ${status} |"
  done <<< "$methods"

  echo ""
  echo "**${uncovered} of ${total} public methods have no test referencing them.**"
  echo ""

  # ---------------------------------------------------------------- fee logic
  echo "## Fee Logic — every computation site in \`${MAIN_DIR}\`"
  echo ""
  echo "| File | Line | Evidence |"
  echo "|---|---|---|"

  grep -rn -E 'calculateFee|0\.0025|0\.005|0\.015|0\.0035|2\.00|\bWIRE\b|\bACH\b|\bSWIFT\b|\bRTP\b' "$MAIN_DIR" \
    --include='*.java' 2>/dev/null \
    | grep -v -E '^\s*\*|//\s*$' \
    | while IFS=: read -r file line content; do
        trimmed="$(echo "$content" | sed 's/^[[:space:]]*//' | cut -c1-70)"
        echo "| \`${file#$MAIN_DIR/}\` | ${line} | \`$(esc "$trimmed")\` |"
      done

  echo ""
  echo "## Fee Rates Found in Source"
  echo "_(these must agree with \`config/fee-schedule.yaml\`)_"
  echo ""
  RATE_LINES="$(grep -rn -E 'WIRE|RTP' "$MAIN_DIR" --include='*.java' -A2 2>/dev/null \
    | grep -E 'multiply|BigDecimal\.valueOf|\* *0\.' || true)"
  if [ -n "$RATE_LINES" ]; then
    echo '```'
    printf '%s\n' "$RATE_LINES"
    echo '```'
  else
    echo "_(none found)_"
  fi
  echo ""
  echo "Digest complete. Paste ONLY this output back into chat — not the files."
} | tee "$OUT_FILE"

echo ""
echo "Saved to ${OUT_FILE}"
