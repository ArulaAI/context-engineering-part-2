#!/usr/bin/env bash
#
# verify.sh — Part A of docs/VERIFICATION.md. Automated pre-delivery checks.
#
# Run from the repo root:  bash docs/verify.sh
#
# Exits non-zero if any check fails, so it can be wired into CI.
#
# A5 is mutating: it applies fixtures/rtp-implementation.diff, checks verify-change.sh's
# verdict, fixes the bug in place, checks again, then reverts the working tree via git
# checkout. It refuses to run at all if the tree is not clean beforehand, so it never
# discards real work.

cd "$(dirname "$0")/.." || exit 2

PASS=0
FAIL=0

ok()   { printf "  \033[32mPASS\033[0m  %s\n" "$1"; PASS=$((PASS+1)); }
bad()  { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; FAIL=$((FAIL+1)); }
note() { printf "        %s\n" "$1"; }

echo ""
echo "Context Lifecycle Lab — automated verification (Part A)"
echo "========================================================="

# ---------------------------------------------------------------- A1 toolchain
echo ""
echo "A1  Toolchain"
if command -v java >/dev/null 2>&1; then
  JV=$(java -version 2>&1 | head -1 | sed -E 's/.*"([0-9]+).*/\1/')
  if [ "${JV:-0}" -ge 17 ] 2>/dev/null; then ok "java $JV (>= 17)"; else bad "java $JV — need 17+"; fi
else
  bad "java not found"
fi
if command -v mvn >/dev/null 2>&1; then ok "maven present"; else bad "mvn not found"; fi
if command -v jshell >/dev/null 2>&1; then ok "jshell present (required by verify-change.sh check 4)"; else bad "jshell not found"; fi
if command -v jdeps >/dev/null 2>&1; then ok "jdeps present (required by authority.sh)"; else bad "jdeps not found"; fi
if command -v git >/dev/null 2>&1; then ok "git present"; else bad "git not found"; fi

# ---------------------------------------------------------------- A2 baseline
echo ""
echo "A2  Baseline build and tests"
if [ -n "$(git status --porcelain -uno 2>/dev/null)" ]; then
  bad "tracked files have uncommitted changes — commit or stash before running verification"
  echo ""
  echo "$FAIL check(s) failed. Fix the working tree and re-run."
  exit 1
fi
MVN_OUT=$(mvn -q clean test 2>&1)
MVN_RC=$?
if [ "$MVN_RC" -ne 0 ]; then
  bad "mvn clean test did not succeed (exit ${MVN_RC})"
  echo "$MVN_OUT" | grep -E "ERROR" | head -5 | sed 's/^/        /'
else
  ok "mvn clean test succeeded"
fi
SUREFIRE="target/surefire-reports"
if [ -d "$SUREFIRE" ]; then
  RUN=$(grep -ho 'tests="[0-9]*"' "$SUREFIRE"/*.xml 2>/dev/null | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}')
  FAILURES=$(grep -ho 'failures="[0-9]*"' "$SUREFIRE"/*.xml 2>/dev/null | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}')
  if [ "${RUN:-0}" -eq 5 ] && [ "${FAILURES:-1}" -eq 0 ]; then
    ok "5 tests run, 0 failures"
  else
    bad "expected 5 tests / 0 failures, got ${RUN:-?} / ${FAILURES:-?}"
  fi
else
  bad "no surefire reports produced"
fi

# ---------------------------------------------------------------- A3 context-map
echo ""
echo "A3  context-map.sh correctness"
MAP=$(./scripts/context-map.sh RTP 2>/dev/null)
if echo "$MAP" | grep -q "config/fee-schedule.yaml"; then ok "finds config/fee-schedule.yaml"
else bad "did not find config/fee-schedule.yaml for keyword RTP"; fi
if echo "$MAP" | grep -q "docs/adr/ADR-0007-fee-schedule.md"; then ok "finds docs/adr/ADR-0007-fee-schedule.md"
else bad "did not find docs/adr/ADR-0007-fee-schedule.md for keyword RTP"; fi
if echo "$MAP" | grep -q "both mention RTP"; then ok "reports the config/ADR disagreement"
else bad "did not report the config/ADR disagreement — has ADR-0007 been marked Superseded already?"; fi

# ---------------------------------------------------------------- A4 authority
echo ""
echo "A4  authority.sh correctness"
AUTH=$(./scripts/authority.sh 2>/dev/null)
if echo "$AUTH" | grep -q "3 hit(s)"; then ok "grep reports 3 hits on LegacyPaymentUtils"
else bad "expected 3 grep hits — has PaymentService.java changed?"; fi
if echo "$AUTH" | grep -q "0 bytecode reference(s)"; then ok "jdeps reports 0 bytecode references"
else bad "expected 0 bytecode references"; fi
if echo "$AUTH" | grep -q "FALSE POSITIVE"; then ok "verdict is FALSE POSITIVE"
else bad "expected verdict FALSE POSITIVE"; fi

# ---------------------------------------------------------------- A5 verify-change (mutating)
echo ""
echo "A5  verify-change.sh catches the seeded bug AND clears once fixed"

cleanup_a5() {
  git checkout -- src/main/java/com/meridian/payments/PaymentService.java 2>/dev/null
  rm -f .workflow/state.json
}
trap cleanup_a5 EXIT

if ! git apply --check fixtures/rtp-implementation.diff 2>/dev/null; then
  bad "fixtures/rtp-implementation.diff does not apply cleanly to baseline"
else
  git apply fixtures/rtp-implementation.diff
  mvn -B -q test-compile >/dev/null 2>&1
  BUGGY=$(./scripts/verify-change.sh 2>&1)
  if echo "$BUGGY" | grep -q "VERDICT: FAIL" && echo "$BUGGY" | grep -q "authoritative configuration respected"; then
    ok "flags the seeded bug (VERDICT: FAIL on 'authoritative configuration respected')"
  else
    bad "did not flag the seeded bug as expected"
    note "got: $(echo "$BUGGY" | tail -1)"
  fi

  # Apply the fix in place: compare the computed fee, not the raw amount.
  # The awk program lives in fixtures/rtp-correct.awk (facilitator fixture,
  # not learner-facing) to avoid inlining the correct implementation here.
  FEE_JAVA="src/main/java/com/meridian/payments/PaymentService.java"
  FEE_JAVA_TMP="$(mktemp)"
  awk -f fixtures/rtp-correct.awk "$FEE_JAVA" > "$FEE_JAVA_TMP"
  AWK_RC=$?
  if [ "$AWK_RC" -eq 0 ]; then
    mv "$FEE_JAVA_TMP" "$FEE_JAVA"
  else
    rm -f "$FEE_JAVA_TMP"
  fi
  if [ "$AWK_RC" -ne 0 ]; then
    bad "could not apply the in-place fix for the clears-once-fixed check"
  else
    mvn -B -q test-compile >/dev/null 2>&1
    FIXED=$(./scripts/verify-change.sh 2>&1)
    if echo "$FIXED" | grep -q "VERDICT: PASS"; then
      ok "clears to VERDICT: PASS once the comparison is corrected"
    else
      bad "did not clear to PASS after the fix"
      note "got: $(echo "$FIXED" | tail -1)"
    fi
  fi
fi

cleanup_a5
trap - EXIT

# ---------------------------------------------------------------------- summary
echo ""
echo "========================================================="
echo "${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
exit $?
