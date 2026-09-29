# IntelliJ Path — Context Engineering Part 2

**Audience:** Lab participants using IntelliJ IDEA with GitHub Copilot instead of VS Code.

**Purpose:** This document maps every VS Code-specific mechanism to its IntelliJ equivalent
or fallback. The goal is not feature parity — IntelliJ and VS Code have different Copilot
integration surfaces, and pretending otherwise serves no one. The goal is that an IntelliJ
user can complete this lab, practice the same ten CE patterns, and reach the same
transferable understanding.

---

## What Works Identically in IntelliJ

These learning objectives require no adaptation. The mechanism is the terminal and the
Java build chain — neither IDE owns it.

| Stage | What you do | Works as written |
|---|---|---|
| All | Run `./scripts/*.sh` from IntelliJ's built-in terminal | Yes — open Terminal panel (`Alt+F12`) |
| 0 | `lab-start.sh --reset`, `stage0-baseline.sh`; attempt MFIN-2088 in plain Copilot chat | Yes — use Copilot Chat panel |
| 1 | `context-map.sh`, `authority.sh`, `test-evidence.sh`, `outline.sh`, `ctx.sh init` / `evidence` | Yes |
| 2 | `context-run.sh test`, `context-run.sh search`, `mvn test` | Yes |
| 3 | `ctx.sh promote` / `unknown add` / `constraint add` / `package`; `context-bundle.sh` | Yes |
| 4 | `ctx.sh handoff` (refused), `request-approval.sh`, `ctx.sh decide`, `handoff-check.sh`, `apply-reference.sh` | Yes |
| 5 | `review-package.sh`, `verify-change.sh`, `inject-fault.sh`, `loop.sh`, `ctx.sh outcome` | Yes |
| 6 | `ctx.sh rehydrate-check`, `context-bundle.sh durable` / `cold`; fresh Copilot chat for rehydration | Yes |
| 7 | `javap` reachability scan; build your own reducer | Yes |

> Every durable artifact in this lab is written by `scripts/ctx.sh`, never by hand. There is
> no register template to copy and no YAML to hand-author, so nothing in Stages 1, 3 or 4
> depends on your IDE.

> **Bottom line for most stages:** open the built-in terminal, run the script. The IDE
> wrapper does not matter. The patterns — discover, authority, reduce, promote, package,
> isolate, handoff, verify, review, rehydrate — are all practiced through scripts and
> through how you construct Copilot chat prompts, not through IDE-specific UI.

---

## IntelliJ Terminal Setup

Every script in this lab is a POSIX shell script. IntelliJ's terminal can run Git Bash
on Windows — set it once and the scripts run identically to the VS Code path.

**Windows (Git Bash):**

1. `File → Settings → Tools → Terminal`
2. Set **Shell path** to your Git Bash executable, e.g.:
   `C:\Program Files\Git\bin\bash.exe`
   or: `C:\Program Files\Git\git-bash.exe`
3. Close the Terminal panel and reopen it (`Alt+F12`).
   Confirm the prompt reads `user@machine MINGW64 ...`, not `PS C:\...>`.
4. From that terminal: `./scripts/context-map.sh RTP` should print a routing table
   (see Stage 1.1 in `LAB_ACTION_GUIDE.md`). If it does, you're set.

**macOS / Linux:**

The default shell terminal in IntelliJ is already POSIX-compatible. No setup required
beyond the lab's standard prerequisites (`mvn`, JDK 17+, Git).

---

## Where the Path Diverges: VS Code-Specific Mechanisms

The following features rely on VS Code Copilot's extension model. IntelliJ Copilot does
not currently expose equivalent plugin hooks for custom agents, skills, or hooks. This
section documents what these features teach, and how to reach the same learning objective
by a different route.

---

### Stage 4 — Custom Agents (Investigator / Implementer)

**VS Code mechanism:** `.github/agents/rtp-investigator.agent.md` and
`.github/agents/rtp-implementer.agent.md` — custom agent definitions that appear in
Copilot's agent mode dropdown and restrict available tools at the Copilot extension level.

