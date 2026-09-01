---
name: authority
description: Settle whether a claimed code dependency is real by comparing text search against compiled bytecode (jdeps), instead of trusting either alone. Use when a class, method, or file appears to depend on another and you need a verdict stronger than a grep hit. Returns a tiered verdict, not a guess.
context: fork
disable-model-invocation: true
---

# Authority

Not all evidence is equal. A text match can be an import, a comment, or a string
literal — it proves nothing about a compiled dependency. This settles it at the
bytecode tier instead of the text tier.

## Input contract

- A symbol to check, e.g. `LegacyPaymentUtils`
- Optionally, the source file to check it against, e.g.
  `src/main/java/com/meridian/payments/PaymentService.java` (defaults to
  `PaymentService.java` if omitted)

## Workflow

1. Run:
   ```
   ./scripts/authority.sh <Symbol> [path/to/Source.java]
   ```
2. Read only the script output.

## Output contract

Return only the script's `grep`/`jdeps` comparison and its `VERDICT:` line. No prose
introduction. No summary paragraph. No code.

## Rules

- **Never** report a dependency as real or absent from the text-search tier alone — the
  bytecode tier (`jdeps`) is the one that settles it. If the script reports it cannot
  find `jdeps` on `PATH`, say so and stop; do not substitute your own guess for a
  bytecode verdict you don't have.
- If `grep` finds hits and `jdeps` finds none, that is a textual reference that is not a
  compiled call (an unused import, a comment, a string literal) — say so plainly, don't
  round it up to "depends on."

If you were invoked as a subagent, this verdict is the entire value you return — make it
self-sufficient for whoever receives it next.
