# Redesign Contract — Context Engineering, Part 2

**Date:** 2026-08-29
**Status:** DRAFT — requires human approval before any implementation begins

---

## 1. Problem Statement

Jeff's feedback:

> "I don't disagree with the content, my concern is how do we link it for
> associates so they understand how to implement the concepts themselves."

After two rounds of remediation the lab now explains the patterns behind its
scripts and tests pattern recognition (Stage 7) and planning (Stage 7B).
But the capstone is still a paper exercise — the learner writes a plan for
what they would build, rather than building it.

**The remaining gap:** the learner never constructs a working tool they can
take home. Planning what you would build is not the same as building it.
The moment the lab ends, the planning document has no residual value.
A working script or hook does.

**The fix:** replace the planning capstone (Stage 7B) with a construction
capstone: the learner uses Copilot to build their own context-optimization
tool — a reducer, a verifier, a context filter, or a noise-removal hook —
that they can use on Monday morning.

---

## 2. Part 1 / Part 2 Boundary

| | Part 1 | Part 2 |
|---|---|---|
| **Scope** | Single conversation | Task that outgrows one chat |
| **Core question** | How do I give Copilot the right context? | How do I engineer context across a multi-session task? |
| **Focus** | Prompt quality, cache reuse, mode selection, file targeting | Discovery, compression, promotion, packaging, handoff, verification, rehydration |
| **Copilot role** | Consumer of context the user provides | Collaborator that operates within engineered context boundaries |
| **Capstone** | (defined by Part 1) | Learner builds a working context-optimization tool using Copilot |

Part 2 assumes Part 1's vocabulary. It does not re-teach prompt engineering,
cache control, or mode selection.

---

## 3. Learning Outcomes

After completing Part 2, a learner can:

1. **Identify** where context lives in an unfamiliar repository before
   retrieving anything (discover before retrieve).
2. **Determine** which source is authoritative for a given claim and
   distinguish machine-verifiable evidence from inference (authority).
3. **Reduce** noisy tool output to decision-relevant signal outside the
   model's context window (compute before context).
4. **Promote** verified facts into durable artifacts and discard temporary
   investigation noise (context lifecycle).
5. **Package** context for a specific consumer — different roles need
   different context (packaging + handoff).
6. **Enforce** boundaries using capabilities, not instructions — and
   explain why (isolation).
7. **Verify** a change deterministically and bound repair attempts to
   prevent thrashing (verification + enforcement).
8. **Rehydrate** a task from durable artifacts in a fresh session
   (rehydration).
9. **Build** a working context-optimization tool for a problem they
   identified, using Copilot as the construction assistant (transfer).
10. **Decide** what kind of artifact a mechanism should become: disposable
    script, repo utility, Copilot hook, skill, agent, or CI gate
    (artifact-choice judgment).

Outcome 9 is the capstone. Outcomes 1-8 are taught through the RTP worked
example. Outcome 9 proves the learner can construct without the worked
example. Outcome 10 runs throughout.

---

## 4. Storyline

**Act 1 — "Use it, then see through it" (Stages 0-3, ~67 min)**

The learner uses the lab's prepared tooling on the MFIN-2088 RTP ticket.
Each tool is a worked example of a context-engineering pattern. After using
each tool, the learner deconstructs it: what does it actually do, what are
the raw commands behind it, what would the portable version look like?

The learner progresses from observer to author: by Stage 3, they fill a
blank context register from their own findings rather than copying one.

**Act 2 — "Cross the human boundary" (Stages 4-6, ~50 min)**

The learner encounters boundaries the tooling cannot cross: a conflict that
requires human authority (Stage 4), a bug that a fresh reviewer catches
(Stage 5), a verification failure that triggers a bounded repair loop.
The tools enforce structure, but the human makes the decisions.

By Stage 6, the learner proves the durable artifacts survive session death
— a fresh chat reconstructs the task from artifacts alone.

