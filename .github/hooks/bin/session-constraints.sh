#!/usr/bin/env bash
# session-constraints.sh — SessionStart: put the non-negotiables in, deterministically.
#
# An instructions file states the fee schedule and hopes. This injects it at the
# top of every session, from a script, with no dependence on the model having
# read or retained anything.
#
# It is still only context — the model can still ignore it. That is why the SEPA
# minimum is ALSO checked deterministically by scripts/verify-change.sh. Injection
# is rung 1 of the enforcement ladder; the deterministic verifier is rung 6.

set -uo pipefail
cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"MERIDIAN FEE SCHEDULE (authoritative, current, from config/fee-schedule.yaml): WIRE 0.25% | ACH flat $0.25 | SWIFT 0.5% + $15 | SEPA 0.35% with a EUR 2.00 minimum applied to the COMPUTED FEE, not the raw amount | all other types zero. LegacyPaymentUtils is RETIRED: it carries a 1% WIRE rate and 2014 FX rates - never call it, never copy from it, never cite its values as current. docs/adr/ADR-0007-fee-schedule.md's draft SEPA rate (0.30% flat, no minimum) is also never current - config/fee-schedule.yaml supersedes it. Verify every change with ./scripts/verify-change.sh (the exit code is the signal); during a repair loop use VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check so the attempt counts against the budget."}}
EOF
