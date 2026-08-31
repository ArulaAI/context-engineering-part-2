#!/usr/bin/env bash
#
# verify-change.sh — the deterministic verifier for MFIN-2088 (RTP fee support).
#
# Stage 5 ("Challenge & Bound") pairs a fresh-context reviewer's REASONING with this
# script's DETERMINISTIC check. A reviewer might miss the minimum-vs-computed-fee
# boundary condition; this script cannot, because it does not read the code and
# judge — it calls the compiled calculateFee() through jshell and checks the number.
#
# Composes:
#   1. required behavior preserved   — scripts/verify.sh (build + full suite green)
#   2. existing path unchanged       — no Java source outside PaymentService.java changed
#   3. prohibited dependency absent  — bytecode check, same tier as scripts/authority.sh
#   4. authoritative configuration respected — calls calculateFee(100.00, "RTP")
#      through jshell against the compiled class and checks it against the USD 2.00
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
  check_pass "required behavior preserved       (${N} tests, 0 failures — existing test suite remains green)"
else
  check_fail "required behavior preserved" "$VERIFY_OUT"
fi

# ---- 2. existing path unchanged --------------------------------------------
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  CHANGED_FILES="$(git diff HEAD --name-only -- src/main/java 2>/dev/null)"
  OTHER_FILES="$(printf '%s\n' "$CHANGED_FILES" | grep -v 'PaymentService.java' | grep -c . || true)"
  if [ "$OTHER_FILES" -eq 0 ]; then
    RANGE="$(./scripts/outline.sh src/main/java/com/meridian/payments/PaymentService.java 2>/dev/null | grep calculateFee | awk '{print $2}')"
    check_pass "no Java source outside PaymentService.java changed${RANGE:+ (calculateFee at lines $RANGE)}"
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
  RESULT="$(echo 'System.out.println(new com.meridian.payments.PaymentService(null,null,null,null).calculateFee(new java.math.BigDecimal("100.00"), "RTP"));' \
    | jshell --class-path target/classes -q - 2>/dev/null | tail -1 | tr -d '[:space:]')"
  # Second amount, well above the minimum-binding range: catches an implementation that
  # hardcodes the floor instead of computing 0.35% of amount.
  RESULT_HIGH="$(echo 'System.out.println(new com.meridian.payments.PaymentService(null,null,null,null).calculateFee(new java.math.BigDecimal("10000.00"), "RTP"));' \
    | jshell --class-path target/classes -q - 2>/dev/null | tail -1 | tr -d '[:space:]')"
  MIN="$(grep 'rtp_minimum_usd' config/fee-schedule.yaml 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  PCT="$(grep 'rtp_percent' config/fee-schedule.yaml 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  EXPECTED_LOW="$(awk -v a=100.00 -v p="$PCT" -v m="$MIN" 'BEGIN{f=a*p; if(f<m) f=m; printf "%.2f", f}')"
  EXPECTED_HIGH="$(awk -v a=10000.00 -v p="$PCT" -v m="$MIN" 'BEGIN{f=a*p; if(f<m) f=m; printf "%.2f", f}')"
  if [ -z "$MIN" ] || [ -z "$PCT" ]; then
    check_fail "authoritative configuration respected" "cannot read rtp_minimum_usd/rtp_percent from config/fee-schedule.yaml"
  elif [ -z "$RESULT" ] || [ -z "$RESULT_HIGH" ]; then
    check_fail "authoritative configuration respected" "could not evaluate calculateFee(...) — is jshell on PATH?"
  elif ! awk -v r="$RESULT" -v e="$EXPECTED_LOW" 'BEGIN{d=r-e; if(d<0)d=-d; exit !(d<0.01)}'; then
    check_fail "authoritative configuration respected" \
"calculateFee(100.00, \"RTP\") = ${RESULT} — expected ${EXPECTED_LOW} (max(${PCT} of amount, USD ${MIN}))"
  elif ! awk -v r="$RESULT_HIGH" -v e="$EXPECTED_HIGH" 'BEGIN{d=r-e; if(d<0)d=-d; exit !(d<0.01)}'; then
    check_fail "authoritative configuration respected" \
"calculateFee(10000.00, \"RTP\") = ${RESULT_HIGH} — expected ${EXPECTED_HIGH} (max(${PCT} of amount, USD ${MIN}))"
  else
    check_pass "authoritative configuration respected   (calculateFee(100.00, \"RTP\") = ${RESULT}; calculateFee(10000.00, \"RTP\") = ${RESULT_HIGH})"
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
