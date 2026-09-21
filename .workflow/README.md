# `.workflow/` — task state that lives on disk, not in the conversation

The chat carries pointers, not payloads. Everything a later actor needs about the task is here.

| File | Written by | Read by |
|---|---|---|
| `baseline` | `scripts/lab-start.sh` | the verifier's scope check, the outcome record |
| `HANDOFF.md` | `scripts/ctx.sh handoff` — a projection of the register for one task | the implementer, in a fresh chat |
| `handoff-consumed` | `scripts/handoff-check.sh`, when an implementer's return quotes the right ID | the outcome record |
| `review-package.md` | `scripts/review-package.sh` | the reviewer, pasted into a fresh chat |
| `outcome.yaml` | `scripts/ctx.sh outcome` | anyone rehydrating the work later |
| `state.json`, `attempts.tsv`, `last-verdict.txt` | `scripts/loop.sh` | `loop.sh`, and the `loop-bound` hook |

All of it is created during your run and is gitignored.

## `HANDOFF.md`

A task-scoped projection of durable state — never a conversation summary. Sections:
Objective · Approved decisions · Allowed change scope · Known constraints · Required proof ·
Unresolved questions · Next action · Return contract.

Its `handoff_id` is a hash of its own content. It exists nowhere else, so an implementer that
quotes it has provably read this file. Editing the file by hand invalidates the ID — regenerate
it from the register instead.

## `outcome.yaml`

What actually happened, recorded from repository state rather than recollection: work item,
handoff ID and whether it was consumed, the approved decisions, where the change landed and in
which commit, the tests added, review findings and their dispositions, the verification
verdict, remaining unknowns, and the next action.