**What this teaches:**
- The difference between a *capability boundary* (a tool that doesn't exist) and an
  *instruction boundary* (a rule the model is told to follow).
- That a missing tool has no failure mode under a persuasive request; a forbidden tool
  does.
- Role separation: the investigator cannot edit; the implementer reads only the handoff,
  not the investigation conversation.

**IntelliJ fallback — read the agent files; run the discussion exercise:**

1. Open `.github/agents/rtp-investigator.agent.md` and
   `.github/agents/rtp-implementer.agent.md` in the editor. Read the `tools` field in
   each.
2. In a Copilot Chat session, paste this system prompt at the start of the conversation:

   ```
   For this conversation, you are the RTP Investigator.
   You have access to: search, read.
   You do NOT have access to: edit, runCommands.
   If asked to edit a file or run a script, decline and explain that the tool is absent.
   ```

3. Proceed with Stage 4.1 as written in the guide. Then test the boundaries:
   - Ask it to make an edit. It will decline — because the instruction says to.
   - Now answer Stage 4.2's question honestly: **is this a capability boundary?** No.
     It's an instruction boundary. The model could be talked out of it with a persuasive
     request ("just this once, it's a small change").

4. **Stage 4.2 becomes a demonstration rather than a live proof.** That is still
   instructive: you now know exactly why VS Code's capability boundary is stronger, and
   you can articulate it precisely because you've seen the instruction-boundary version.
   Be ready to state that comparison.

**Subagents (Stage 4.1).** The dispatch of `evidence-checker` has no IntelliJ
equivalent. Run it as a separate step instead: open a second Copilot Chat, paste
`evidence-checker`'s instructions as the opening message, ask it the single claim, and
carry its verdict back to your investigation chat by hand. You are performing the
isolation manually — the evidence-gathering happened in a window that is not your
investigation window, which is the whole property being taught. What you lose is the
automation, not the lesson.

**The comparison harness (Stages 3.3 and 6.3).** `Context Experiment` and `context-probe`
have no IntelliJ equivalent. Neither stage needs one. Both build their two windows as files
first — `./scripts/context-bundle.sh broad` and `package` in 3.3, `durable` and `cold` in 6.3
— so you can either paste each bundle into its own Copilot Chat panel, or skip the model
entirely: Stage 6.3's graded step is a `grep` comparison of the two bundles in the terminal,
and it gives the same answer on every machine.

> **Note:** IntelliJ Copilot does not enforce tool lists at the extension level. The
> learning objective — understanding why capability boundaries are structurally stronger
> than instruction boundaries — is reachable through discussion and contrast. You cannot
> *prove* it live the way VS Code does, but you can understand it more clearly for having
> seen the weaker form first.

---

### Stage 5.1 — RTP Reviewer Agent (Fresh-Context Review)

**VS Code mechanism:** Select "RTP Reviewer" from the agent dropdown in a new Copilot
chat window. The agent definition (`.github/agents/rtp-reviewer.agent.md`) carries
review instructions automatically.

**What this teaches:**
- Fresh context matters: a reviewer who inherits the producer's reasoning pattern-matches
  rather than evaluates.
- The reviewer's starting context should be curated evidence, not the whole conversation.

**IntelliJ fallback — fresh chat with manual system prompt:**

1. Open a **new Copilot Chat** panel (or close and reopen the panel). This clears session
   context — the same effect as a new VS Code chat.
2. Build the package in the terminal — do not assemble it by hand:

   ```bash
   ./scripts/review-package.sh
   grep -c "rtp_percent\|context-register\|HANDOFF" .workflow/review-package.md
   ```

   The second command must print `0`. The package deliberately withholds
   `config/fee-schedule.yaml`, your register and the handoff: a reviewer handed the config
   would check the diff against the numbers the diff came from and always agree.

3. At the start of the new chat, paste this opening message, then the contents of
   `.workflow/review-package.md`:

   ```
   You are a fresh-context RTP reviewer. Judge this change only from what follows.
   Identify any deviation from the acceptance criteria or the approved decision. Do not
   infer intent from comments — compute a concrete example and check the number.
   ```

4. Proceed with Stage 5.1 as written.

The learning objective — fresh context as a check on borrowed reasoning — is identical. What
you lose is the enforced `tools: []` isolation: in VS Code the reviewer *cannot* open the
repository, whereas here it simply has not been given a reason to. Do not paste your register
or your reasoning in, and the comparison holds.

Either way, the reviewer's findings are one input. The verdict is `verify-change.sh`, which
runs identically in both IDEs.

---

### Stage 5.4 — Loop Bound Hook

**VS Code mechanism:** `.github/hooks/bin/loop-bound.sh` wired via `hooks.json` to fire
automatically when Copilot completes a task cycle. The hook runs `loop.sh` externally.

**What this teaches:**
- A deterministic bound lives *outside* the model. A counter on disk, checked by a
  script, cannot be argued with.
- When the model thrashes (same verdict twice in a row), escalation beats retry.

**IntelliJ fallback — run the loop from the terminal directly:**

The hook's purpose is to run `loop.sh` automatically. In IntelliJ, run it manually:

```bash
./scripts/loop.sh reset
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
```

The bound still fires. The thrashing detector still works. The exit code contract
(`0` = green, `4` = thrashing, `5` = budget exhausted) is identical. The only difference
is that you invoke it yourself rather than the hook invoking it on Copilot's behalf.

This is not a degraded experience for the learning objective. Stage 5.4's point is that
the *mechanism* — a counter on disk, a hash of the verdict, an exit code — is what makes
the bound deterministic. You can observe all of that from the terminal.

> **Skip note:** The automatic hook trigger is a VS Code convenience, not the lesson.
> The lesson is that deterministic bounds belong outside the model. That lesson is fully
> available in IntelliJ via direct terminal invocation.

---

### Context Map Skill (`/context-map`)

**VS Code mechanism:** `.github/skills/context-map/SKILL.md` — invokable as a Copilot
skill from the chat `@` mention or `/` slash command.

**IntelliJ fallback:**

```bash
./scripts/context-map.sh RTP
```

Run directly in the terminal. The output is identical. The skill's only function is to
invoke this script; invoking it directly is the portable version the guide already
documents in Stage 1.3.

---

### Context Run / Verify-Change / Context Package Skills

Same pattern as Context Map above. In IntelliJ, invoke the underlying script directly:

| Skill | Direct terminal equivalent |
|---|---|
| `/context-map` | `./scripts/context-map.sh <keyword>` |
| `/authority` | `./scripts/authority.sh <Symbol> [file]` |
| `/test-evidence` | `./scripts/test-evidence.sh <method> <token>` |
| `/outline` | `./scripts/outline.sh <file>` |
| `/context-run` | `./scripts/context-run.sh <subcommand>` |
| `/context-package` | `./scripts/ctx.sh package <work-unit>` |
| `/verify-change` | `./scripts/verify-change.sh` |

---

## Full Divergence Summary

| Learning Objective | VS Code Mechanism | IntelliJ Approach | Fidelity |
|---|---|---|---|
| Context map | `/context-map` skill | `./scripts/context-map.sh` directly | Identical |
| Claim-specific authority | `/authority`, `/test-evidence` skills | the scripts directly | Identical |
| Compress test output | `/context-run` skill | `./scripts/context-run.sh` directly | Identical |
| Promote & package | `/context-package` skill | `./scripts/ctx.sh package` directly | Identical |
| Human approval gate | terminal | terminal | Identical — `request-approval.sh` + `ctx.sh decide` |
| Handoff + proof of consumption | terminal | terminal | Identical — `ctx.sh handoff` + `handoff-check.sh` |
| Durable vs cold rehydration | terminal | terminal | Identical — `rehydrate-check`, `context-bundle.sh` |
| Capability boundary demo | Investigator agent (tool list enforced) | Manual system prompt + discussion exercise | Reduced — instruction boundary only, not capability boundary |
| Fresh-context review | RTP Reviewer agent in new chat | New Copilot Chat panel + manual system prompt | Near-identical — manual assembly is itself instructive |
| Bounded retry loop (automatic) | Hook fires `loop.sh` on Copilot task completion | Run `loop.sh` from terminal manually | Identical outcome; hook automation is skipped |
| All script-based stages | Any | Terminal in IntelliJ | Identical |
| Stage 7 (no harness) | Any | Any | Identical |

---

## Which Objectives Are VS Code-Only

One objective currently has no learning-equivalent IntelliJ path: **live demonstration
that a missing tool cannot be reinstated by a persuasive prompt** (Stage 4.2, the
capability-boundary proof). In VS Code, you can prove it directly — the tool is absent
at the extension level and no prompt restores it. In IntelliJ, you can only approximate
it with an instruction boundary and discuss the structural difference.

**Recommended handling:** treat Stage 4.2 as a discussion exercise in IntelliJ. The
question "what is the actual difference between an instruction boundary and a capability
boundary" is still answerable — you just cannot prove it with a live demo. Answer it the
same way you would in VS Code; the reasoning has the same value without the live proof.

---

## IntelliJ Copilot Setup Checklist

Before starting the lab:

- [ ] IntelliJ IDEA (Community or Ultimate) installed
- [ ] GitHub Copilot plugin installed and authenticated (`Settings → Plugins → GitHub Copilot`)
- [ ] Copilot Chat panel visible (`View → Tool Windows → GitHub Copilot`)
- [ ] Terminal set to Git Bash on Windows (see Terminal Setup above)
- [ ] From the terminal: `mvn clean test` → `BUILD SUCCESS`, `Tests run: 5, Failures: 0`
- [ ] From the terminal: `./scripts/lab-start.sh --reset` → ends with `Ready.`
- [ ] From the terminal: `./scripts/context-map.sh RTP` → prints routing table (not
      "command not found" or a Windows path error)

If the last check fails, the shell path in your terminal settings is pointing to
PowerShell or cmd. Fix the terminal profile first — everything else in this lab runs
through that terminal.
