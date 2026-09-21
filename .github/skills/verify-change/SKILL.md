---
name: verify-change
description: Run the deterministic verifier for the MFIN-2088 change — pricing authority recorded, build and full suite green, change inside the handoff's declared scope, no LegacyPaymentUtils dependency, approved pricing implemented, config matching the approval — and report its verdict. Use to check or gate a change instead of reasoning about whether it is correct.
context: fork
disable-model-invocation: true
---

# Verify Change

Run the deterministic verifier and relay its verdict. Every check fails closed: missing
evidence is a failure, never a pass.

## Workflow

1. Run:
   ```
   ./scripts/verify-change.sh
   ```
2. Return the ✓/✗ lines and the `VERDICT:` line exactly as printed.

## Exit codes

| Exit | Meaning |
|---|---|
| 0 | every check passed |
| 1 | one or more checks failed — the ✗ lines say which, with evidence |
| 2 | the code does not compile — no further checks ran |

## Output contract

The script's check lines and verdict, unedited. No prose introduction, no interpretation.

## Rules

- Never report a pass the script did not print.
- Never explain away a ✗ line. Report it; the person reading decides what it means.
