#!/usr/bin/env bash
# authority.sh — not all evidence is equal.
#
# Lab 1 taught: use the cheapest primitive that can answer.
# This corrects it to: use the most AUTHORITATIVE primitive that can answer.
#
#   bytecode / compiler  >  AST / parser  >  regex / text  >  semantic search  >  model recall
#
# The two tiers below disagree about this codebase. One of them is wrong, and it
# is not the compiler.
#
# usage: scripts/authority.sh [Symbol] [path/to/Source.java]

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

SYMBOL="${1:-LegacyPaymentUtils}"
SRC="${2:-src/main/java/com/meridian/payments/PaymentService.java}"
NAME="$(basename "${SRC%.java}")"

REL="${SRC#src/main/java/}"
CLASS="target/classes/${REL%.java}.class"

if [ ! -f "$CLASS" ]; then
  mvn -B -q test-compile >/dev/null 2>&1 || { echo "cannot compile; jdeps needs bytecode"; exit 3; }
fi

echo "Q: does ${NAME} depend on ${SYMBOL}?"
echo

# ── tier 3 · text search ────────────────────────────────────────────────────
echo "grep — text (tier 3)"
HITS="$(grep -n "$SYMBOL" "$SRC" 2>/dev/null || true)"
if [ -n "$HITS" ]; then
  N="$(printf '%s\n' "$HITS" | grep -c .)"
  printf '%s\n' "$HITS" | sed 's/^/    /'
else
  N=0
fi
echo "    => ${N} hit(s)  ::  reads as A LIVE DEPENDENCY"
echo

# ── tier 1 · bytecode ───────────────────────────────────────────────────────
echo "jdeps — bytecode (tier 1)"
DEPS="$(jdeps -v -cp target/classes "$CLASS" 2>/dev/null | grep "$SYMBOL" || true)"
if [ -n "$DEPS" ]; then
  D="$(printf '%s\n' "$DEPS" | grep -c .)"
  printf '%s\n' "$DEPS" | sed 's/^/    /'
else
  D=0
fi
echo "    => ${D} bytecode reference(s)"
echo

# ── verdict ─────────────────────────────────────────────────────────────────
if [ "$N" -gt 0 ] && [ "$D" -eq 0 ]; then
  cat <<EOF
VERDICT: the search result is a FALSE POSITIVE.

  ${N} textual hits, 0 bytecode dependencies. The import is dead and the rest
  are comments. The duplication is copy-paste, not a call — so "remove the
  dependency" is the wrong ticket. The compiler disproved the search for free.

  A model asked the same question reads the same ${N} lines and agrees with grep.
EOF
  exit 0
elif [ "$D" -gt 0 ]; then
  echo "VERDICT: real dependency — ${D} bytecode reference(s). grep and jdeps agree."
  exit 0
else
  echo "VERDICT: no evidence in either tier."
  exit 0
fi
