# `.workflow/` — state that lives on disk, not in the conversation

The workflow passes state through files here. The chat carries **pointers**, not
payloads.

| File | Written by | Read by |
|---|---|---|
| `HANDOFF.md` | `sepa-investigator` (Stage 4) | the human, then `sepa-implementer` |
| `state.json` | `scripts/loop.sh` | `scripts/loop.sh`, the agent running the loop |

Two reasons this matters:

**Cost.** A handoff read from a file costs what it costs, once. A handoff carried in
conversation history is re-sent on every subsequent turn for the life of the session.

**Determinism.** The attempt counter in `state.json` is not something the agent has to
remember, and not something it can talk itself out of. A bound written in an instructions
file is a request. A bound on disk, checked by a script, is a bound.

Both files are regenerated per run and are safe to delete.
