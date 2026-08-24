# `.context/` — promoted facts, on disk, not in the conversation

Stage 3 ("Promote & Package") treats a long conversation's discoveries as unequal. Some
are verified facts worth keeping. Most are temporary observations worth discarding. This
directory is where the "worth keeping" half lives, so the next task package can be built
from it instead of from a re-read of the whole conversation.

| File | Written by | Read by |
|---|---|---|
| `context-register.yaml` | you, in Stage 3 | `scripts/context-for.sh` |

`context-register.yaml` is a **deliberately flat YAML subset** — two levels of nesting
max, one scalar per line, a `>` folded block only on `objective`. That's not a limitation
that slipped in by accident: it's what lets `scripts/context-for.sh` parse the register
with a plain `awk` state machine and no YAML library, no Python, and no dependency
beyond what's already installed alongside a JDK and Maven — matching every other script
in this lab's "no dependencies beyond what's already installed" rule.

Required top-level keys: `objective`, `verified_facts`, `authoritative_sources`,
`decisions`, `constraints`, `superseded_sources`, `unknowns`. See
`context-register.yaml.example` for the exact shape, filled in for this lab's SEPA
scenario.

Each entry under `verified_facts` may carry an optional `applies_to: <work-unit-tag>`
field. An entry without one is treated as global and included in every package
`scripts/context-for.sh` builds; a tagged entry is included only when its tag matches
the requested work unit.

**`context-register.yaml` (without `.example`) is created live by you during Stage 3.**
It is not shipped — the empty state is the honest starting point, matching "nothing has
been promoted yet."
