---
description: Generate this lab's context-engineering kit for a different repository — your own. Interviews you about your stack, then writes the equivalent skills, scripts, and instructions for that repo instead of Meridian's.
mode: agent
---

# Generate a Context Kit for This Repository

The Meridian lab ships seven tools hardcoded to one Java/Maven payments codebase. They
are reference implementations, not a library. Your job is to produce the equivalent kit
for the repository this is being run in, so the person asking never has to hand-port
anything.

## Step 1 — Interview before generating

Ask for whatever you cannot determine by looking at the repo yourself. Check first:
read the build file, the directory layout, and any CI config before asking a human
anything you could have answered by reading. Then confirm the gaps:

- **Build and test:** what command runs the tests, and where does it write a
  machine-readable report? (Surefire XML, `build/test-results/`, `jest --json`,
  `pytest --junit-xml`, `go test -json` — every mainstream toolchain has one.)
- **Dependency proof:** what settles "does A actually depend on B" at a tier stronger
  than text search in this language? (`jdeps` for JVM bytecode, `madge`/`ts-prune` for
  TS, `go mod why`, `pydeps`, `cargo tree -i`. If nothing exists, say so plainly rather
  than inventing one.)
- **Where truth lives:** which directories hold committed config, architecture
  decisions, tickets, and tests? This is what the routing table categorizes by.
- **The authority question:** is there a file in this repo that is authoritative for
  business values (rates, limits, flags) the way `config/fee-schedule.yaml` is for
  Meridian? If there isn't, that absence is itself worth reporting.

## Step 2 — Generate, in this order

For each tool below, write a `.github/skills/<name>/SKILL.md` plus the small script it
wraps. Match the frontmatter shape of the lab's existing skills exactly: `name`,
`description`, `context: fork`, `disable-model-invocation: true`, an input contract, a
one-line `Run:` workflow, and an output contract that says *return the digest only, no
prose*.

1. **`context-map`** — routing table for a keyword across this repo's actual
   directories. Prints paths, hit counts, and categories. Never file contents.
2. **`context-run test`** — runs the real test command, parses this repo's own
   machine-readable report, prints pass/fail counts and a regression line. **Must fail
   closed**: distinguish "0 failures because everything passed" from "0 failures because
   nothing ran." That guard is not optional — a reducer that hides a harness failure is
   worse than the noise it removed.
3. **`authority`** — text-tier vs. strongest-available-tier comparison for a dependency
   claim. If this language has no bytecode-equivalent check, generate the best available
   tier and **state its tier honestly in the output** rather than implying certainty it
   doesn't have.
4. **`outline`** — structure of one file (signatures and line ranges), never contents.

Stop there unless asked for more. Those four cover discover, reduce, and authority. The
register (`context-for`) and the verifier (`verify-change`) are task-specific by nature —
offer to generate them only if the person describes a specific recurring work unit or a
specific non-negotiable acceptance criterion to encode.

## Step 3 — Verify before you hand it over

Do not report success on generated code you haven't run. For each tool: run it, show the
real output, then **force it to fail** (point it at a nonexistent path, or break the
underlying command) and show that it exits non-zero with a clean error instead of a false
green. If a tool can't be made to fail closed in this environment, say which one and why.

## Rules

- Generate for **this** repository, not Meridian's. If you find yourself writing
  `com.meridian`, `fee-schedule.yaml`, or `LegacyPaymentUtils`, you have copied instead
  of ported.
- Prefer tools already installed with the language toolchain over anything requiring a
  new dependency. The lab's own constraint — nothing beyond what ships with the JDK and
  the build tool — is what made its kit portable in the first place.
- If a category genuinely has no good equivalent in this stack, say so and skip it. Four
  working tools beat six where two lie.
