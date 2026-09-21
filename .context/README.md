# `.context/` — evidence and durable engineering state

This directory holds engineering state that must outlive any conversation. Nothing in it is
written by hand and nothing in it comes from a chat: `scripts/ctx.sh` writes every entry, and
it refuses entries that do not carry their evidence or their authority.

| File | Layer | Written by | Holds |
|---|---|---|---|
| `evidence-ledger.yaml` | Evidence | `ctx.sh evidence add` / `evidence capture` | what a mechanism observed about one claim, and whether that settled it |
| `context-register.yaml` | Durable verified context | `ctx.sh init / promote / unknown / constraint / decide` | what is verified, decided, constrained, superseded, and still unknown |
| `bundles/*.md` | Derived | `scripts/context-bundle.sh` | exact context windows for controlled comparisons |
| `context-map-*.md` etc. | Ephemeral | the routing and digest tools | a saved copy of tool output, so it survives the chat scrolling |

All of it is created during your run and is gitignored. None of it ships.

## The rules `ctx.sh` enforces

- A **verified fact** can only be promoted from a recorded piece of evidence, and carries that
  evidence's mechanism and source.
- An **unresolved** claim cannot be promoted as a fact. It becomes an **unknown**.
- A **decision** must cite an authority file that exists. Recording it **retires** the unknown
  it resolves, and records any source it supersedes and exactly how much of it.
- No question is ever both decided and still open. `ctx.sh check` fails if one is.

## Register shape

```yaml
objective: "..."
work_item: "..."

verified_facts:
  - id: VF-001
    claim: "..."
    evidence_id: "EV-001"
    mechanism: "jdeps"
    source: "..."
    applies_to: "calculateFee-rtp"     # omit for a fact that applies to every work unit

authoritative_sources:      # added automatically when a decision cites an authority
decisions:                  # D-nnn: decision, resolves, authority, decided_by
constraints:                # C-nnn: constraint, basis
superseded_sources:         # SS-nnn: source, superseded_by, scope, decision
unknowns:                   # UNK-nnn: question, status, blocking
retired_unknowns:           # the same questions once a decision resolved them
```
