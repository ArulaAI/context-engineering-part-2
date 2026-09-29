#!/usr/bin/env bash
#
# apply-reference.sh — apply the reference answer for MFIN-2088.
#
# The lab's teaching does not depend on who types the code. It depends on the approved
# rule being implemented EXACTLY once, so that every check downstream — the verifier's
# jshell call, the injected fault, the test evidence, the loop's verdict hash — reports
# the same numbers on every run. That is what this script guarantees.
#
# The answer lives in reference/, outside src/, so it never compiles into the baseline and
# never pollutes a participant's context before they reach it.
#
#   implementation  splice reference/calculateFee.java over PaymentService.calculateFee
#   tests           append reference/rtp-tests.java's two test methods to PaymentServiceTest
#   both            implementation, then tests
#   status          report what has been applied
#
# usage: scripts/apply-reference.sh implementation | tests | both | status
# exit 0 ok · 2 bad usage · 3 wrong state (already applied / target not found)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

SRC="src/main/java/com/meridian/payments/PaymentService.java"
TEST="src/test/java/com/meridian/payments/PaymentServiceTest.java"
REF_IMPL="reference/calculateFee.java"
REF_TEST="reference/rtp-tests.java"

impl_applied() { grep -q 'paymentType.equals("RTP")' "$SRC"; }
tests_applied() { grep -q 'calculateFee_rtpMinimumAppliesBelowThreshold' "$TEST"; }

apply_impl() {
  [ -f "$REF_IMPL" ] || { echo "apply-reference: $REF_IMPL is missing." >&2; exit 3; }
  if impl_applied; then
    echo "implementation: already applied (calculateFee has an RTP branch)."
    return 0
  fi
  RANGE="$(bash scripts/lib/methods.sh "$SRC" | awk -F'\t' '$1=="calculateFee"{print $2" "$3; exit}')"
  [ -n "$RANGE" ] || { echo "apply-reference: could not locate calculateFee in $SRC" >&2; exit 3; }
  set -- $RANGE; START="$1"; END="$2"
  {
    head -n $((START - 1)) "$SRC"
    cat "$REF_IMPL"
    tail -n +$((END + 1)) "$SRC"
  } > "$SRC.tmp" && mv "$SRC.tmp" "$SRC"
  echo "implementation: applied the approved RTP rule to PaymentService.calculateFee"
  echo "                (0.35% of the amount, minimum USD 2.00, compared against the fee)."
}

apply_tests() {
  [ -f "$REF_TEST" ] || { echo "apply-reference: $REF_TEST is missing." >&2; exit 3; }
  if tests_applied; then
    echo "tests: already applied (two RTP test methods are present)."
    return 0
  fi
  # Insert before the final closing brace of the class, keeping the comment block that
  # documents the deliberate gaps where it is.
  LAST="$(grep -n '^}' "$TEST" | tail -1 | cut -d: -f1)"
  [ -n "$LAST" ] || { echo "apply-reference: could not find the end of the class in $TEST" >&2; exit 3; }
  {
    head -n $((LAST - 1)) "$TEST"
    cat "$REF_TEST"
    tail -n +"$LAST" "$TEST"
  } > "$TEST.tmp" && mv "$TEST.tmp" "$TEST"
  echo "tests: added 2 permanent tests for the approved RTP rule to PaymentServiceTest."
}

case "${1:-}" in
  implementation) apply_impl ;;
  tests)          apply_tests ;;
  both)           apply_impl; apply_tests ;;
  status)
    impl_applied  && echo "implementation: applied" || echo "implementation: not applied"
    tests_applied && echo "tests:          applied" || echo "tests:          not applied"
    ;;
  *) echo "usage: apply-reference.sh implementation | tests | both | status" >&2; exit 2 ;;
esac
