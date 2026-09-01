---
name: outline
description: Print the method and field structure of a Java file — signatures and line ranges only — without sending the file's contents into context. Use before you need to reference or edit one method in a large file. Returns a structural outline, not the file.
context: fork
disable-model-invocation: true
---

# Outline

Give shape without content — orient on a large file in a couple hundred tokens instead
of attaching the whole thing.

## Input contract

- One or more file paths, e.g. `src/main/java/com/meridian/payments/PaymentService.java`

## Workflow

1. Run:
   ```
   ./scripts/outline.sh <file.java> [file.java ...]
   ```
2. Read only the script output.

## Output contract

Return only the script's method/field list with line ranges. No prose introduction. No
summary paragraph. No code, and do not paste the file's actual contents even if you can
see them — the point is retrieving shape, not content.

## Rules

- **Never** substitute this for reading the actual method body when the task requires the
  logic itself — this tells you *where*, not *what*. Once you know the line range,
  retrieve only that span (`#selection` on the highlighted method), not the whole file.

If you were invoked as a subagent, this outline is the entire value you return — make it
self-sufficient for whoever receives it next.
