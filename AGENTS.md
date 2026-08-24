# Meridian Payments — Agent Instructions (Context Lifecycle Lab)

Java 17 payments platform. Maven build. JUnit 5 + Mockito. This lab's task is MFIN-2088
(SEPA transfer fee support) — see `docs/JIRA_TICKETS.md`.

## Build and test

```
mvn clean compile          # must pass before any change is considered done
mvn test                   # baseline is green; keep it green
./scripts/verify-change.sh # the task-specific deterministic verifier — prefer this
```

## Non-negotiable business rules

- Current fee schedule (source of truth: `config/fee-schedule.yaml`): **WIRE 0.25%,
  ACH flat $0.25, SWIFT 0.5% + $15, SEPA 0.35% with a EUR 2.00 minimum applied to the
  computed fee, not the raw transfer amount.**
- `LegacyPaymentUtils` is retired. It carries a 1% WIRE rate and 2014 FX rates. Do not
  call it, copy from it, or cite its values as current.
- `docs/adr/ADR-0007-fee-schedule.md` is a stale, never-finalized draft (SEPA 0.30%
  flat, no minimum). `config/fee-schedule.yaml` supersedes it. Do not implement from
  the ADR.
- Currency conversion routes through `CurrencyConverter`. Never inline an exchange rate.
- Never log account IDs, card numbers, CVV, passwords, session tokens, or `requestedBy`.

## Answering questions about this codebase

Prefer the narrowest, most authoritative primitive that can answer:

| Question | Use |
|---|---|
| Where should I even look for this? | `./scripts/context-map.sh <keyword>` |
| Is a dependency real or just text? | `./scripts/authority.sh <Symbol> <file>` |
| Shape of a large class | `./scripts/digest.sh <file>` or `./scripts/outline.sh <file>` |
| What did the last test run show? | `./scripts/context-run.sh test` |
| What changed? | `./scripts/context-run.sh diff` |
| Where is a term used across the repo? | `./scripts/context-run.sh search <term>` |
| What's already been verified for this work unit? | `./scripts/context-for.sh <work-unit>` |
| Is the SEPA implementation actually correct? | `./scripts/verify-change.sh` |

Do not attach whole files to answer questions the above can answer. Do not reach for a
broad workspace search unless the question is genuinely broad and you cannot name a
narrower primitive.

## Output

- Return only the code that changes. No unchanged methods, no class boilerplate.
- One inline comment where the business reason is not obvious. No prose blocks unless asked.
- If a method signature does not change, do not reproduce it.

---

<!--
DESIGN NOTE — deliberately flat.

This file is one level deep on purpose. A July 2026 study on long-context agents found
single-level disclosure outperformed multi-level hierarchies, and that deeper nesting
sometimes reduced accuracy. Resist splitting this into a tree of linked files.

AGENTS.md is read by Copilot and by other agent tooling, and is stewarded by the Agentic
AI Foundation under the Linux Foundation. Prefer it over a vendor-specific instructions
file when the guidance is not vendor-specific.
-->
