---
name: test-evidence
description: Settle whether any test actually exercises a specific behavior — tests that call a method AND use a given token — and, when such tests exist, run exactly those tests. Use when the claim is "is behavior X of method Y proven by tests?" rather than "is method Y referenced by a test?". Returns a verdict backed by a source scan or by execution.
context: fork
disable-model-invocation: true
---

# Test Evidence

"Is this method covered?" and "is this behavior proven?" are different claims. A method can
be called by tests that never touch the case you care about. This answers the narrower
question.

## Input contract

- A method name, e.g. `calculateFee`
- A token that identifies the behavior, e.g. `RTP`

## Workflow

1. Run:
   ```
   ./scripts/test-evidence.sh <method> <token>
   ```
2. Return its output.

## Output contract

The evidence table, the `VERDICT:` line and the `EVIDENCE:` line, unedited.

## Rules

- `NOT PROVEN` is a complete answer. Do not soften it because other tests call the method.
- If matching tests exist, the verdict comes from running them — report the run result, not
  the fact that the tests exist.
- A passing behavior test does not prove a specific boundary of that behavior; do not claim
  it does.
