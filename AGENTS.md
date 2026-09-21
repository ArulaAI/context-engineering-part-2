# Meridian Payments — Agent Instructions

Java 17 payments platform. Maven build. JUnit 5 + Mockito. Current work item: MFIN-2088
— see `docs/JIRA_TICKETS.md`.

## Build and test

```
mvn clean compile          # must pass before any change is considered done
mvn test                   # baseline is green; keep it green
```

## Engineering rules

- When sources disagree about a value, surface both sources and their provenance. Do not
  pick one yourself — say what would settle it and stop.
- Fee constants must trace to an approved pricing reference, not to a comment, a legacy
  class, or recall.
- Currency conversion routes through `CurrencyConverter`. Never inline an exchange rate.
- Never log account IDs, card numbers, CVV, passwords, session tokens, or `requestedBy`.

## Where engineering state lives

| Layer | File | Written by |
|---|---|---|
| Evidence (claim-specific observations) | `.context/evidence-ledger.yaml` | `./scripts/ctx.sh evidence ...` |
| Durable verified context | `.context/context-register.yaml` | `./scripts/ctx.sh promote / unknown / decide` |
| Task handoff (projection for the next actor) | `.workflow/HANDOFF.md` | `./scripts/ctx.sh handoff <work-unit>` |
| Workflow outcome (what actually happened) | `.workflow/outcome.yaml` | `./scripts/ctx.sh outcome ...` |

Chat transcripts are not engineering state. Do not treat anything said in a conversation
as verified unless it is recorded in one of the files above with its evidence.

## Answering questions about this codebase

| Question | Skill | Underlying script |
|---|---|---|
| Where should I look for this? (routing, not answers) | `/context-map <keyword>` | `./scripts/context-map.sh <keyword>` |
| Is a dependency real or only text? | `/authority <Symbol> [file]` | `./scripts/authority.sh <Symbol> [file]` |
| Does any test exercise this behavior? | `/test-evidence <method> <token>` | `./scripts/test-evidence.sh <method> <token>` |
| Shape of a large class | `/outline <file>` | `./scripts/outline.sh <file>` |
| Test run, diff, or search as a digest | `/context-run test\|diff\|search <term>` | `./scripts/context-run.sh ...` |
| Package durable context for a work unit | `/context-package <work-unit>` | `./scripts/ctx.sh package <work-unit>` |
| Does the change satisfy the ticket? | `/verify-change` | `./scripts/verify-change.sh` |

Do not attach whole files to answer a question one of these can answer.

If you hold the `agent` tool, dispatch `evidence-checker` for a single factual claim rather
than gathering the evidence yourself. It returns a verdict; the compile output and file
reads stay in its context. Dispatch one claim at a time.

## Output

- Return only the code that changes. No unchanged methods, no class boilerplate.
- One inline comment where the business reason is not obvious.
- If a method signature does not change, do not reproduce it.
