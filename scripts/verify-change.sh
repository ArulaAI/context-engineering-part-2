#!/usr/bin/env bash
#
# verify-change.sh — the deterministic verifier for MFIN-2088.
#
# Each check settles one claim with the mechanism that can actually settle it, and every
# check fails CLOSED: missing evidence is a failure, never a pass.
#
#   1. pricing authority recorded   a human decision in the register cites an approval record
#                                   that exists (the business-authority claim)
#   2. build and full test suite    scripts/verify.sh (the behavior-preserved claim)
#   3. change inside declared scope every changed hunk since the lab's starting commit lies in
#                                   a method the HANDOFF declares (the scope claim)
#   4. no LegacyPaymentUtils dep.   bytecode, via scripts/authority.sh (the dependency claim)
#   5. approved pricing implemented calls the compiled calculateFee() through jshell and compares
#                                   it with the APPROVAL record's numbers (the behavior claim)
#   6. config matches approval      config/fee-schedule.yaml carries the approved values
#
# Expected values come from the approval the human decision cites — not from config. Config
# is checked against the approval, because "which source governs pricing" was a decision,
# and this script does not get to make it.
#
# exit 0 all pass · 1 a check failed · 2 compile failure · 3 required state missing

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

REG=".context/context-register.yaml"
HANDOFF=".workflow/HANDOFF.md"
BASELINE_FILE=".workflow/baseline"
PASS=0; FAIL=0

check_pass() { echo "✓ $1"; PASS=$((PASS+1)); }
check_fail() { echo "✗ $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/    /'; FAIL=$((FAIL+1)); }

# ---- 1. pricing authority recorded -------------------------------------------------------
AUTH=""
if [ -f "$REG" ]; then
  AUTH="$(awk '/^decisions:/{d=1;next} /^[a-z_]+:/{d=0} d && /^    authority: /{sub(/^    authority: /,""); gsub(/"/,""); print; exit}' "$REG")"
fi
PCT=""; MIN=""
if [ -z "$AUTH" ]; then
  check_fail "pricing authority recorded" "no human decision in $REG cites a pricing authority — RTP pricing is undecided"
elif [ ! -f "$AUTH" ]; then
  check_fail "pricing authority recorded" "the decision cites $AUTH, which does not exist"
else
  PCT="$(awk '/^approved_pricing:/{a=1} a && /percent:/{print $2; exit}' "$AUTH")"
  MIN="$(awk '/^approved_pricing:/{a=1} a && /minimum_usd:/{print $2; exit}' "$AUTH")"
  if [ -z "$PCT" ] || [ -z "$MIN" ]; then
    check_fail "pricing authority recorded" "$AUTH has no machine-readable approved_pricing (percent, minimum_usd)"
  else
    check_pass "pricing authority recorded          ($AUTH: ${PCT} of amount, minimum USD ${MIN})"
  fi
fi

# ---- 2. build and full test suite --------------------------------------------------------
VERIFY_OUT="$(bash scripts/verify.sh 2>&1)"; VERIFY_RC=$?
if [ "$VERIFY_RC" -eq 2 ]; then
  printf '%s\n' "$VERIFY_OUT"
  echo "COMPILE FAIL — no further checks can run."
  exit 2
fi
if [ "$VERIFY_RC" -eq 0 ]; then
  check_pass "build and full test suite green     ($(printf '%s' "$VERIFY_OUT" | grep -oE '[0-9]+ tests' | head -1), 0 failures)"
else
  check_fail "build and full test suite green" "$VERIFY_OUT"
fi

# ---- 3. change inside declared scope -----------------------------------------------------
if [ ! -f "$HANDOFF" ]; then
  check_fail "change inside declared scope" "no $HANDOFF — there is no declared scope to check against"
elif [ ! -f "$BASELINE_FILE" ]; then
  check_fail "change inside declared scope" "no $BASELINE_FILE — run ./scripts/lab-start.sh so the scope has a fixed starting point"
else
  BASE="$(cat "$BASELINE_FILE")"
  SCOPE="$(awk '/^## Allowed change scope/{s=1;next} /^## /{s=0} s' "$HANDOFF" | grep -oE '`[A-Z][A-Za-z0-9]*\.[a-z][A-Za-z0-9]*`' | tr -d '`')"
  OUT=""; INSIDE=0
  CHANGED="$( { git diff --name-only "$BASE" -- src/main/java; git ls-files --others --exclude-standard -- src/main/java; } | sort -u)"
  for f in $CHANGED; do
    cls="$(basename "$f" .java)"
    ranges=""
    for s in $SCOPE; do [ "${s%%.*}" = "$cls" ] && ranges="$ranges ${s#*.}"; done
    if [ -z "$ranges" ]; then OUT="${OUT}${f}: not in the declared scope at all"$'\n'; continue; fi
    methods="$(bash scripts/lib/methods.sh "$f" 2>/dev/null)"
    while IFS=, read -r start count; do
      [ -n "$start" ] || continue
      count="${count:-1}"; end=$(( count > 0 ? start + count - 1 : start ))
      hit="$(printf '%s\n' "$methods" | awk -F'\t' -v a="$start" -v b="$end" '$2<=a && b<=$3 {print $1; exit}')"
      ok=0; for m in $ranges; do [ "$hit" = "$m" ] && ok=1; done
      if [ $ok -eq 1 ]; then INSIDE=$((INSIDE+1)); else OUT="${OUT}${f}:${start}-${end} is in ${hit:-no method}, outside the declared scope"$'\n'; fi
    done < <(git diff -U0 "$BASE" -- "$f" | sed -n 's/^@@ -[0-9,]* +\([0-9]*\)\(,\([0-9]*\)\)\{0,1\} @@.*/\1,\3/p')
  done
  if [ -n "$OUT" ]; then
    check_fail "change inside declared scope" "${OUT%$'\n'}"
  else
    check_pass "change inside declared scope        (${INSIDE} changed hunk(s), all inside $(printf '%s' "$SCOPE" | tr '\n' ' ' | sed 's/ $//'))"
  fi