**Act 3 — "Build your own" (Stage 7, ~40 min)**

The scaffolding comes off. First, the learner recognizes a pattern in a
new problem without being told which pattern applies (7.1-7.3). Then — the
capstone — the learner builds a working context-optimization tool for a
real problem, using Copilot as the construction assistant. They spec it,
build it, validate it, and decide where it lives. They walk out with a
real artifact, not a plan.

---

## 5. Stage Responsibilities

### Stages 0-6: Unchanged in intent

These stages remain as-is from the current remediation. Their job is to
teach the ten patterns through the RTP worked example with the
USE -> DECONSTRUCT -> BUILD progression already established.

No structural changes. Minor wording adjustments only if the capstone
requires setup (e.g., earlier mention of hooks as a deployment target).

### Stage 7.1-7.3: Pattern Recognition (keep, ~15 min)

**Unchanged.** The CurrencyConverter exercise tests whether the learner can
recognize which patterns apply to a problem the lab never solved for them.
This is the RECOGNITION test. The capstone is the CONSTRUCTION test.
Both are needed.

### Stage 7.4 + 7B: REPLACED by "Build Your Own Tool" (~25-30 min)

**What it replaces:**
- Stage 7.4 (abstract reducer spec exercise — learner specs but doesn't build)
- Stage 7B (planning exercise — learner plans but doesn't build)

**What the new capstone does:**

```
Step 1 — Pick your noise problem (3 min)
  From a structured menu OR name your own:
  - Test output (any framework)
  - Dependency tree (mvn dependency:tree, npm ls, pip freeze)
  - Build/compile warnings
  - Git history (log, blame, diff-stat)
  - Static analysis / linter output
  - API response body
  - Your own: ___

Step 2 — Spec the tool (5 min)
  The learner writes the 4-property spec BEFORE touching Copilot:
  - Decision this tool serves
  - Signal source (command + output format)
  - Minimum fields to retain
  - Failure mode (how it fails closed)

  This is the gate. The spec proves the learner understood the pattern.
  Without it, the exercise becomes "ask Copilot to write a script."

Step 3 — Build with Copilot (10-12 min)
  - Give Copilot the spec as a prompt
  - Review what Copilot produces against the spec
  - Run it against a real noisy command in this repo
  - Force a failure — verify non-zero exit (fail-closed check)
  - Iterate if needed — the iteration IS the learning

Step 4 — Decide where it lives (5 min)
  Using the artifact-choice table from Stage 5.3:
  - Disposable script (delete after)
  - Shell alias (personal convenience)
  - Repo script in scripts/ (team utility)
  - Copilot hook (automatic noise reduction)
  - CI gate (deterministic pipeline check)

  Wire it into ONE of these and run it once from that location.

Step 5 — Record (3 min)
  In stage-readings:
  - The noisy command and its raw line count
  - The reduced output and its line count
  - What was kept, what was discarded, why
  - The failure mode and how it was tested
  - Where the tool lives and why that deployment choice
```

### Debrief (5 min)

Shortened. The "Ten Patterns" reference card remains. The planning
exercise is gone (the capstone replaced it). The artifact-choice table
moves earlier (Stage 2 or 3, per existing remediation finding F10).

---

## 6. Copilot Customization Model

Copilot customization in this lab serves two purposes:

| Purpose | What | Example |
|---|---|---|
| **Worked example** | The lab ships agents, skills, and hooks as demonstrations of context-engineering patterns | `rtp-investigator` demonstrates capability boundaries; `context-run` skill demonstrates compute-before-context; `quiet-build` hook demonstrates automatic noise reduction |
| **Construction tool** | In the capstone, Copilot is the assistant that helps the learner build their own tool | The learner prompts Copilot with their reducer spec; Copilot writes the script; the learner validates and iterates |

**What we teach about customization:**
- Skills and hooks are DEPLOYMENT TARGETS for context-engineering patterns, not the patterns themselves
- A hook that reduces noise is an instance of "compute before context"
- A skill that wraps a script is an instance of "reusable context packaging"
- The learner's capstone tool can become a hook, a script, or a CI gate — the pattern is the same

**What we do NOT teach:**
- How to write Copilot extensions
- The full hook/skill/agent API surface
- How to build MCP servers
- How to configure hooks.json from scratch

The lab shows enough of the customization surface for the learner to
understand that their tool CAN be deployed as a hook, but the hook-wiring
is a 2-minute demonstration, not a tutorial.

---

## 7. Jeff Acceptance Criteria

Every criterion is testable. "Testable" means a fresh observer can
determine PASS/FAIL without interpretation.

| # | Jeff's concern (paraphrased) | Acceptance test |
|---|---|---|
| J1 | "How do I apply this in my day to day workflow?" | The learner leaves with a working tool they built for a problem they identified. The tool runs outside this lab repo. |
| J2 | "Nothing explains how it worked" | Every script the learner runs has a portable-version callout showing the raw commands behind it. At least 5 of 11 scripts are deconstructed. |
| J3 | "How to implement this for their own repo" | The capstone requires the learner to implement a context-optimization tool from a spec they wrote, using Copilot, validated against a real noisy command. |
| J4 | "Users would not have these available" | Stage 7 bans all lab scripts, agents, and skills. The capstone uses only Copilot + standard tools. |
| J5 | "How do we link it for associates" | The ten-pattern reference card frames each pattern as a question, not a script name. The artifact-choice table teaches when to build what kind of mechanism. |

---

## 8. Capstone Acceptance Criteria

The capstone ("Build Your Own Tool") must satisfy ALL of these:

| # | Criterion | Rationale |
|---|---|---|
| C1 | The learner writes the 4-property spec BEFORE prompting Copilot | Proves they understood the pattern, not just the tool |
| C2 | The tool runs against a real command and produces reduced output | Proves the tool works, not just compiles |
| C3 | The tool fails closed when the underlying command fails | Proves the learner internalized the fail-closed invariant |
| C4 | The learner can state what was discarded and why | Proves deliberate design, not accidental filtering |
| C5 | The tool is wired into a deployment target (script, alias, hook, or CI) | Proves the learner made an artifact-choice decision |
| C6 | The learner did NOT copy the RTP reducer pattern verbatim | The tool addresses a different problem category than context-run.sh's test-output reduction |
| C7 | Total capstone time is under 30 minutes | The lab must fit a deliverable session format |
| C8 | A learner who fails the capstone has concrete feedback on which step broke down (spec, build, validation, or deployment) | The exercise has diagnostic value, not just pass/fail |

---

## 9. Time Budget

| Block | Stages | Duration | Change from current |
|---|---|---|---|
| Act 1 — Use and deconstruct | 0, 1, 2, 3 | ~67 min | Unchanged |
| Act 2 — Cross the human boundary | 4, 5, 6 | ~50 min | Unchanged |
| Act 3 — Recognition | 7.1-7.3 | ~15 min | Unchanged |
| Act 3 — Capstone: Build Your Own Tool | 7-final | ~25-30 min | Replaces 7.4 (10 min) + 7B (10-15 min) |
| Debrief | — | ~5 min | Shortened (planning exercise removed) |
| **Total** | | **~162-167 min** | **Net change: +0 to +5 min** |

**Delivery format options** (decision deferred to timed dry run):

- **Option A (recommended): Two 80-minute sessions.** Part A: Stages 0-5 (Acts 1-2). Part B: Stages 6-7 + Capstone + Debrief (Act 3). The gap between sessions strengthens the capstone — learners have time to think about what they want to build.
- **Option B: 120-minute full session** with condensed-path cuts in Stages 1, 3, 5.
- **Option C: 90-minute core + 45-minute extension.** Core: Stages 0-6. Extension: Stage 7 + Capstone.

---

## 10. Non-Goals

This lab does NOT attempt to:

1. **Teach shell scripting.** The capstone is about the PATTERN (spec a
   reducer, validate it fails closed, choose a deployment target), not
   about bash syntax. Copilot writes the script. The learner makes the
   design decisions.

2. **Tour GitHub Copilot features.** Agents, skills, and hooks appear as
   worked examples of CE patterns, not as features to learn. The lab
   teaches when and why to use each mechanism, not how to configure
   hooks.json from scratch.

3. **Build production infrastructure.** The capstone tool is a working
   prototype, not a production-grade CI pipeline. It should work, fail
   closed, and be useful — not be polished.

4. **Cover multi-repo context management.** Deferred to a future lab.
   This lab is single-repository throughout.

5. **Teach prompt engineering.** That is Part 1's responsibility.

6. **Replace human judgment with automation.** Every stage maintains the
   pattern: AI investigates -> deterministic evidence -> human decides ->
   controlled next action. The capstone tool is a tool the human
   deploys, not an autonomous agent.

7. **Make every script generic.** The RTP scenario is a worked example.
   Scripts are intentionally specific to that scenario. The
   transferable method is taught through deconstruction and the capstone,
   not through parameterized scripts.

---

## 11. Invariants

Implementation of this redesign MUST NOT violate:

### Pedagogical invariants

1. **Spec before code.** In the capstone, the learner writes the 4-property
   spec before prompting Copilot. This gate is non-negotiable. Without it,
   the exercise proves Copilot can write scripts, not that the learner
   understood the pattern.

2. **Fail-closed is tested, not assumed.** Every deterministic mechanism
   must be tested with a forced failure. The capstone tool must demonstrate
   non-zero exit on a failed underlying command.

3. **Worked examples stay specific.** The RTP scripts remain RTP-specific.
   Transferability comes from deconstruction + capstone, not from making
   scripts generic.

4. **Deconstruct before construct.** No construction exercise appears before
   the corresponding pattern has been demonstrated and deconstructed.
   The capstone comes AFTER Stages 0-6 teach the patterns.

5. **Recognition before construction.** Stage 7.1-7.3 (pattern recognition)
   comes before the capstone (pattern construction). The learner must show
   they can identify which patterns apply before they build an instance.

### Technical invariants

6. **Capability boundaries are real.** If the lab claims a tool is missing,
   it must actually be missing. No policy boundaries presented as
   capability boundaries.

7. **No answer leakage across stage boundaries.** Scaffolding files must
   not reveal answers the learner is supposed to discover. Agent
   definitions, hooks, instructions, and skills must not contain literal
   rates, bug diagnoses, or authority resolutions.

8. **Human-in-the-loop decisions are genuine.** The answer to any human
   decision point must not be inferrable solely from scaffolding files
   available before the decision stage.

9. **The reducer fails closed.** `context-run.sh` must exit non-zero when
   Maven fails, regardless of stale reports. (Already fixed — do not
   regress.)

### Structural invariants

10. **Platform parity is honest.** If a mechanism requires VS Code, say so.
    IntelliJ fallbacks are documented, not hidden. Git Bash on Windows is
    a stated dependency.

11. **Published duration matches a dry run.** The session length on any
    marketing or curriculum document must reflect a timed dry run by a
    non-builder, not builder estimates.

12. **The capstone is self-contained.** A learner who completes Stages 0-6
    has everything they need for the capstone. No hidden dependencies on
    content outside the lab, external repos, or additional setup.

13. **Construction exercises produce artifacts, not prose.** The capstone
    output is a working script/hook, not a planning document or a
    reflection paragraph.

---

*This contract governs all subsequent implementation. No changes to
LAB_ACTION_GUIDE.md, stage-readings, or skills may contradict the
invariants above without updating this contract first.*

*DO NOT IMPLEMENT. This document is a contract, not a plan.*
