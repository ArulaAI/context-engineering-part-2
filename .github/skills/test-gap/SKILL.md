---
name: test-gap
description: Report which public methods on a class have no test referencing them, and where fee/rate/amount logic is computed across the tree — without sending any source or test file into context. Use to answer "is this already tested?" before writing a new test or trusting an existing one. Returns a coverage table, not a guess.
context: fork
disable-model-invocation: true
---

# Test Gap

Answer "what's untested?" and "where does this concept live?" from a computed table,
not from reading every source and test file into the conversation.

## Input contract

- Optionally, a target file, e.g. `src/main/java/com/meridian/payments/PaymentService.java`
  (defaults to `PaymentService.java` if omitted)

## Workflow

1. Run:
   ```
   ./scripts/test-gap.sh [path/to/Source.java]
   ```
2. Read only the script output.

## Output contract

Return only the script's two tables — test coverage gap, then fee logic computation
sites. No prose introduction. No summary paragraph. No code.

## Rules

- **Never** claim a method is tested because its name appears in a comment inside a test
  file — the script already strips comments before counting references; trust its count
  over your own read of a test file.
- A method reporting "covered" only means *some* test references it — it does not mean a
  specific boundary condition is exercised. Say so if asked a narrower coverage question
  than this script answers (e.g. "is the boundary case tested," not just "is it tested
  at all").

If you were invoked as a subagent, this table is the entire value you return — make it
self-sufficient for whoever receives it next.
