#!/usr/bin/env bash
#
# dry-run.sh — FACILITATOR TOOL. Not a lab stage; participants never run this.
#
# Runs every terminal step of LAB_ACTION_GUIDE.md end to end, in order, from a clean
# baseline, and asserts the result of each one. Its job is to answer a single question
# before you record or deliver: does the whole lab still run, with the numbers the guide
# prints? A green run means every command in the guide works and every "Expected:" block
# is still true. A red run names the first step that drifted.
#
# It deliberately does NOT exercise the Copilot-side steps (agents, skills, chat prompts).
# Those need a human at the keyboard. Everything else is here.
#
# usage: scripts/dry-run.sh
# exit 0 every step passed · 1 a step failed (the first failure is named)
#
# WARNING: this resets lab runtime state and restores src/ from the baseline commit.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

STEP=0; FAILED=0; FIRST_FAIL=""

ok()   { STEP=$((STEP+1)); printf '  %-2s ✓ %s\n' "$STEP" "$1"; }
bad()  { STEP=$((STEP+1)); FAILED=$((FAILED+1)); printf '  %-2s ✗ %s\n' "$STEP" "$1"
         [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /'
         [ -z "$FIRST_FAIL" ] && FIRST_FAIL="$1"; }
stage() { echo ""; echo "$1"; }

# expect <label> <pattern> <output>   — the output must contain the pattern
expect() {
  if printf '%s' "$3" | grep -qF -- "$2"; then ok "$1"; else bad "$1" "expected to find: $2
got:
$3"; fi
}
# expect_rc <label> <wanted-exit> <actual-exit> <output>
expect_rc() {
  if [ "$3" = "$2" ]; then ok "$1"; else bad "$1" "expected exit $2, got exit $3
$4"; fi
}

echo "Dry run — every terminal step in LAB_ACTION_GUIDE.md, from a clean baseline."
echo "Repo: $(pwd)"

# ---------------------------------------------------------------- Before You Start
stage "Before You Start"
git checkout -- src config docs/adr 2>/dev/null
OUT="$(bash scripts/lab-start.sh --reset 2>&1)"; RC=$?
expect_rc "lab-start.sh --reset exits 0" 0 "$RC" "$OUT"
expect "baseline build is green (5 tests)" "PASS 5 tests" "$OUT"
expect "starting commit recorded" "Recorded starting commit" "$OUT"

# ---------------------------------------------------------------- Stage 0
stage "Stage 0 — the helpful trap"
OUT="$(bash scripts/stage0-baseline.sh 2>&1)"; RC=$?
expect_rc "stage0-baseline.sh exits 0" 0 "$RC" "$OUT"

# ---------------------------------------------------------------- Stage 1
stage "Stage 1 — discover before you retrieve"
OUT="$(bash scripts/context-map.sh RTP 2>&1)"
expect "context-map RTP routes surfaces" "Unresolved" "$OUT"
OUT="$(bash scripts/authority.sh LegacyPaymentUtils src/main/java/com/meridian/payments/PaymentService.java 2>&1)"
expect "authority: 3 text hits" "3 hit(s)" "$OUT"
expect "authority: 0 bytecode refs" "0 bytecode reference(s)" "$OUT"
expect "authority: verdict rejected" "status=rejected" "$OUT"
OUT="$(bash scripts/test-evidence.sh calculateFee RTP 2>&1)"
expect "test-evidence: NOT PROVEN at baseline" "NOT PROVEN" "$OUT"
OUT="$(bash scripts/outline.sh src/main/java/com/meridian/payments/PaymentService.java 2>&1)"
expect "outline locates calculateFee" "calculateFee" "$OUT"

OUT="$(bash scripts/ctx.sh init --objective "Add approved RTP fee support to PaymentService.calculateFee" --work-item MFIN-2088 2>&1)"; RC=$?
expect_rc "ctx init exits 0" 0 "$RC" "$OUT"
OUT="$(bash scripts/authority.sh LegacyPaymentUtils 2>/dev/null | bash scripts/ctx.sh evidence capture --source "scripts/authority.sh LegacyPaymentUtils" --applies-to calculateFee-rtp 2>&1)"
expect "EV-001 captured as rejected" "EV-001  [rejected]" "$OUT"
OUT="$(bash scripts/test-evidence.sh calculateFee RTP 2>/dev/null | bash scripts/ctx.sh evidence capture --source "scripts/test-evidence.sh calculateFee RTP" --applies-to calculateFee-rtp 2>&1)"
expect "EV-002 captured as unproven" "EV-002  [unproven]" "$OUT"
OUT="$(bash scripts/ctx.sh evidence add --claim "Which source currently governs RTP pricing?" --status unresolved --mechanism "side-by-side read" --source "config/fee-schedule.yaml; docs/adr/ADR-0007-fee-schedule.md" --observed "config/fee-schedule.yaml states 0.35% with a USD 2.00 minimum; ADR-0007 states 0.30% flat with no minimum" --applies-to calculateFee-rtp 2>&1)"
expect "EV-003 recorded as unresolved" "EV-003  [unresolved]" "$OUT"

# ---------------------------------------------------------------- Stage 2
stage "Stage 2 — compress before context"
OUT="$(bash scripts/context-run.sh test 2>&1)"; RC=$?
expect_rc "context-run test exits 0" 0 "$RC" "$OUT"
expect "context-run test reports a digest" "5 passed" "$OUT"
expect "digest names the lines it removed" "NOISE REMOVED" "$OUT"
OUT="$(TEST_CMD="mvn -B no-such-phase" bash scripts/context-run.sh test 2>&1)"; RC=$?
expect "reducer fails closed on a broken build" "BUILD FAILED" "$OUT"
OUT="$(bash scripts/context-run.sh search RTP 2>&1)"
expect "context-run search RTP produces a digest" "RTP" "$OUT"

# ---------------------------------------------------------------- Stage 3
stage "Stage 3 — promote & package"
OUT="$(bash scripts/ctx.sh promote EV-001 --fact "PaymentService has no compiled dependency on LegacyPaymentUtils" 2>&1)"; RC=$?
expect_rc "promote EV-001 exits 0" 0 "$RC" "$OUT"
expect "VF-001 created" "VF-001" "$OUT"
OUT="$(bash scripts/ctx.sh promote EV-002 --fact "No existing test exercises calculateFee with RTP" 2>&1)"; RC=$?
expect_rc "promote EV-002 exits 0" 0 "$RC" "$OUT"
OUT="$(bash scripts/ctx.sh unknown add --from EV-003 --blocking 2>&1)"
expect "UNK-001 opened as blocking" "UNK-001" "$OUT"
OUT="$(bash scripts/ctx.sh constraint add --text "Do not add a call to LegacyPaymentUtils" --basis VF-001 --applies-to calculateFee-rtp 2>&1)"; RC=$?
expect_rc "constraint recorded" 0 "$RC" "$OUT"
OUT="$(bash scripts/ctx.sh promote EV-003 --fact "config is authoritative" 2>&1)"; RC=$?
expect_rc "promoting an unresolved claim is refused" 1 "$RC" "$OUT"
expect "refusal explains why" "unresolved claim is not a fact" "$OUT"
OUT="$(bash scripts/ctx.sh check 2>&1)"; RC=$?
expect_rc "register consistent after Stage 3" 0 "$RC" "$OUT"
OUT="$(bash scripts/ctx.sh package calculateFee-rtp 2>&1)"; RC=$?
expect_rc "ctx package exits 0" 0 "$RC" "$OUT"
OUT="$(bash scripts/context-bundle.sh broad 2>&1; bash scripts/context-bundle.sh package 2>&1)"; RC=$?
expect_rc "both comparison bundles build" 0 "$RC" "$OUT"

# ---------------------------------------------------------------- Stage 4
stage "Stage 4 — boundaries & handoff"
OUT="$(bash scripts/ctx.sh package calculateFee-rtp 2>&1)"
expect "4.4: no decision recorded yet" "Decisions (human, with authority)" "$OUT"
expect "4.4: the asserted rate reached nothing durable" "(none)" "$OUT"
expect "4.4: UNK-001 still blocking" "[BLOCKING]" "$OUT"
OUT="$(bash scripts/ctx.sh handoff calculateFee-rtp --scope PaymentService.calculateFee --next "implement" 2>&1)"; RC=$?
expect_rc "handoff REFUSED while UNK-001 is open" 4 "$RC" "$OUT"
expect "refusal names the blocking unknown" "UNK-001" "$OUT"
OUT="$(bash scripts/request-approval.sh MFIN-2088 2>&1)"; RC=$?
expect_rc "request-approval exits 0" 0 "$RC" "$OUT"
expect "approval landed in docs/approvals" "docs/approvals/PRICING-442.md" "$OUT"
OUT="$(bash scripts/ctx.sh decide --resolves UNK-001 \
  --decision "RTP transfers are charged 0.35% of the transfer amount, with a minimum fee of USD 2.00 per transfer; whichever is larger governs." \
  --authority docs/approvals/PRICING-442.md --decided-by "Lab facilitator" \
  --supersedes docs/adr/ADR-0007-fee-schedule.md \
  --scope "ADR-0007 Decision 2 (the RTP rate) only. Decision 1 (rates live in config/fee-schedule.yaml) still stands." 2>&1)"
expect "D-001 recorded" "D-001" "$OUT"
expect "UNK-001 retired by D-001" "retired (resolved by D-001)" "$OUT"
OUT="$(bash scripts/ctx.sh check 2>&1)"; RC=$?
expect_rc "register is consistent" 0 "$RC" "$OUT"
OUT="$(bash scripts/ctx.sh handoff calculateFee-rtp --scope PaymentService.calculateFee --next "Implement D-001 in PaymentService.calculateFee, then run ./scripts/verify-change.sh" 2>&1)"; RC=$?
expect_rc "handoff now succeeds" 0 "$RC" "$OUT"
expect "handoff has an id" "handoff_id: H-" "$OUT"
HID="$(awk '/^handoff_id: /{print $2; exit}' .workflow/HANDOFF.md)"
OUT="$(bash scripts/handoff-check.sh "HANDOFF_ID: $HID — done." 2>&1)"; RC=$?
expect_rc "handoff-check accepts the real id" 0 "$RC" "$OUT"
expect "handoff reported CONSUMED" "CONSUMED" "$OUT"
OUT="$(bash scripts/handoff-check.sh "HANDOFF_ID: H-0000deadbeef" 2>&1)"; RC=$?
expect_rc "handoff-check rejects an invented id" 1 "$RC" "$OUT"
OUT="$(bash scripts/apply-reference.sh implementation 2>&1)"; RC=$?
expect_rc "reference implementation applies" 0 "$RC" "$OUT"

# ---------------------------------------------------------------- Stage 5
stage "Stage 5 — challenge & bound"
OUT="$(bash scripts/review-package.sh 2>&1)"; RC=$?
expect_rc "review-package builds" 0 "$RC" "$OUT"
PKG="$(cat .workflow/review-package.md 2>/dev/null)"
expect "package carries the acceptance criteria" "MFIN-2088" "$PKG"
expect "package carries the approved decision" "D-001" "$PKG"
N="$(grep -c "rtp_percent\|context-register\|HANDOFF" .workflow/review-package.md)"
if [ "$N" = "0" ]; then ok "5.1: package leaks no config, register or handoff (grep = 0)"
else bad "5.1: package leaks no config, register or handoff (grep = 0)" "grep returned $N"; fi

OUT="$(bash scripts/apply-reference.sh tests 2>&1)"; RC=$?
expect_rc "reference tests apply" 0 "$RC" "$OUT"
OUT="$(bash scripts/test-evidence.sh calculateFee RTP 2>&1)"
expect "2 RTP tests, all green" "ran 2, all passed" "$OUT"
OUT="$(bash scripts/inject-fault.sh on 2>&1)"; RC=$?
expect_rc "fault injects" 0 "$RC" "$OUT"
OUT="$(bash scripts/test-evidence.sh calculateFee RTP 2>&1)"
expect "minimum test goes RED under the fault" "ran 2, 1 FAILED" "$OUT"

bash scripts/loop.sh reset >/dev/null 2>&1
OUT="$(VERIFY_CMD=scripts/verify-change.sh bash scripts/loop.sh check 2>&1)"; RC=$?
expect_rc "loop: attempt 1 fails, CONTINUE (exit 1)" 1 "$RC" "$OUT"
expect "verifier fails under the fault" "VERDICT: FAIL" "$OUT"
OUT="$(VERIFY_CMD=scripts/verify-change.sh bash scripts/loop.sh check 2>&1)"; RC=$?
expect_rc "loop: no code change is REDUNDANT (exit 6)" 6 "$RC" "$OUT"
expect "redundant retry is named as such" "REDUNDANT RETRY" "$OUT"
# a change that does not fix anything: touch a comment inside the faulty branch
sed -i 's|// compares the minimum against the transfer amount, not against the computed fee|// compares the minimum against the transfer amount, not against the computed fee (edited)|' src/main/java/com/meridian/payments/PaymentService.java
OUT="$(VERIFY_CMD=scripts/verify-change.sh bash scripts/loop.sh check 2>&1)"; RC=$?
expect_rc "loop: changed code, same failure (exit 1)" 1 "$RC" "$OUT"
expect "unsuccessful repair is named" "UNSUCCESSFUL REPAIR" "$OUT"
sed -i 's|(edited)|(edited twice)|' src/main/java/com/meridian/payments/PaymentService.java
OUT="$(VERIFY_CMD=scripts/verify-change.sh bash scripts/loop.sh check 2>&1)"; RC=$?
expect_rc "loop: thrashing stops the loop (exit 4)" 4 "$RC" "$OUT"
expect "thrashing is named" "thrashing" "$OUT"

OUT="$(bash scripts/inject-fault.sh off 2>&1)"; RC=$?
expect_rc "fault removes, implementation restored" 0 "$RC" "$OUT"
bash scripts/loop.sh reset >/dev/null 2>&1
OUT="$(VERIFY_CMD=scripts/verify-change.sh bash scripts/loop.sh check 2>&1)"; RC=$?
expect_rc "loop: green at attempt 1 (exit 0)" 0 "$RC" "$OUT"
expect "verifier passes 6 of 6" "VERDICT: PASS" "$OUT"
expect "loop closes cleanly" "DONE" "$OUT"

OUT="$(bash scripts/verify-change.sh 2>&1)"; RC=$?
expect_rc "verify-change exits 0" 0 "$RC" "$OUT"
for c in "pricing authority recorded" "build and full test suite green" "change inside declared scope" \
         "no LegacyPaymentUtils dependency" "approved pricing implemented" "config matches the approved pricing"; do
  expect "check green: $c" "✓ $c" "$OUT"
done

git add -A src >/dev/null 2>&1
git -c user.name=dry-run -c user.email=dry-run@local commit -q -m "feat: add approved RTP fee support (MFIN-2088)" >/dev/null 2>&1
OUT="$(bash scripts/ctx.sh outcome --work-unit calculateFee-rtp --status implemented \
  --test "PaymentServiceTest.calculateFee_rtpMinimumAppliesBelowThreshold" \
  --test "PaymentServiceTest.calculateFee_rtpPercentageAppliesAboveThreshold" \
  --finding "no deviation from the approved rule found::accepted, no change required" \
  --next "Wire calculateFee into the payment path — tracked as a separate work item" 2>&1)"; RC=$?
expect_rc "outcome written" 0 "$RC" "$OUT"
expect "outcome records verification PASS" "verification: PASS" "$OUT"
expect "outcome records the handoff as consumed" "handoff consumed: true" "$OUT"

# ---------------------------------------------------------------- Stage 6
stage "Stage 6 — rehydrate & prove"
OUT="$(bash scripts/ctx.sh rehydrate-check 2>&1)"; RC=$?
expect_rc "rehydrate-check exits 0" 0 "$RC" "$OUT"
expect "every question has a durable source" "REHYDRATABLE" "$OUT"
if printf '%s' "$OUT" | grep -q 'MISSING'; then
  bad "no question is MISSING a source" "$OUT"; else ok "no question is MISSING a source"; fi
OUT="$(bash scripts/context-bundle.sh durable 2>&1)"; RC=$?
expect_rc "durable bundle builds" 0 "$RC" "$OUT"
OUT="$(bash scripts/context-bundle.sh cold 2>&1)"; RC=$?
expect_rc "cold bundle builds" 0 "$RC" "$OUT"
for k in D-001 superseded verification next_action; do
  D="$(grep -c "$k" .context/bundles/durable.md)"; C="$(grep -c "$k" .context/bundles/cold.md)"
  if [ "$D" -gt 0 ] && [ "$C" = "0" ]; then ok "6.3: '$k' is in durable, absent from cold"
  else bad "6.3: '$k' is in durable, absent from cold" "durable=$D cold=$C"; fi
done
C="$(grep -c 0.0035 .context/bundles/cold.md)"
if [ "$C" -gt 0 ]; then ok "6.3: the cold bundle still shows the rate in the code"
else bad "6.3: the cold bundle still shows the rate in the code" "cold=$C"; fi

# ---------------------------------------------------------------- Stage 7
stage "Stage 7 — build beyond the harness"
mvn -q compile >/dev/null 2>&1
N=0
for c in $(find target/classes -name '*.class' 2>/dev/null); do
  n="${c#target/classes/}"; n="${n%.class}"
  k=$(javap -c -p -cp target/classes "$(printf '%s' "$n" | tr '/' '.')" 2>/dev/null | grep -c "PaymentService.calculateFee")
  N=$((N + k))
done
if [ "$N" = "0" ]; then ok "reachability scan: 0 production call sites (as the guide states)"
else bad "reachability scan: 0 production call sites" "found $N"; fi
OUT="$(mvn -B dependency:tree 2>&1 | wc -l)"
if [ "${OUT:-0}" -gt 20 ]; then ok "mvn dependency:tree is noisy enough to reduce ($OUT lines)"
else bad "mvn dependency:tree is noisy enough to reduce" "only $OUT lines"; fi

# ---------------------------------------------------------------- restore
stage "Restoring the repo"
if [ "${DRYRUN_KEEP:-0}" = "1" ]; then
  ok "DRYRUN_KEEP=1 — leaving the finished state in place for inspection"
  echo ""
  echo "Restore it yourself with: git reset --soft HEAD~1 && git checkout -- src && ./scripts/lab-start.sh --reset"
  echo "DRY RUN: $((STEP-FAILED)) of $STEP steps passed (state kept)."
  exit $([ "$FAILED" -eq 0 ] && echo 0 || echo 1)
fi
git reset -q --soft HEAD~1 2>/dev/null && git restore -q --staged src 2>/dev/null
git checkout -- src config docs/adr 2>/dev/null
bash scripts/lab-start.sh --reset >/dev/null 2>&1
ok "repo restored to the baseline commit, runtime state cleared"

echo ""
if [ "$FAILED" -eq 0 ]; then
  echo "DRY RUN: PASS — $STEP of $STEP steps behaved as the guide states."
  exit 0
fi
echo "DRY RUN: FAIL — $FAILED of $STEP steps drifted. First failure: $FIRST_FAIL"
exit 1