fi

# ---- 4. no LegacyPaymentUtils dependency --------------------------------------------------
AUTH_OUT="$(bash scripts/authority.sh LegacyPaymentUtils src/main/java/com/meridian/payments/PaymentService.java 2>&1)"; AUTH_RC=$?
EVID="$(printf '%s\n' "$AUTH_OUT" | grep '^EVIDENCE: ' | tail -1)"
if [ "$AUTH_RC" -ne 0 ] || [ -z "$EVID" ]; then
  check_fail "no LegacyPaymentUtils dependency" "dependency evidence unavailable (authority.sh exit $AUTH_RC) — refusing to assume none: $(printf '%s\n' "$AUTH_OUT" | grep -m1 'authority.sh:' || echo 'no EVIDENCE line produced')"
else
  REFS="$(printf '%s' "$EVID" | sed -n 's/.*bytecode_refs=\([0-9]*\).*/\1/p')"
  if [ "${REFS:-x}" = "0" ]; then
    check_pass "no LegacyPaymentUtils dependency    (0 bytecode references, jdeps)"
  else
    check_fail "no LegacyPaymentUtils dependency" "${REFS} bytecode reference(s) — see scripts/authority.sh"
  fi
fi

# ---- 5. approved pricing implemented -------------------------------------------------------
CLASS=target/classes/com/meridian/payments/PaymentService.class
fee() {
  echo "System.out.println(new com.meridian.payments.PaymentService(null,null,null,null).calculateFee(new java.math.BigDecimal(\"$1\"), \"RTP\"));" \
    | jshell --class-path target/classes -q - 2>/dev/null | tail -1 | tr -d '[:space:]'
}
if [ -z "$PCT" ] || [ -z "$MIN" ]; then
  check_fail "approved pricing implemented" "no approved pricing to check against (see check 1)"
elif [ ! -f "$CLASS" ]; then
  check_fail "approved pricing implemented" "PaymentService did not compile"
elif ! command -v jshell >/dev/null 2>&1; then
  check_fail "approved pricing implemented" "jshell not on PATH — cannot execute calculateFee, refusing to guess"
else
  DETAIL=""; BAD=""
  for amt in 100.00 10000.00; do
    got="$(fee "$amt")"
    want="$(awk -v a="$amt" -v p="$PCT" -v m="$MIN" 'BEGIN{f=a*p; if(f<m) f=m; printf "%.2f", f}')"
    DETAIL="${DETAIL}calculateFee(${amt}, \"RTP\") = ${got:-<no result>}; "
    if [ -z "$got" ] || ! awk -v r="$got" -v e="$want" 'BEGIN{d=r-e; if(d<0)d=-d; exit !(d<0.005)}'; then
      BAD="${BAD}calculateFee(${amt}, \"RTP\") = ${got:-<no result>} — approved pricing gives ${want}"$'\n'
    fi
  done
  if [ -n "$BAD" ]; then check_fail "approved pricing implemented" "${BAD%$'\n'}"
  else check_pass "approved pricing implemented        (${DETAIL%; })"; fi
fi

# ---- 6. config matches the approval --------------------------------------------------------
if [ -z "$PCT" ] || [ -z "$MIN" ]; then
  check_fail "config matches the approved pricing" "no approved pricing to compare with (see check 1)"
else
  CP="$(awk '/^rtp_percent:/{print $2; exit}' config/fee-schedule.yaml)"
  CM="$(awk '/^rtp_minimum_usd:/{print $2; exit}' config/fee-schedule.yaml)"
  if awk -v a="$CP" -v b="$PCT" -v c="$CM" -v d="$MIN" 'BEGIN{exit !(a==b && c==d)}' 2>/dev/null && [ -n "$CP" ] && [ -n "$CM" ]; then
    check_pass "config matches the approved pricing (rtp_percent ${CP}, rtp_minimum_usd ${CM})"
  else
    check_fail "config matches the approved pricing" "config: rtp_percent=${CP:-missing} rtp_minimum_usd=${CM:-missing}; approval: ${PCT}, ${MIN}"
  fi
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "VERDICT: PASS — ${PASS} of $((PASS+FAIL)) checks passed"
  exit 0
fi
echo "VERDICT: FAIL — ${FAIL} of $((PASS+FAIL)) checks failed"
exit 1
