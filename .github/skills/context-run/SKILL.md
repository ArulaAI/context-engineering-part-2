---
name: context-run
description: Run a noisy command (test suite, diff, repo search) through a compacting wrapper that returns a digest instead of raw output, with a stated noise-removed figure. Use whenever the alternative is pasting raw mvn test, git diff, or grep output into the conversation.
context: fork
disable-model-invocation: false
---

# Context Run

Reduce tool output **before** it reaches the model — the cheapest token is the one
that never enters the window.

## Input contract

- A subcommand: `test`, `diff`, or `search <term>`

## Workflow

1. Run:
   ```
   ./scripts/context-run.sh <test|diff|search> [term]
   ```
2. Read only the script output. **Do not run the raw command yourself and paste its
   output** — that defeats the point.

## Output contract

Return only the script's digest, including its `NOISE REMOVED` line. No prose
introduction. No summary paragraph. No code.

## Rules

- **Never** paste raw `mvn test`, `git diff`, or `grep -r` output into the conversation
  when this skill's wrapper can answer the same question.
- If `context-run.sh search` reports a rate cross-check disagreement, say so explicitly
  — do not silently pick one of the two rates.
- The current fee schedule is **WIRE 0.25%, ACH flat $0.25, SWIFT 0.5% + $15, SEPA
  0.35% with a EUR 2.00 minimum** per `config/fee-schedule.yaml`. `LegacyPaymentUtils`
  and `docs/adr/ADR-0007-fee-schedule.md`'s draft rate are never current.

If you were invoked as a subagent, this digest is the entire value you return — make it
self-sufficient.
