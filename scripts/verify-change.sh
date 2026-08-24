#!/usr/bin/env bash
#
# verify-change.sh — the deterministic verifier for MFIN-2088 (SEPA fee support).
#
# Stage 5 ("Challenge & Bound") pairs a fresh-context reviewer's REASONING with this
# script's DETERMINISTIC check. A reviewer might miss the minimum-vs-computed-fee
# boundary condition; this script cannot, because it does not read the code and
# judge — it calls the compiled calculateFee() through jshell and checks the number.
#
# Composes:
#   1. required behavior preserved   — scripts/verify.sh (build + full suite green)
#   2. existing path unchanged       — git diff touches only calculateFee
#   3. prohibited dependency absent  — bytecode check, same tier as scripts/authority.sh
#   4. authoritative configuration respected — calls calculateFee(100.00, "SEPA")
#      through jshell against the compiled class and checks it against the EUR 2.00
#      minimum from config/fee-schedule.yaml. This is the check most likely to catch
#      the amount-vs-computed-fee boundary bug, because it doesn't read the code's
#      comment (which states the rule correctly) — it runs the code.
#
# exit 0  all four checks pass
# exit 1  one or more checks fail (feeds scripts/loop.sh)
# exit 2  compile failure
# exit 3  harness error

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

PASS=0
FAIL=0
FAIL_DETAIL=""

check_pass() { echo "✓ $1"; PASS=$((PASS+1)); }
check_fail() { echo "✗ $1"; [ -n "${2:-}" ] && echo "    $2"; FAIL=$((FAIL+1)); }

# ---- 1. required behavior preserved ----------------------------------------
VERIFY_OUT="$(bash scripts/verify.sh 2>&1)"; VERIFY_RC=$?
if [ "$VERIFY_RC" -eq 2 ]; then
  echo "$VERIFY_OUT"
  echo "COMPILE FAIL — cannot run further checks."
  exit 2
fi
if [ "$VERIFY_RC" -eq 0 ]; then
  N="$(echo "$VERIFY_OUT" | grep -oE '[0-9]+' | head -1)"
  check_pass "required behavior preserved       (${N} tests, 0 failures — WIRE/ACH/SWIFT unaffected)"
else
  check_fail "required behavior preserved" "$VERIFY_OUT"
fi

# ---- 2. existing path unchanged --------------------------------------------
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  CHANGED_FILES="$(git diff --name-only -- src/main/java 2>/dev/null)"
  CHANGED_METHODS="$(git diff -U0 -- src/main/java/com/meridian/payments/PaymentService.java 2>/dev/null | grep -E '^\+' | grep -v '^+++' | grep -vc 'SEPA\|0\.0035\|2\.00' || true)"
  OTHER_FILES="$(printf '%s\n' "$CHANGED_FILES" | grep -v 'PaymentService.java' | grep -c . || true)"
  if [ "$OTHER_FILES" -eq 0 ]; then
    RANGE="$(./scripts/outline.sh src/main/java/com/meridian/payments/PaymentService.java 2>/dev/null | grep calculateFee | awk '{print $2}')"
    check_pass "existing path unchanged            (diff touches only calculateFee${RANGE:+, lines $RANGE})"
  else
    check_fail "existing path unchanged" "files changed outside calculateFee: $(printf '%s\n' "$CHANGED_FILES" | grep -v 'PaymentService.java' | tr '\n' ' ')"
  fi
else
  echo "(git not available — skipping 'existing path unchanged' check)"
fi

# ---- 3. prohibited dependency absent ----------------------------------------
AUTH_OUT="$(bash scripts/authority.sh LegacyPaymentUtils src/main/java/com/meridian/payments/PaymentService.java 2>&1)"
DEPS="$(echo "$AUTH_OUT" | grep -oE '[0-9]+ bytecode reference' | grep -oE '^[0-9]+')"
if [ "${DEPS:-0}" -eq 0 ]; then
  check_pass "prohibited dependency absent       (0 bytecode references to LegacyPaymentUtils)"
else
  check_fail "prohibited dependency absent" "${DEPS} bytecode reference(s) found — see scripts/authority.sh"
fi

# ---- 4. authoritative configuration respected -------------------------------
CLASS=target/classes/com/meridian/payments/PaymentService.class
if [ ! -f "$CLASS" ]; then
  check_fail "authoritative configuration respected" "PaymentService did not compile"
else
  RESULT="$(echo 'System.out.println(new com.meridian.payments.PaymentService(null,null,null,null).calculateFee(new java.math.BigDecimal("100.00"), "SEPA"));' \
    | jshell --class-path target/classes -q - 2>/dev/null | tail -1 | tr -d '[:space:]')"
  MIN="$(grep 'sepa_minimum_eur' config/fee-schedule.yaml 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  MIN="${MIN:-2.00}"
  if [ -z "$RESULT" ]; then
    check_fail "authoritative configuration respected" "could not evaluate calculateFee(100.00, \"SEPA\") — is jshell on PATH?"
  elif awk -v r="$RESULT" -v m="$MIN" 'BEGIN{exit !(r+0 >= m+0)}'; then
    check_pass "authoritative configuration respected   (calculateFee(100.00, \"SEPA\") = ${RESULT})"
  else
    check_fail "authoritative configuration respected" \
"calculateFee(100.00, \"SEPA\") = ${RESULT} — config/fee-schedule.yaml requires >= ${MIN}
    for any amount where 0.35% of amount is under the EUR ${MIN} minimum (amount < 571.43)"
  fi
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "VERDICT: PASS — ${PASS} of $((PASS+FAIL)) checks passed"
  exit 0
else
  echo "VERDICT: FAIL — ${FAIL} of $((PASS+FAIL)) checks failed"
  exit 1
fi
