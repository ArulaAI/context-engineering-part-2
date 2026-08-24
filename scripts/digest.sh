#!/usr/bin/env bash
# digest.sh — the shape of a class, from the compiler.
#
# `javap` reads bytecode. It cannot be fooled by a commented-out method, and it
# cannot miss one your regex didn't anticipate. A hand-rolled outline script
# approximates; this one knows.
#
# It is also already installed — it ships with the JDK. Nothing to add, nothing
# to review, nothing to keep in sync with the language.
#
# usage: scripts/digest.sh path/to/Source.java

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

SRC="${1:-src/main/java/com/meridian/payments/PaymentService.java}"
[ -f "$SRC" ] || { echo "no such file: $SRC" >&2; exit 3; }

REL="${SRC#src/main/java/}"
CLASS="target/classes/${REL%.java}.class"
[ -f "$CLASS" ] || mvn -B -q test-compile >/dev/null 2>&1

SRC_LINES="$(wc -l < "$SRC" | tr -d ' ')"

javap -p "$CLASS" 2>/dev/null \
  | sed -E 's/^  //; s/java\.lang\.//g; s/java\.math\.//g; s/java\.util\.//g; s/com\.meridian\.payments\.[a-z]*\.?//g' \
  | grep -v '^Compiled from' \
  | sed 's/;$//'

DIGEST_LINES="$(javap -p "$CLASS" 2>/dev/null | grep -vc '^Compiled from')"
echo
echo "-- ${DIGEST_LINES} lines describing a ${SRC_LINES}-line file"
