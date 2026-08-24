---
name: context-package
description: Build a task-specific context package (objective, relevant files, applicable verified facts, authoritative config, constraints, required tests, open questions) from already-promoted facts in .context/context-register.yaml. Use when starting a new work unit that has verified facts recorded from earlier investigation. Returns the package, not a re-derivation of the facts.
context: fork
disable-model-invocation: false
---

# Context Package

Package what has already been promoted and verified — this skill does not re-derive
facts, it filters and formats ones that already survived Stage 3's promote-or-discard
decision.

## Input contract

- A work-unit name, e.g. `calculateFee-sepa`
- `.context/context-register.yaml` must already exist (create it in Stage 3 before
  using this skill)

## Workflow

1. Run:
   ```
   ./scripts/context-for.sh <work-unit>
   ```
2. Read only the script output. **Do not open `.context/context-register.yaml`
   yourself and re-summarize it** — the script's filtering (by `applies_to` tag) is
   the point.

## Output contract

Return only the script's package. No prose introduction. No summary paragraph. No code.

## Rules

- **Never** invent a verified fact that isn't in the register. If the package says
  "(none promoted yet)," that is the honest answer — say so, don't fill the gap from
  memory or a fresh search.
- If the register's `superseded_sources` section flags a source, never treat that
  source as current, even if it's the only one you can find quickly.

If you were invoked as a subagent, this package is the entire value you return — make
it self-sufficient for whoever receives it next.
