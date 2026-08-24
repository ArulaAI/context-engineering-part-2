---
name: verify-change
description: Run the deterministic four-check verifier for the SEPA fee change (required behavior preserved, existing path unchanged, prohibited dependency absent, authoritative configuration respected) and report its exit code. Use to check or gate a SEPA implementation instead of reasoning about whether it's correct.
context: fork
disable-model-invocation: false
---

# Verify Change

Establish what must be true deterministically, rather than reasoning about whether a
change looks correct.

## Input contract

None.

## Workflow

Run:
```
./scripts/verify-change.sh
```
Then report its output and its exit code. Nothing else.

## Output contract

| Exit | Meaning | Report |
|---|---|---|
| 0 | all four checks pass | the ✓ checklist and `VERDICT: PASS` line |
| 1 | one or more checks fail | the checklist with ✗ line(s), and the failing check's detail |
| 2 | compile failure | say the build didn't compile, and stop |
| 3 | harness error | say the script could not run, and stop |

No prose introduction. No summary paragraph. No code.

## Rules

- **Never** substitute your own read of the diff for this script's verdict, and never
  substitute this script's verdict for a fresh-context reviewer's read either — Stage 5
  pairs both on purpose, because a reviewer might miss a boundary condition a
  deterministic check catches, and a deterministic check only verifies what it was
  written to check.
- If the script reports all four checks passing while you believe the implementation
  is still wrong, say so explicitly rather than trusting the checklist over your own
  reasoning — the checklist is only as good as the four things it verifies.
- The EUR 2.00 SEPA minimum must be compared against the *computed fee*, not the raw
  transfer amount. This is the check most likely to fail on a first attempt.

If you were invoked as a subagent, this report is the entire value you return — make it
self-sufficient.
