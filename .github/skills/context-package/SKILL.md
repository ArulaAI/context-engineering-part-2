---
name: context-package
description: Build a task-specific package of durable engineering state — decisions with their authority, verified facts with their evidence, constraints, superseded sources, and open unknowns — filtered to one work unit from .context/context-register.yaml. Use when starting work that earlier investigation already informed. Returns the package, never a re-derivation.
context: fork
disable-model-invocation: true
---

# Context Package

Package what has already been verified and decided. This skill does not re-derive facts: it
filters durable state by work-unit tag and returns it.

## Input contract

- A work-unit name, e.g. `calculateFee-rtp`
- `.context/context-register.yaml` must exist (`./scripts/ctx.sh init` creates it)

## Workflow

1. Run:
   ```
   ./scripts/ctx.sh package <work-unit>
   ```
2. Read only the script output. **Do not open the register and re-summarize it** — the
   filtering by `applies_to` tag is the point.

## Output contract

Return only the script's package. No prose introduction. No summary paragraph.

## Rules

- Never add a fact that is not in the package. "(none)" is an honest answer.
- Never treat an open unknown as settled, and never treat a superseded source as current.
