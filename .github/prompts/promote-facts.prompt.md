---
description: Format your dictated verified facts, constraints, and unknowns into .context/context-register.yaml, matching the template's exact shape. You decide what counts as verified — this only handles the YAML formatting.
mode: edit
---

# Promote Facts to the Context Register

Fill in `.context/context-register.yaml` from `.context/context-register.template.yaml`'s
exact structure: two levels of nesting, one scalar per line, a `>` folded block only on
`objective`. Do not invent this shape from general YAML knowledge — match the template
file exactly, since `scripts/context-for.sh` parses it with a plain `awk` state machine,
not a real YAML library, and drifts from the exact shape silently misparse.

I will describe, in plain English, what I've verified: my objective, my verified facts
(each needs a `claim`, a `source`, and a `source_type`), my authoritative sources, my
constraints, and any unknowns. Write only what I actually say — never infer, guess, or
add a fact I didn't state out loud, even if it seems obviously true from the codebase.
Deciding what counts as verified is not your job here; formatting it is.

Leave `decisions:` and `superseded_sources:` empty unless I explicitly say a human has
already ratified something. Those two sections record a governance act, not a technical
finding — do not populate them from inference no matter how confident the evidence looks.

If I haven't stated my facts yet, ask me for them before writing anything.
