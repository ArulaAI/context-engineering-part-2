# Meridian Payments — Agent Instructions (Context Lifecycle Lab)

Java 17 payments platform. Maven build. JUnit 5 + Mockito. This lab's task is MFIN-2088
— see `docs/JIRA_TICKETS.md`.

## Build and test

```
mvn clean compile          # must pass before any change is considered done
mvn test                   # baseline is green; keep it green
```

## Non-negotiable business rules

- When sources disagree about a value, check each source's provenance (commit history,
  status fields, ticket references) before assuming either is current. Do not implement
  from an unverified source — surface the conflict and escalate.
- Do not invent or copy rates from stale sources. Any constants introduced into fee
  logic must be traceable to the verified committed fee schedule.
- Currency conversion routes through `CurrencyConverter`. Never inline an exchange rate.
- Never log account IDs, card numbers, CVV, passwords, session tokens, or `requestedBy`.

## Answering questions about this codebase

These primitives are for general repository exploration. When a lab stage explicitly
says "do not use scripts, agents, or skills" — for example, Stage 0's first-pass audit
or Stage 7's unaided capstone — that instruction overrides this table for that stage.

| Question | Use |
|---|---|
| Where should I even look for this? | `./scripts/context-map.sh <keyword>` |
| Is a dependency real or just text? | `./scripts/authority.sh <Symbol> <file>` |
| Shape of a large class | `./scripts/digest.sh <file>` or `./scripts/outline.sh <file>` |
| What did the last test run show? | `./scripts/context-run.sh test` |
| What changed? | `./scripts/context-run.sh diff` |
| Where is a term used across the repo? | `./scripts/context-run.sh search <term>` |

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
