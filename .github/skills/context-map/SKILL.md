---
name: context-map
description: Produce a routing table for where truth lives on a keyword or feature (affected domains, symbols, contracts, config, ADRs, tests, dependency bounds, ticket) before retrieving anything. Use when starting an unfamiliar task, before searching or reading source. Returns a routing table, not an answer.
context: fork
disable-model-invocation: false
---

# Context Map

Answer "where should I look for this?" before answering "what is the answer?" — a
routing table is cheap on purpose so it isn't mistaken for the answer itself.

## Input contract

- A keyword or feature name, e.g. `SEPA`

## Workflow

1. Run:
   ```
   ./scripts/context-map.sh <keyword>
   ```
2. Read only the script output. **Do not open the files it lists** unless the map
   itself is ambiguous about which category a hit belongs to.

## Output contract

Return only the script's table, plus its one closing note if two categories disagree
(e.g. configuration and an architecture decision both claim a rate). No prose
introduction. No summary paragraph. No code.

## Rules

- **Never** treat the map as authoritative — it reports where sources exist, not which
  one is correct. Resolving a disagreement between sources is a separate step
  (`scripts/authority.sh`, or a human decision if no compiler check applies).
- The current fee schedule is **WIRE 0.25%, ACH flat $0.25, SWIFT 0.5% + $15, SEPA
  0.35% with a EUR 2.00 minimum** per `config/fee-schedule.yaml`. `LegacyPaymentUtils`
  and `docs/adr/ADR-0007-fee-schedule.md`'s draft rate are never current.

If you were invoked as a subagent, this table is the entire value you return — make
every row carry something the caller cannot get without you.
