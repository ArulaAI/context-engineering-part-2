---
name: context-map
description: Route before you retrieve. For a keyword, list the candidate context surfaces — task, implementation candidates, configuration, decision records, test surfaces, legacy or dependency signals, other docs — and the questions a map cannot settle. It tells you where to look, never what is true.
context: fork
disable-model-invocation: true
---

# Context Map

Answer "where should I look for this?" before answering "what is the answer?" — a
routing table is cheap on purpose so it isn't mistaken for the answer itself.

## Input contract

- A keyword or feature name, e.g. `RTP`

## Workflow

1. Run:
   ```
   ./scripts/context-map.sh <keyword>
   ```
2. Read only the script output. **Do not open the files it lists** unless the map
   itself is ambiguous about which category a hit belongs to.

## Output contract

Return only the script's markdown table, its **Unresolved** section, and the final
"Saved to .context/context-map-\<keyword\>.md" line. No prose introduction. No
summary paragraph. No code.

## Rules

- **Never** treat the map as authoritative — it reports where sources exist, not which
  one is correct. Resolving a disagreement between sources is a separate step
  (`scripts/authority.sh`, or a human decision if no compiler check applies).
- Never state which source is correct, current, or authoritative, and never state that a
  dependency is or is not real. The map's "Unresolved" section is where those questions
  belong; evidence mechanisms and people with authority settle them.

If you were invoked as a subagent, this table is the entire value you return — make
every row carry something the caller cannot get without you.
