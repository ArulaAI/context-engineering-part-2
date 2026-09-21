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

# Bytecode must be current. A class file older than any source file would answer a
# question about code that no longer exists — so recompile whenever that is possible.
if [ ! -f "$CLASS" ] || [ -n "$(find src/main/java -name '*.java' -newer "$CLASS" 2>/dev/null | head -1)" ]; then
  mvn -B -q test-compile >/dev/null 2>&1 || {
    echo "authority.sh: cannot compile — bytecode evidence is unavailable, refusing to guess." >&2
    exit 3
  }
fi
[ -f "$CLASS" ] || { echo "authority.sh: no class file for ${SRC} after compiling." >&2; exit 3; }

# Fail closed: a missing jdeps must not silently look like "0 bytecode references."
# jdeps ships with every JDK 17+, but some PATH setups only expose java/jshell — e.g.
# Windows' Oracle "javapath" shim shadows the real JDK bin/ directory. Without this
# guard, tier-1 silently degrades to "grep found nothing extra," which reads exactly
# like a genuine no-dependency verdict. That is the same fail-open hazard Stage 2
# teaches you to check for in context-run.sh — this script did not used to guard
# against it.
if ! command -v jdeps >/dev/null 2>&1; then
  echo "authority.sh: jdeps not found on PATH — refusing to guess at a tier-1 verdict." >&2
  echo "jdeps ships with the JDK (17+), but some installs put a java-only shim (e.g." >&2
  echo "Windows' javapath) ahead of the real JDK bin/ directory on PATH. Find your" >&2
  echo "JDK's bin/ (java -version shows the version; check Program Files\\Java\\jdk-*\\bin" >&2
  echo "on Windows) and put it on PATH ahead of any shim, then retry." >&2
  exit 3
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
echo "    => ${N} hit(s)  ::  textual presence detected"
echo

# ── tier 1 · bytecode ───────────────────────────────────────────────────────
echo "jdeps — bytecode (tier 1)"
# Fail closed: if jdeps itself errors, "no matching line" would read exactly like "no
# dependency". Capture its exit status and refuse to answer rather than answer wrong.
JDEPS_OUT="$(jdeps -v -cp target/classes "$CLASS" 2>&1)"; JDEPS_RC=$?
if [ "$JDEPS_RC" -ne 0 ]; then
  echo "authority.sh: jdeps failed (exit ${JDEPS_RC}) — bytecode evidence unavailable." >&2
  printf '%s
' "$JDEPS_OUT" | head -5 >&2
  exit 3
fi
DEPS="$(printf '%s
' "$JDEPS_OUT" | grep -- "$SYMBOL" || true)"
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
VERDICT: no compiled dependency detected.

  ${N} textual reference(s), 0 bytecode dependencies.
  No compiled dependency from ${NAME} to ${SYMBOL}.

  Inspect the ${N} textual reference(s) separately before classifying their
  role — they may be imports, comments, string literals, or same-package
  usage that jdeps does not distinguish from absence.
EOF
  echo ""
  echo "EVIDENCE: claim=\"${NAME} depends on ${SYMBOL}\" status=rejected mechanism=jdeps bytecode_refs=0 text_refs=${N}"
  exit 0
elif [ "$D" -gt 0 ]; then
  echo "VERDICT: real dependency — ${D} bytecode reference(s). grep and jdeps agree."
  echo ""
  echo "EVIDENCE: claim=\"${NAME} depends on ${SYMBOL}\" status=verified mechanism=jdeps bytecode_refs=${D} text_refs=${N}"
  exit 0
else
  echo "VERDICT: no evidence in either tier."
  echo ""
  echo "EVIDENCE: claim=\"${NAME} depends on ${SYMBOL}\" status=rejected mechanism=jdeps bytecode_refs=0 text_refs=0"
  exit 0
fi
