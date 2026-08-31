#!/usr/bin/env bash
# session-constraints.sh — SessionStart: put the non-negotiables in, deterministically.
#
# An instructions file states the fee schedule and hopes. This injects it at the
# top of every session, from a script, with no dependence on the model having
# read or retained anything.
#
# It is still only context — the model can still ignore it. That is why the RTP
# minimum is ALSO checked deterministically by scripts/verify-change.sh. Injection
# is rung 1 of the enforcement ladder; the deterministic verifier is rung 6.

set -uo pipefail
cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"When you encounter conflicting information across sources, surface both sources and their provenance - do not assume either is authoritative without checking evidence (commit history, status fields, etc.). Verify claims with the strongest available evidence tier before acting on them."}}
EOF
