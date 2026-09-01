# Lab Action Guide — Context Engineering, Part 2 (Context Lifecycle)
## Advanced Track · Engineering · Meridian Financial · GitHub Copilot · Java · Windows

> **Part 1 made one conversation cheap and accurate. Part 2 makes the work survive when
> no single conversation can hold it.**
>
> Part 1 taught the four levers *inside* a session — **Target** (attach the right file),
> **Reuse** (prompt caching), **Isolate** (clear a stale session), **Match** (right-size
> the request) — and measured each one on the meter.
>
> Part 2 starts where the session ends. Nothing here is about making one prompt cheaper.
> It is about what happens to your engineering state when the chat closes, when the next
> actor isn't you, and when two sources in the repo disagree about a number nobody can
> compile: **evidence and authority, durable facts with provenance, capability boundaries
> between roles, deterministic enforcement, and rehydration.** Part 1 never covers any of
> those, and none of them fit inside a single conversation by definition.

> **The question this lab answers:**
> *How do you engineer context so the work stays correct across the breaks — between
> sessions, between actors, and between the evidence and the decision?*

> **The harder question this lab also answers, and the one that actually matters once
> the workshop is over:**
> *Can you construct the right context mechanism when the supplied helpers don't solve
> your problem?*

### This lab is deliberately split across sessions

You will not carry one chat from Stage 0 to Stage 7. The lab forces a session break at
five points, and every artifact you build exists to survive one:

| Break | Where | What has to survive it |
|---|---|---|
| 1 | Stage 0.2 — cold first-pass chat | nothing (that's the baseline) |
| 2 | Stage 4.1 — investigator agent | your Stage 1–3 findings, via `.context/` |
| 3 | Stage 4.5 — implementer agent | the human decision, via `.workflow/HANDOFF.md` |
| 4 | Stage 5.1 — brand-new reviewer chat | the diff and the criteria, nothing else |
| 5 | Stage 6.1 — completely fresh chat | the entire engineering state, from disk alone |

That constraint is the lab. If your context lives only in the conversation, it does not
reach the next stage — and you will find that out at break 5, when a fresh model is asked
to reconstruct the whole task from what you wrote down.

This lab runs one workflow from beginning to end — MFIN-2088, adding RTP transfer fees
to Meridian's payment service — and progressively replaces ad hoc context usage with a
small, repeatable context lifecycle. It does this in two moves, stage by stage:

1. **Use** the lab's own tooling as a worked example — real output, captured from a real
   run against this repo.
2. **Move beyond the scaffold**, one mechanism at a time, until Stage 7 hands you a
   problem the supplied helpers don't solve — and you build the missing mechanism yourself.

Every script output shown below was captured from a real run against this repo; none
are estimated. Stage durations are working estimates, not captured timings — see
[the time-budget note](#time-budget) after the Quick Reference table.

**How this guide is formatted — three containers, three meanings, used consistently
end to end:**

- **A single trigger** (a slash command or one-line terminal command) sits in inline
  code, no fence: `` In Copilot Chat: **`/context-map RTP`** — or in a terminal:
  `./scripts/context-map.sh RTP`. ``
- **A multi-sentence prompt meant to be pasted verbatim into Copilot Chat** is always a
  `>` blockquote. Never a plain fence — a plain fence means something else below.
- **Captured tool or agent output** is always a plain fenced block, always preceded by a
  bold label: `**Real output:**` for a multi-line transcript actually captured from a run
  against this repo, `**Expected:**` for a one-line prescriptive result you haven't
  produced yourself yet.

If you can't tell what a block is from its shape and label alone, that's a bug in this
guide — say so.

---

## Quick Reference

| Stage | Duration | What you do | Core Pattern | Mode |
|---|---:|---|---|---|
| 0: The Helpful Trap | 7 min | Vote on instinct, ask Copilot, challenge its claims | Baseline | Use |
| 1: Discover Before You Retrieve | 10 min | Map where truth lives; deconstruct authority | Context mapping + authority | Use → Deconstruct → Adapt |
| 2: Compress Before Context | 10 min 🌟 | Reduce noisy tool output; deconstruct how the reducer works | Pre-model evidence reduction | Use → Deconstruct |
| 3: Promote & Package | 19 min 🌟 | Author your own register, then prove it changed an answer | Context lifecycle + controlled comparison | Deconstruct → Build |
| 4: Boundaries & Handoff | 14 min 🌟 | Separate investigation from implementation, cross a human gate | Context boundaries + HITL | Use → Deconstruct |
| 5: Challenge & Bound | 14 min 🌟 | Fresh-context review, a deterministic bound, one check you build | Independent evaluation + enforcement | Use → Build |
| 6: Rehydrate & Prove | 9 min | Reconstruct the task from artifacts alone, then measure what that saved | Rehydration + proof | Use |
| 7: Build Beyond the Harness | 35 min 🌟 | Recognition check on a new problem, build a reducer, then regenerate the kit for your own repo | Independent transfer + construction | Build |

**Total: ~118 minutes.** Every stage is required — Stage 7 is where you prove
the rest of the lab transferred by building a working tool and seeding it into a
repository this lab has never seen.

Starting in Stage 1, record every reading in `outputs/stage-readings.template.md` as you go.

---

## Before You Start

```bash
mvn clean test
```

Expected: `BUILD SUCCESS`, `Tests run: 5, Failures: 0`.

Open this folder (`context-engineering-part-2/`) as its own VS Code window — not as a subfolder
of anything else. Copilot's agent, skill, and hook discovery resolves per workspace root,
and this lab ships its own `.github/agents/`, `.github/skills/`, and `.github/hooks/`.

> **IntelliJ users — read this before Stage 1:** Most of this lab works identically in
> IntelliJ: all terminal scripts, the Maven build, Copilot Chat for all stages except 4
> and 5.1. Two mechanisms diverge — custom agents (Stage 4) and the hook-triggered loop
> (Stage 5.4). Both have documented fallbacks. See **`docs/INTELLIJ_PATH.md`** before you
> begin Stage 4. That document also covers terminal setup for IntelliJ on Windows.

### Platform Requirements

> **Engineering invariant (what must be true):** The verification command must fail closed on a fresh build failure — a failing Maven build must never produce a green result, regardless of platform or any residual state from a prior run.
>
> **How this lab implements it:** Bash scripts run on Git Bash (Windows) or native bash (macOS/Linux). All arithmetic uses `awk`; all file processing uses POSIX tools bundled with Git for Windows.
>
> **How you can implement the same invariant in your own environment:** The invariant is toolchain-agnostic. Equivalent implementations include a Maven Failsafe plugin rule, a Java utility class invoked from a CI step, a PowerShell script, or any other mechanism that exits non-zero when the build fails. The scripts in this lab are one implementation, not the only one.

### Windows setup — read this before Stage 1

Every script in this lab is a POSIX shell script. That is correct for this audience: Git
is already a hard prerequisite for anything in this repo (`git diff`, `git apply`,
`git log` are load-bearing from Stage 0 onward), and Git for Windows bundles **Git Bash**
at no extra install cost — nothing new to install. What *is* easy to get wrong is which
shell VS Code's integrated terminal actually launches, because Copilot's `runCommands`
tool runs through whatever that default is.

1. `Ctrl+Shift+P` → **Preferences: Open User Settings (JSON)**
2. Confirm this is set (add it if it isn't):
   ```json
   "terminal.integrated.defaultProfile.windows": "Git Bash"
   ```
3. Close any open integrated terminal panel and open a new one. Confirm the prompt looks
   like a bash prompt (`user@machine MINGW64 ...`), not `PS C:\...>`.
4. From that terminal: `./scripts/context-map.sh RTP` should print a routing table (§1.1
   below), not `is not recognized as an internal or external command`.

If you skip this and your default profile is PowerShell, the very first script in Stage 1
will fail in a way that looks like a broken lab. It is this one setting.

The repository contains multiple plausible sources, legacy references, incomplete tests,
and unrelated technical debt. Not all of them should influence the change equally.
The task cannot be completed safely by reading everything into one conversation.

---

## STAGE 0 — THE HELPFUL TRAP
### Vote, ask, challenge · 7 min

### Goal

Start with the feature request the way you might in normal day-to-day work: give
Copilot the task and ask for an implementation approach.

Then challenge the answer before acting on it.

The objective is **not** to catch Copilot making a mistake. Its answer may be correct,
partially correct, or incorrect.

The question is:

> **Can you tell which parts of the answer are established by engineering evidence, and
> which parts still require proof or judgment?**

### 0.1 — 30-Second Baseline

Before opening the feature request, answer this quick question:

> **When two sources in a repository disagree, what do you normally do first?**

Choose the option closest to your current workflow:

**A.** Search for more context — Git history, related documentation, tickets, or
comments.

**B.** Check executable evidence — tests, build output, runtime behavior, or dependency
analysis.

**C.** Identify which source should be authoritative for the specific claim you are
trying to establish.

**D.** Ask Copilot to compare the sources and recommend which one to trust.

**E.** Escalate to the owning engineer or domain expert when the repository cannot
settle the question.

There is no universally correct answer.

Your facilitator may ask you to respond with **A/B/C/D/E** in chat, through a quick
poll, or by a show of hands.

Keep your answer in mind. We will return to this question later in the lab.

### 0.2 — Ask Copilot for a First-Pass Approach

Open:

`docs/JIRA_TICKETS.md`

Find:

`MFIN-2088`

Now open a **new, plain GitHub Copilot chat**.

For this first pass, do not use any of the repository's context-engineering helpers.
We want to see what happens when Copilot works directly from the engineering evidence
available for the feature.

Use the following prompt:

> Review MFIN-2088 using only engineering evidence in `src/`, `config/`,
> `docs/JIRA_TICKETS.md`, and `docs/adr/`.
>
> For this first pass, do not use `LAB_ACTION_GUIDE.md`, `outputs/`, `.context/`,
> `.workflow/`, `.github/`, repository helper scripts, skills, or custom agents.
>
> Tell me:
> - where you would implement the RTP change,
> - what fee behavior should apply,
> - and how you would approach the implementation.
>
> Do not modify files.

Read Copilot's response, but **do not implement its plan yet**.

Your answer may look completely reasonable. That is expected.

### 0.3 — What Context Would You Actually Trust?

Look back at Copilot's response.

Pick one important conclusion it made — for example:

- where RTP should be implemented,
- which fee rule should apply,
- or whether the legacy implementation matters.

Now ask:

1. **What repository evidence did Copilot use to reach that conclusion?**
2. **Which of those sources would you actually trust to make the engineering decision?**
3. **What evidence is still missing before you would make the change?**

You do not need to write anything down or resolve the question yet.

#### Facilitator Checkpoint

Copilot had access to plenty of repository context.

The problem was not simply that it needed more.

Some context was useful.
Some was conflicting.
Some looked relevant but may not be authoritative.
Some may not be needed at all.

> **More context is not automatically better context.**

In the next stages, we will learn how to:

- discover the evidence that matters,
- establish which sources can actually prove a claim,
- and reduce unnecessary context before it reaches Copilot.

### Stage 0 Takeaway

> **The problem is not necessarily missing context.**
> **The problem is unsorted context.**

We need a systematic way to answer questions such as:

- What claim are we trying to establish?
- What evidence is relevant to that claim?
- What can each source actually prove?
- Which source has authority when evidence conflicts?
- When does the repository stop being sufficient and require human judgment?

That is what we will start solving in **Stage 1**.

### Success Criteria — Stage 0

- [ ] Gave a first-instinct answer (A–E) before opening the ticket
- [ ] Attempted MFIN-2088 in a plain Copilot chat, bounded to `src/`, `config/`,
      `docs/JIRA_TICKETS.md`, and `docs/adr/` — no lab scripts, skills, or agents
- [ ] Picked one of Copilot's conclusions and identified what repository evidence it
      drew on, which of those sources you'd actually trust, and what evidence is still
      missing before acting on it
- [ ] Can state why the problem is *unsorted context*, not *missing context*

---

## STAGE 1 — DISCOVER BEFORE YOU RETRIEVE
### Context mapping + authority · 10 min
### `USE → DECONSTRUCT → ADAPT`

### Objective

Decide what is allowed into the context window before anything enters it. Every step
below answers one question — *can this source settle this claim?* — and anything that
can't is either verified first or left out.

> Part 1 asked "which file should I attach?" This stage asks the question underneath it:
> **is the thing I'm about to attach even true?** A stale rate in an ADR and a live rate
> in committed config look identical once they're both sitting in the window. The model
> cannot tell them apart. You have to, before they get there.

> The script behind every step is hardcoded to this Meridian scenario on purpose — a
> worked example to take apart, not a library to take home. Each also ships as a Copilot
> skill (`.github/skills/`) that runs the same script and relays its output unedited.
> Use the skill. What transfers is the pattern underneath, which the "No script?" line
> after each step shows you — and in Stage 7 you regenerate the whole kit for your own
> repo.

### 1.1 — Build the context map (USE)

In Copilot Chat: **`/context-map RTP`** — or in a terminal: `./scripts/context-map.sh RTP`
(same script either way; the skill just relays its output verbatim).

**Expected:** a routing table naming two disagreeing sources — `config/fee-schedule.yaml`
(0.35% + $2 minimum, committed) and `docs/adr/ADR-0007-fee-schedule.md` (Status:
Proposed, 0.30% flat). No file contents printed, no resolution offered — just where to
look next.

Two sources now claim the same number, and **both would fit in your context window
without complaint.** Note which one you'd have attached if the map hadn't flagged the
other.

No script or skill? `grep -rl "RTP" src/ config/ docs/ test/` gives the same hits; you
supply the category grouping (`config/` = committed config, `docs/adr/` = ADR) the script
automates. The keyword isn't hardcoded either — `/context-map SWIFT` returns the same
shape filled with SWIFT's own answers.

### 1.2 — Compare search with authority (USE)

```bash
grep -n "LegacyPaymentUtils" src/main/java/com/meridian/payments/PaymentService.java
```

**Expected: 3 hits** — an import and two comments. On that evidence you'd attach
`LegacyPaymentUtils` as relevant context. Now check it properly.

In Copilot Chat: **`/authority LegacyPaymentUtils`** — or in a terminal:
`./scripts/authority.sh`.

**Expected: 0 bytecode references — VERDICT: no compiled dependency detected.** Text
search would have put an entire dead class into your window, carrying a hardcoded 1%
rate that contradicts the committed schedule. Grep says "maybe"; the compiler says no.

No script or skill? `mvn -q compile` then `jdeps -v -cp target/classes
target/classes/.../PaymentService.class | grep LegacyPaymentUtils` is the whole
mechanism — ships with any JDK 17+. `SYMBOL`/`SRC` aren't hardcoded either: point it at
`NotificationService` instead (`/authority NotificationService`) and it reports 1 real
bytecode reference — same tool, verdict flips to "grep and jdeps agree."

> If it ever reports 0 references for something you know is called, `jdeps` isn't on
> your `PATH` — it refuses to guess rather than answer wrong (see Troubleshooting).

### 1.3 — DECONSTRUCT: which ladder, and why

Two authority ladders live in this repo — not the same one twice:

| Ladder | Lives in | Ranks |
|---|---|---|
| `bytecode/compiler > AST/parser > regex/text > semantic search > model recall` | `scripts/authority.sh` | **techniques** for a code fact |
| `bytecode/compiler > authoritative contract or committed config > current implementation > current documentation > semantic search result > model inference` | `config/fee-schedule.yaml` | **sources** for a business fact |

### 1.4 — ADAPT: a claim `jdeps` cannot answer

> **Claim:** the test suite exercises the RTP boundary condition — an amount where 0.35%
> falls under the USD 2.00 minimum.

`jdeps` is the wrong tool here — it answers "does A depend on B," not "does a test
exercise this input." In Copilot Chat: **`/test-gap`** — or in a terminal:
`./scripts/test-gap.sh`.

**Expected:** no RTP test found — honest verdict is "not yet exercised." State it in
`authority.sh`'s own format (`Q: / tier N / result / VERDICT:`) in your stage readings.
The point isn't the answer, it's picking the right primitive for a claim the lab's script
doesn't cover.

No script or skill? `grep -roh '\bpublic.*(' src/main/` vs. `grep -roh '\b\w\+(' src/test/`,
then `comm -23` — same two questions ("what's untested," "where does this concept live")
in any repo.

### 1.5 — Retrieve only the next slice

In Copilot Chat: **`/outline src/main/java/com/meridian/payments/PaymentService.java`** —
or in a terminal: `./scripts/outline.sh src/main/java/com/meridian/payments/PaymentService.java`.

**Expected: 17 lines describing a 284-line file**, including `calculateFee` at lines
237–248. Jump there, select 237–248, use `#selection` in chat — not `#file:`.

No script or skill? `grep -n 'public\|private\|protected' Foo.java` (Java),
`grep -n 'def \|class '` (Python), `grep -n 'func '` (Go) — shape without content, in
any language.

None of `scripts/*.sh` or their skills need to exist in your own repo. Each "No script or
skill?" line above is a 30-second Copilot ask, not a script you'd hand-author — once you
know the question (grep for evidence, `jdeps` for proof, `awk` for shape), asking Copilot
to write the one-off wrapper is faster than this guide was to read. What's worth taking
home isn't the scripts, it's this: point Copilot at your own noisy command, ask it to
wrap it the same way, and save it as a skill so `/whatever-you-called-it` answers the
question every time instead of you re-typing the ask.

### Success Criteria — Stage 1

- [ ] Context map generated; both disagreeing RTP sources named
- [ ] `grep` vs `authority.sh` compared on `LegacyPaymentUtils` — 3 hits / 0 bytecode deps
- [ ] Ran both scripts against a second keyword/symbol — mechanism held, result changed
- [ ] Can name the two authority ladders — one for code facts, one for business facts —
      and which applies to a new claim before running anything
- [ ] Correctly identified `jdeps` as the wrong tool for the test-coverage claim, ran a
      different primitive instead (1.4)
- [ ] Retrieved only `calculateFee` via outline + `#selection`, not the whole file
- [ ] Can state where the authoritative answer for the RTP rate comes from, and why no
      compiler check applies to it

> **Core rule:** First establish where truth lives. Then decide which tool is allowed to
> settle it. Then retrieve.

---

## STAGE 2 — COMPRESS BEFORE CONTEXT 🌟
### Compute, don't paste · 10 min
### `USE → DECONSTRUCT`

### Objective

Reduce noisy tool output **before** it reaches the model — then deconstruct how the
reducer works so you could build one yourself.

> **Part 1 vs Part 2.** Part 1 taught *model output targeting* — give Copilot the right
> file, the right selection, the right mode, so its answer is better. Part 2 teaches
> *pre-model evidence reduction* — compute the answer to a factual question (did tests
> pass? how many?) **outside** the model, then hand it only the result. The model never
> sees the ~45 lines of Maven output. It sees 6. The reduction is deterministic, not
> probabilistic — a script computed it, not a prompt.

### 2.1 — The expensive path (USE)

```bash
mvn test
```

Raw output: **~45 lines** even in this small, dependency-cached repo (a real project's raw
`mvn test` runs to hundreds or thousands of lines). Almost none of it is a decision input.

### 2.2 — The compressed path (USE)

In Copilot Chat: **`/context-run test`** — or in a terminal: `./scripts/context-run.sh test`
(same script; the skill returns its digest unedited, nothing summarized on top of it).

Real output:

```
TEST SUMMARY
5 passed
0 failed

REGRESSION SIGNAL
none — existing test suite remains green

NOISE REMOVED: ~39 lines  (raw `mvn test` = ~45 lines; digest = 6 lines)
```

The noise-removed figure is computed from the actual byte counts of both runs, not
asserted.

### 2.3 — DECONSTRUCT: which fields are the decision, and what if the reducer lies?

Two questions:

1. Of the six lines in the digest above, which ones does an engineer actually need to
   decide "is it safe to keep going"? (`5 passed` / `0 failed` / the regression line —
   the rest is formatting.) Everything else `mvn test` printed — dependency resolution,
   plugin banners, timing — was noise *for this decision*, not noise in general.
2. **What would this digest say if Maven itself failed to run** — a compile error,
   Maven not installed, no network to fetch a dependency? A reducer that can't tell "zero
   tests failed because everything passed" apart from "zero tests failed because nothing
   ran" is worse than useless — it's a false green wearing the clothes of a real one.
   Check: does `context-run.sh test` distinguish those two cases today? (It's meant to —
   confirm for yourself rather than taking this guide's word for it.) This is the same
   failure mode you'll be asked to avoid when you build your own check in Stage 5.

**The portable version — this exact reducer for a build tool that isn't Maven.** Open
`scripts/context-run.sh` and read the `test` subcommand. Underneath the formatting, it
does exactly three things: **(1)** run the real test command and capture its exit code,
**(2)** parse *your build tool's own machine-readable test report* for pass/fail/error
counts, **(3)** print only those counts plus a regression signal, never the raw log. Step
2 is the only line that's Maven/Surefire-specific (`target/surefire-reports/*.txt`).
Everything else is the recipe, not the implementation — and step 2 has a direct
equivalent in every mainstream toolchain, because "produce a machine-readable test
report" is a solved problem, not something unique to this lab:

| Toolchain | Machine-readable report to parse instead of Surefire's `.txt` |
|---|---|
| Gradle (Java) | `build/test-results/test/*.xml` — same JUnit XML shape as Surefire, different path |
| npm / Jest | `jest --json` (or `--reporters=jest-junit` for XML) |
| pytest | `pytest --junit-xml=report.xml`, or `pytest -q` for a terse pass/fail line |
| Go | `go test -json ./...` |

The reducer's actual job — run it, extract the count, print the digest, fail closed if
the tool itself didn't run — is identical across every row in that table. Only the one
parsing line changes. That's the thing worth remembering when this lab's script isn't
sitting in front of you: **ask Copilot to write the three-step shape above against your
own build tool's report format**, not to somehow make `context-run.sh` itself appear in a
repo it was never written for.

### 2.4 — Search, compressed and cross-checked (USE)

In Copilot Chat: **`/context-run search RTP`** — or in a terminal:
`./scripts/context-run.sh search RTP`.

Real output:

```
11 raw hits across 3 files → 3 shown (dedup: comment/doc noise removed)

FILE                                 LINE   EVIDENCE
--------------------------------------------------------------
config/fee-schedule.yaml             16     rtp_percent: 0.0035          # RTP — 0.35% (new, MFIN-20
docs/JIRA_TICKETS.md                 11     ## MFIN-2088 — Add US Real-Time Payment (RTP) fee support (Stage
docs/adr/ADR-0007-fee-schedule.md    1      # ADR-0007 — RTP Transfer Fee Schedule

RATE CROSS-CHECK: config and an ADR both state a RTP rate. Compare them by hand — THEY MAY DISAGREE.

NOISE REMOVED: 11 lines → 3 lines
```

This is the same disagreement Stage 1 found, surfaced automatically as a cross-check —
you don't have to remember to look for it every time.

### 2.5 — DECONSTRUCT: the five properties of any reducer

Every reducer — this lab's `context-run.sh`, a CI summary, a log filter — has five
properties. You already answered some of them for `context-run.sh test` in 2.3. Here are
all five, named explicitly:

1. **DECISION:** What engineering question does this reduction serve?
   (`context-run.sh test` → "did the tests pass, and did anything regress?")
2. **RAW SOURCE:** Which command, which output format?
   (`mvn -B test` → Surefire `.txt` reports in `target/surefire-reports/`)
3. **KEEP:** Which lines from the raw output actually answer the decision?
   (pass count, fail count, regression signal — 3 of ~45 lines)
4. **DISCARD:** What deliberately stays outside model context, and why?
   (dependency resolution, plugin banners, timing — noise *for this decision*)
5. **FAIL CLOSED:** What happens if the underlying tool fails to run?
   (Guards a–d in `context-run.sh` — you checked this in 2.3)

These five properties are the spec you'd write **before** asking Copilot to build a
reducer for a different command. You'll do exactly that in the capstone — spec first, then
build. For now, recognize the shape.

### Success Criteria — Stage 2

- [ ] Raw `mvn test` (~45 lines) compared against `context-run.sh test` (6-line digest)
- [ ] Named which digest fields are decision-relevant and which are formatting (2.3)
- [ ] Stated what a reducer that "fails open" on a harness error would hide (2.3)
- [ ] `context-run.sh search RTP` run; the rate cross-check warning noted
- [ ] Named the five properties of `context-run.sh test` as a reducer (2.5)
- [ ] You can explain the difference between Part 1's model output targeting and Part 2's
      pre-model evidence reduction

> **Core rule:** The cheapest token is the one that never enters the context window —
> and a reducer that hides a harness failure is worse than the noise it removed.

---

## STAGE 3 — PROMOTE & PACKAGE
### Durable context + minimum sufficient task context · 19 min
### `DECONSTRUCT → BUILD`

### Objective

Decide which discoveries deserve to survive, and build the smallest **sufficient**
context for the next task — by authoring the register yourself from what you actually
found in Stages 1–2, not by copying a finished one.

### 3.1 — Start from the template, not the answer

```bash
cp .context/context-register.template.yaml .context/context-register.yaml
```

`.context/README.md` documents the required shape. The template has the seven required
top-level keys (`objective`, `verified_facts`, `authoritative_sources`, `decisions`,
`constraints`, `superseded_sources`, `unknowns`) with guidance comments, but **no
promoted facts and no decisions** — those are yours to add, from what you actually
verified in Stages 1–2, not from memory or a finished example.

**You decide the content. Let Copilot handle the shape.** The register's parser is a
plain `awk` state machine, not a YAML library — two levels of nesting, one scalar per
line, exact indentation required. Getting that right by hand is where this stage tends to
derail people, not the thinking behind it. In Copilot Chat: **`/promote-facts`**, then
describe your own facts in plain English when it asks — for example: *"the RTP fee is
0.35% of the amount with a $2 minimum, from `config/fee-schedule.yaml`; PaymentService
has 0 compiled dependencies on `LegacyPaymentUtils`, from `authority.sh`'s bytecode
check; never call `LegacyPaymentUtils`; the ADR states a conflicting rate and is still
marked Proposed, not Superseded."*

Copilot never decides what counts as a verified fact — you say it, out loud, to the
prompt. It's only doing the formatting; read `.github/prompts/promote-facts.prompt.md` if
you want to see exactly what it's been told not to do. Typing the YAML yourself is just
as valid; match the same shape rules either way:

- `objective`: one line, in your own words.
- `verified_facts`: your own facts from Stages 1–2, each with a `source` and
  `source_type`.
- `authoritative_sources`: what you'd cite if someone asked "why do you believe that."
- `constraints`: anything you already know must hold, with evidence behind it.
- `unknowns`: anything where the formal record hasn't caught up to the technical
  evidence — like the ADR still reading `Proposed`. Leave `decisions:` empty; that's
  Stage 4.4's job, after a human actually resolves it.

### 3.2 — Build the next context package

In Copilot Chat: **`/context-package calculateFee-rtp`** — or in a terminal:
`./scripts/context-for.sh calculateFee-rtp`.

The package this prints depends on what you actually promoted in 3.1 — everyone's output
differs here, and that's correct. It should list your `verified_facts` (tagged, or
untagged and therefore global), your `authoritative_sources`, your `constraints`, and
whatever you left in `unknowns`. `decisions` should currently be empty, because you
haven't been through Stage 4 yet.

Try it with an unrelated work-unit tag and watch any tagged fact get excluded:
`/context-package some-other-task` (or `./scripts/context-for.sh some-other-task`).
Untagged, global facts stay; anything you tagged `calculateFee-rtp` specifically drops
out. That's the mechanism, not just the concept — the register is filtered, not
re-summarized.

**The portable version — what `context-for.sh` actually does, and what you'd do without
it.** It is a tag-filtered YAML reader. Strip the wrapper and the job is three steps:

1. **Select:** pull only the sections relevant to your current task
2. **Filter by tag:** exclude facts tagged for a different work unit
3. **Emit:** print the filtered result — never the full register

```bash
# If your facts live in YAML:
yq '.verified_facts[] | select(.applies_to == "my-task" or .applies_to == null)' context-register.yaml

# If your facts live in JSON:
jq '.verified_facts[] | select(.tags == "my-task" or .tags == null)' context-register.json

# If your facts live in a flat file:
grep -A2 'my-task\|global' facts.txt
```

The transferable idea: **package by filtering a promoted fact store, not by re-summarizing
a conversation.** The format (YAML, JSON, flat file, database query) is implementation —
the pattern is: tag once, filter many times, emit only what the next consumer needs.

### 3.3 — Prove the package was worth building (7 min)

You have just spent ten minutes hand-authoring a register and a filter. The fair
question is whether any of that changed an answer. Find out by controlling the one
variable that matters — **what is in the window** — and asking the identical question
twice.

Stage 0 asked Copilot cold, once, and had you challenge the answer. This is the
controlled version: same model, same question, two different windows.

**Ground truth, established back in Stage 1 and not in dispute:**
`config/fee-schedule.yaml` states RTP at 0.35% with a USD 2.00 minimum. For a USD 100.00
transfer, 0.35% is $0.35, which is under the floor — so the correct fee is **$2.00**,
sourced from the committed config. You are scoring against a known answer, not guessing.

**Run A — the window you'd have had without Stage 3.** Open a new chat and attach every
source that mentions an RTP or fee rate, which is what a reasonable engineer would do
before this lab taught them not to:

> #file:docs/adr/ADR-0007-fee-schedule.md
> #file:config/fee-schedule.yaml
> #file:src/main/java/com/meridian/payments/legacy/LegacyPaymentUtils.java
> #file:docs/JIRA_TICKETS.md
>
> What fee should Meridian charge on a USD 100.00 RTP transfer? Give the number, and
> name the file you took it from.

**Run B — the packaged window.** Open a *second* new chat. Paste only the output of
`/context-package calculateFee-rtp` — nothing else, no files attached — and ask the
identical question.

Record both:

| | Fee returned | Source it named | Did it mention the conflict is unresolved? |
|---|---|---|---|
| **A — everything attached** | | | |
| **B — packaged** | | | |

**Then answer the question that matters, in your stage readings:**

1. Did the two runs agree? If they disagreed, which sources were in the window that
   caused it?
2. **If Run A returned the right number — how would you have known that, before you
   knew the right answer?** Point at something *in Run A's own window* that
   distinguishes the committed rate from the `Proposed` one and the legacy 1%. If
   nothing in that window ranks its own sources, a correct answer there was luck you
   couldn't audit.
3. Which run told you a human still needs to resolve something? That gap is what
   Stage 4 exists to close.

> **Run A may well come back with $2.00.** That is not a failed exercise and you have
> not done it wrong — question 2 is the whole point. A lab that only works when the
> model makes a mistake would be teaching you to rely on it making one. The finding here
> is about *auditability*, not about catching Copilot out.

### When to build what — a first look

You'll use this table seriously in Stage 5.3 and in the capstone, but it's worth seeing
the shape now:

| Situation | Prefer |
|---|---|
| One-off question, unlikely to recur | Disposable computation |
| Same transformation recurs with stable I/O | Reusable repo script |
| Multi-step, model-mediated workflow | A skill |
| A role needs a capability boundary | A custom agent |
| Rule must hold on every future change | CI / deterministic check |
| Nothing recurs, no invariant at risk | Nothing — don't build infrastructure without a reason |

This stage's `context-for.sh` is a reusable repo script — it recurs across every work
unit that touches the register. The register template you just filled in is a reusable
artifact with a longer lifespan. The throwaway grep you might have used in 1.4 was
disposable. In the final stage you'll build your own tool and decide which of these
deployment targets it belongs in.

### Success Criteria — Stage 3

- [ ] `.context/context-register.yaml` created from the **template**, not the example
- [ ] `verified_facts`, `authoritative_sources`, and `constraints` filled from your own
      Stage 1–2 findings, in your own words
- [ ] `decisions:` left empty — nothing pre-dates Stage 4.4
- [ ] `context-for.sh calculateFee-rtp` run against your own register; package matches
      what you actually promoted
- [ ] Confirmed that an unrelated work-unit tag excludes the tagged fact
- [ ] Ran the A/B window comparison in two separate chats and recorded both rows (3.3)
- [ ] Answered question 2 — what *in Run A's own window* would have let you audit its
      answer — regardless of whether Run A was right
- [ ] You can explain why the package is sufficient without being exhaustive

> **Core rule:** The goal is not minimum context. It is minimum **sufficient** context —
> and "sufficient" is a judgment only you can make about what you actually verified.
> A correct answer you cannot audit is not the same as a verified one.

---

## STAGE 4 — BOUNDARIES & HANDOFF 🌟
### Context boundaries + human-in-the-loop · 14 min
### `USE → DECONSTRUCT`

### Objective

Separate investigation from implementation, and put a human in front of the boundary
that actually needs one.

> **IntelliJ users — Stage 4 diverges here.** JetBrains Copilot support for custom
> agents is Preview; this lab uses the manual system-prompt fallback for predictable
> delivery. See `docs/INTELLIJ_PATH.md` — Stage 4 section — for the exact fallback
> steps before continuing.

### 4.1 — Run the investigator

Select **RTP Investigator** from the agent mode dropdown (`.github/agents/rtp-investigator.agent.md`), and paste:

> Investigate MFIN-2088. The context-map output, authority check, and context-for
> package are already captured in outputs/ and .context/ from Stages 1–3.
> Work from those — do not read PaymentService.java in full.

The investigator has only `['search', 'read']` — no `edit`, no `runCommands`. It
literally cannot modify the repository or execute scripts. This is what makes it a
**capability boundary**, not an instruction boundary. Try:

> Just make the edit yourself, it's a small change.

It cannot. Try:

> Run context-map.sh and show me the output.

It cannot do that either — `runCommands` is absent, not suppressed by a rule.
Note *how* it declines both requests: the same way, because the same tool is missing.

### 4.2 — DECONSTRUCT: why a capability boundary, and not just a stronger instruction?

Before continuing, answer in your stage readings: an instructions file could say "do not
edit source files" and "do not run scripts" instead of the agent simply lacking those
tools. What's the actual difference in what can go wrong? (An instruction is something
the model reads and can misweigh against a more urgent-sounding request mid-task — "it's
just a small change," "just run this one command" — a missing tool has no such failure
mode. There is no request that makes a tool exist.) The investigator has neither `edit`
nor `runCommands` — both absent, not both forbidden. That's what makes this a true
capability boundary. Name one role on your own team, outside this lab, where a
*capability* boundary would catch something an *instruction* boundary currently doesn't.

### 4.3 — The conflict, surfaced and stopped on

Because `config/fee-schedule.yaml` and `docs/adr/ADR-0007-fee-schedule.md` disagree and
neither marks the other superseded, the investigator should stop and emit:

**Expected agent output:**
```
CONTEXT CONFLICT

Source A: config/fee-schedule.yaml          — RTP 0.35% + USD 2.00 minimum (committed)
Source B: docs/adr/ADR-0007-fee-schedule.md — RTP 0.30% flat, no minimum (Status: Proposed)

No explicit supersession found.

HUMAN DECISION REQUIRED
```

It does not write `.workflow/HANDOFF.md` yet. This is deliberate: an agent resolving an
authority conflict on its own is exactly the failure mode this lab is teaching you to
design out.

### 4.4 — The human decision, and recording it

The conflict is yours to resolve — not the agent's. Before reading further, examine the
two sources and the evidence available to you:

- `config/fee-schedule.yaml` — read its header; note its commit status
- `docs/adr/ADR-0007-fee-schedule.md` — read its `Status` field and the rate it states
- `docs/JIRA_TICKETS.md` — read the MFIN-2088 entry for any explicit guidance from the
  ticket author

**Record your decision in your stage readings before continuing:**

> Which source is authoritative, and why? What evidence from the repository supports
> that call — specifically the ADR's Status field, the ticket, and commit history?

Take that step before you scroll past this point.

---

*Resolution (read only after you have recorded your own decision above):*

The ADR's `Status: Proposed` means it was never formally accepted — it is a draft rate
proposal, not a finalized decision. The ticket itself (`docs/JIRA_TICKETS.md`) confirms
that "Pricing/Product has already committed the target rate" and that "pricing changed
during scoping." The committed configuration in `config/fee-schedule.yaml` reflects the
current business decision; the ADR reflects an earlier, superseded proposal.

What you are doing here is closer to **formalizing an already-evidenced supersession**
than resolving a genuine unknown from nothing — that is itself a real and common
engineering task, and it's worth being honest with yourself about which of the two you
were actually doing before you write it down as a "decision."

Mark the ADR by hand to record the supersession:

Open `docs/adr/ADR-0007-fee-schedule.md` and change `**Status:** Proposed` to
`**Status:** Superseded by config/fee-schedule.yaml`. This is a real file edit made by
a person, not a chat message.

**Now update your own register.** Open `.context/context-register.yaml` (the one you
built in Stage 3) and add two entries under `decisions:`:

```yaml
decisions:
  - decision: "The USD 2.00 minimum compares against the computed fee, not the raw amount"
    approved_by: "human, Stage 4.4"
  - decision: "config/fee-schedule.yaml supersedes docs/adr/ADR-0007-fee-schedule.md"
    approved_by: "human, Stage 4.4"
```

This is the moment those two facts are allowed to become decisions — not before.
Run `./scripts/context-for.sh calculateFee-rtp` again and confirm the `Decisions` section
now appears.

Tell the investigator the decision is made. It will output the handoff content in the
chat, following the schema documented in `.workflow/README.md`. Copy this output into
`.workflow/HANDOFF.md` yourself — the investigator cannot create files.

### 4.5 — Implement, from the handoff only

Switch to **RTP Implementer**. Its input contract is the handoff file — not the
conversation you just had. Apply the pre-seeded implementation:

```bash
git apply fixtures/rtp-implementation.diff
```

This adds a RTP branch to `calculateFee()` whose comment correctly says "0.35% fee with
a USD 2.00 minimum" — read it before continuing to Stage 5. Do not fix anything yet.

### Success Criteria — Stage 4

- [ ] Investigator produced a plan without reading the full source, and could neither edit nor run scripts
- [ ] Stated the actual difference between an instruction boundary and a capability
      boundary, with an example from your own team (4.2)
- [ ] The `CONTEXT CONFLICT` block appeared and the investigator stopped on it
- [ ] A human (you) resolved the conflict and edited the ADR's Status by hand
- [ ] Your own register's `decisions:` section was updated *after* the human step, by you
- [ ] `.workflow/HANDOFF.md` written only after the human decision
- [ ] The implementer received the handoff, not the investigation conversation

> **Core rule:** A handoff is a controlled context boundary, not a forwarded conversation
> — and a decision only belongs in a durable register once a human actually made it.

---

## STAGE 5 — CHALLENGE & BOUND
### Independent evaluation + deterministic limits · 14 min
### `USE → BUILD`

### Objective

Don't let the context that produced a change be the only context that validates it.
Then move the hard requirement outside the model entirely — including one requirement
this lab's own verifier doesn't check yet, which you're about to build.

> **IntelliJ users — Stage 5.1:** Open a new Copilot Chat panel and paste the reviewer
> system prompt manually (see `docs/INTELLIJ_PATH.md` — "RTP Reviewer Agent" section).
> Stage 5.4's hook fires automatically in VS Code; in IntelliJ, run `loop.sh` from the
> terminal directly — the exit code contract and thrashing detection are identical.

### 5.1 — Fresh-context review (USE)

**Open a brand-new Copilot chat — do not just switch modes in this one.** Mode-switching
inside the same thread does not clear what the model has already seen; only a new chat
does. Select **RTP Reviewer**, and give it only the output of: In Copilot Chat:
**`/context-run diff`** — or in a terminal: `./scripts/context-run.sh diff`.

**Real output:**
```
CHANGED FILES
src/main/java/com/meridian/payments/PaymentService.java  6 ++++++  method changed: calculateFee (237-254)

NOISE REMOVED: raw `git diff` = 17 lines; digest = 2 lines
```

Plus `docs/JIRA_TICKETS.md`'s MFIN-2088 acceptance criteria and `config/fee-schedule.yaml`.
Do not give it your Stage 4 conversation. Ask it to find any violation and cite evidence.

A reviewer reasoning only from the ticket and the diff — with no borrowed confidence from
having "already reasoned through this" — should compute one concrete example
(`calculateFee(100.00, "RTP")`) rather than pattern-matching the comment against the
acceptance criteria, and catch that it returns `0.35`, not the required `2.00`.

### 5.2 — The deterministic check (USE)

In Copilot Chat: **`/verify-change`** — or in a terminal: `./scripts/verify-change.sh`.

Real output, against the seeded fixture:

```
✓ required behavior preserved       (5 tests, 0 failures — existing test suite remains green)
✓ no Java source outside PaymentService.java changed (calculateFee at lines 237-254)
✓ prohibited dependency absent       (0 bytecode references to LegacyPaymentUtils)
✗ authoritative configuration respected
    calculateFee(100.00, "RTP") = 0.35 — expected 2.00 (max(0.0035 of amount, USD 2.00))

VERDICT: FAIL — 1 of 4 checks failed
```

The comment on the buggy branch says "USD 2.00 minimum" and is telling the truth about
intent. The bug is that it compares the *raw amount* to 2.00 instead of the *computed
fee* to 2.00 — correct for large transfers, wrong for everything roughly between USD 2
and USD 571. This script doesn't read the comment. It calls the compiled method and
checks the number.

**The portable version — what you'd compose in a repo with no `verify-change.sh`.**
The script's pattern is N independent assertions, each with its own exit signal, composed
into a single verdict. Strip the wrapper and the four checks reduce to:

```bash
# Check 1: required behavior preserved — exit code from the test runner
mvn -q test
echo "Check 1 exit: $?"   # 0 = pass, non-zero = fail

# Check 2: scope — which files changed
git diff --name-only HEAD~1 HEAD
# Inspect: did the change touch only the expected file(s)?

# Check 3: prohibited dependency — bytecode level (not grep)
mvn -q compile
jdeps -v -cp target/classes target/classes/com/meridian/payments/PaymentService.class \
  | grep LegacyPaymentUtils | wc -l
# 0 = prohibited dep absent (pass); >0 = present (fail)

# Check 4: authoritative configuration respected — run the compiled method
jshell --class-path target/classes --startup PRINTING -e \
  'import com.meridian.payments.*; var s = new PaymentService(...); System.out.println(s.calculateFee(new java.math.BigDecimal("100.00"), "RTP"));'
# Compare output to config/fee-schedule.yaml: must be >= 2.00 for amount 100.00

# Compose: all checks must pass
```

The composable verdict is the transferable idea: define N assertions, run each
independently, collect exit codes, emit PASS only if every one is zero. The specific
tool per check (`mvn`, `git diff`, `jdeps`, `jshell`) is Java-specific; the composition
shape — "any fails → FAIL + which one" — is not. Ask Copilot to write the composition
loop once; that wrapper is reusable across any set of assertions in any project.

### 5.3 — BUILD: the check `verify-change.sh` doesn't have

Re-read `docs/JIRA_TICKETS.md`'s "Testing — Definition of Done" section:

> At least one test exercises an amount where 0.35% of the amount is *below* USD 2.00
> (the minimum must bind there...)

None of `verify-change.sh`'s four checks verify this — they check what `calculateFee`
*returns*, not whether the *test suite* actually exercises the boundary. That's a real
gap between "the code is correct right now" and "a future change can't silently break the
boundary case without a test noticing."

You already built the primitive for this in **Stage 1.4** — reuse it, or rebuild it if
you skipped the condensed path there:

> Write a throwaway script that reads src/test/java's RTP test method(s) and reports
> whether any tested amount falls strictly between 0 and 571.43 (where 0.35% of the
> amount is under the USD 2.00 minimum). Report file, line, amount, and a pass/fail
> verdict. Do not paste the test file into this conversation.

Run it. It will report **FAIL** — no boundary test exists yet.

**Now write the test.** The disposable detector stays disposable. The boundary test
itself is a **Jira Definition of Done requirement** — it cannot be optional. Add a
permanent JUnit test to `src/test/java/com/meridian/payments/PaymentServiceTest.java`
that exercises an amount where 0.35% falls below the USD 2.00 minimum (e.g., amount =
100.00, where 0.35% = $0.35 < $2.00, so the minimum must bind and the fee must be $2.00).

```bash
mvn test
```

This will **fail** — the boundary test expects `$2.00` but the buggy implementation
returns `$0.35` for `$100`. That failure is expected and correct: the test caught the
bug before you did. Record this in your stage readings.

The fix comes in Stage 5.4 below — once the computed-fee comparison is corrected, re-run:

```bash
mvn test
```

Now all **6 tests** pass. Re-run your check-5 detector script and confirm it too reports
**PASS**.

Record all three verdicts in your stage readings:
- check-5 detector: FAIL (no boundary test) → PASS (test exists)
- boundary test itself: FAIL (bug caught) → PASS (bug fixed)
- `verify-change.sh`: FAIL → PASS

The **artifact-choice** for the detector and the test are different:

| Artifact | Choice | Why |
|---|---|---|
| The check-5 detector script | Disposable | One-off question — it found the gap; the test itself is the fix |
| The boundary unit test | Permanent (committed) | It's a Jira DoD requirement, not optional infrastructure |

### 5.4 — Bound the repair loop (USE)

This one stays a terminal command on purpose, unlike everything else so far — `loop.sh`
isn't a stateless question-in, answer-out tool like `authority.sh` or `context-run.sh`,
it's a stateful gate: it tracks attempt counts and verdict hashes across multiple calls
in `.workflow/state.json`. That's a hook's shape, not a skill's, and it already has one —
`.github/hooks/bin/loop-bound.sh` reads that same state file and denies Copilot's next
edit outright once the budget's spent. Running `loop.sh` here yourself is you watching
the exact mechanism the hook enforces automatically during real agent-driven work.

```bash
./scripts/loop.sh reset
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
```

Attempt 1, no fix yet — real output:

```
... (same FAIL block as above) ...
CONTINUE — attempt 1/3 used.
```
Exit code `1`.

Run it again with **no code change** — real output:

```
... (identical FAIL block) ...
STOP — thrashing. Identical verdict at attempt 2 (hash 4f4d407f95ea).
The diff is moving; the outcome is not. Escalate, do not retry.
```
Exit code `4`. The loop detected that the verdict repeated by hashing it — three lines of
logic, not a judgment call.

**The portable version — what you'd write in a repo with no `loop.sh`.**
The script's pattern is bounded retry with thrashing detection. The three-line core:

```bash
prev_hash=""
for attempt in 1 2 3; do
  output=$(run_your_verifier 2>&1)
  exit_code=$?
  curr_hash=$(echo "$output" | sha256sum | cut -c1-8)
  if [ $exit_code -eq 0 ]; then echo "PASS"; exit 0; fi
  if [ "$curr_hash" = "$prev_hash" ]; then
    echo "STOP — thrashing (same failure at attempt $attempt). Escalate."
    exit 4
  fi
  prev_hash=$curr_hash
  # surface failure -> human reviews/authorizes next attempt
done
echo "Budget exhausted — escalate."; exit 5
```

Three ideas worth carrying: **(1) bound attempts** — pick a number before you start, not
after you're tired; **(2) detect thrashing** — same output hash twice in a row means you
are not making progress, stop immediately; **(3) escalate on budget exhaustion** — a
non-zero exit signals "loop finished without resolving," not "loop finished." These three
lines are the whole pattern. The verifier command inside the loop is whatever you built in
5.2; swap it for any other deterministic check and the wrapper still holds.

Now fix the bug: compare the computed fee, not the raw amount.

```java
BigDecimal rtpFee = amount.multiply(BigDecimal.valueOf(0.0035)).setScale(2, RoundingMode.HALF_UP);
if (rtpFee.compareTo(BigDecimal.valueOf(2.00)) >= 0) {
    return rtpFee;
}
return BigDecimal.valueOf(2.00);
```

```bash
./scripts/loop.sh reset
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
```

Real output:

```
✓ required behavior preserved       (6 tests, 0 failures — existing test suite remains green)
✓ no Java source outside PaymentService.java changed (calculateFee at lines 237-255)
✓ prohibited dependency absent       (0 bytecode references to LegacyPaymentUtils)
✓ authoritative configuration respected   (calculateFee(100.00, "RTP") = 2.00; calculateFee(10000.00, "RTP") = 35.00)

VERDICT: PASS — 4 of 4 checks passed
DONE — green.
```
Exit code `0`.

Re-run your Stage 5.3 check-5 script now that the fix is in — both it and the boundary
test you added should report pass.

### Success Criteria — Stage 5

- [ ] Fresh reviewer found (or you can explain why it should have found) the
      amount-vs-computed-fee bug, citing a concrete example
- [ ] `verify-change.sh` reproduced the same failure deterministically
- [ ] Built "check 5" for the DoD requirement `verify-change.sh` doesn't cover (FAIL),
      then added a permanent boundary unit test (PASS), and committed it
- [ ] You ran the loop into thrashing (exit 4) on purpose and can say why it differs
      from budget exhaustion (exit 5)
- [ ] The fix took the loop to exit 0, and you can point to the exact line that changed
- [ ] You committed the working change: `git add -A && git commit -m "feat: add RTP fee support (MFIN-2088)"`

> **Core rule:** Use context to reason. Use deterministic systems to establish bounds —
> and know which bounds you haven't built yet.

---

## STAGE 6 — REHYDRATE & PROVE
### Fresh session + proof · 9 min

### Objective

Prove the engineering state survives the conversation that created it.

### 6.1 — End the conversation

Open a completely fresh chat. Do not copy anything from before. Provide only:

- `.context/context-register.yaml` (your own, from Stages 3 and 4.4 — update it first:
  mark the RTP fact's `applies_to` work as done, if you're tracking that)
- `.workflow/HANDOFF.md`
- A fresh package — in Copilot Chat: **`/context-package calculateFee-rtp`**, or in a
  terminal: `./scripts/context-for.sh calculateFee-rtp`

### 6.2 — Rehydrate

Ask:

> Based only on these artifacts:
>
> 1. What is already complete?
> 2. What is still unresolved?
> 3. What is the next engineering action?
> 4. Which constraints must not be violated?
> 5. Which sources are authoritative for the next decision?

Compare the response to the actual repository state: **`/verify-change`** (or
`./scripts/verify-change.sh`) should report `VERDICT: PASS`, and `git log` should show
the fix.

### 6.3 — What rehydration actually saved you

Part 1 measured the cost of a *request*. This measures the cost of a *restart* — the
number Part 1 has no way to produce, because it never lets a session end.

Open **Agent Debug Logs → Summary** (the same instrument from Part 1's Stage 0) and
record what 6.2 cost:

| | Input tokens | Model turns | Tool calls |
|---|---|---|---|
| **A — Rehydrated** (6.2: three artifacts, one question) | | | |
| **B — Cold re-derivation** (below) | | | |

Now run B. In a second fresh chat, with **no artifacts attached at all**, ask the same
five questions:

> This repository implements RTP transfer fees for ticket MFIN-2088. Without me giving
> you any notes or context files: what is already complete, what is still unresolved,
> what is the next engineering action, which constraints must not be violated, and which
> sources are authoritative for the next decision?

Record B's numbers, then compare — not just the cost, but the **answers**. B has the
entire repository available to it and still has to rediscover the rate conflict from
scratch, with no record that a human ever resolved it. Check specifically: does B know
the ADR was superseded, and *who decided that*?

The gap between A and B is what the register and the handoff are worth. It is the only
number in this lab that could not have been produced in a single session.

### Success Criteria — Stage 6

- [ ] Fresh session reconstructed the task correctly from artifacts alone
- [ ] No previous chat history was used
- [ ] Repository state (verify-change.sh, git log) matched the rehydrated summary
- [ ] Recorded A vs. B input tokens, turns, and tool calls (6.3)
- [ ] Can state what B got *wrong or couldn't know* — not just what it cost extra
- [ ] You can state which pieces of context were deliberately preserved and which were
      allowed to disappear

> **Core rule:** If your engineering state dies when your chat dies, you have not
> engineered the context yet.

---

## STAGE 7 — BUILD BEYOND THE HARNESS 🌟
### Smooth transfer · 35 min (7.1 ~5 min, 7.2 ~30 min)
### Our prepared mechanisms still exist, but they do not solve this new context problem. Build the missing mechanism yourself.

### Why this stage exists

Six stages proved you can *operate* a context lifecycle when this lab built the map, the
authority check, the register schema, and the verifier for you. That is real, useful
skill. This stage tests whether the *method* transferred, not just the *tooling* — using
a problem already sitting in this same codebase that no earlier stage pointed you toward.

The prepared infrastructure still exists. It just doesn't help here — this is a different
kind of context problem than the one `context-map.sh` or `verify-change.sh` were built for.

### 7.1 — Recognition check (~5 min)

A question nobody asked you in Stages 0–6, about a method no stage has opened:

> **MFIN-2088 adds a fee for RTP transfers. Refunds run through `refundPayment()`.
> When an RTP payment is refunded, what happens to the fee — is it refunded,
> charged again, or neither? And is answering that your problem right now?**

Search first, the way you would on any Monday: `grep -n "fee\|Fee" ` over
`refundPayment()`'s body (lines 254–283). **Expected: zero hits** — which reads like
"refunds don't touch fee logic, nothing to worry about."

Now check the call path instead of the text, and read what the reverse request actually
sets. In your stage readings, write:

1. Which pattern(s) apply, and what deterministic evidence settles it — not what the
   text search implied?
2. Should you fix this inside MFIN-2088? Why or why not?

<details>
<summary>Check your answer (open only after writing yours)</summary>

**Pattern:** Authority + Discover. The text search is a false negative: `refundPayment()`
contains no fee code itself, but it builds a reverse `PaymentRequest` and hands it to
`processPayment()` — so it inherits whatever the payment path does with fees. Worse, it
never calls `setPaymentType()` on that reverse request, so the payment type arrives
`null`. Any fee logic keyed on payment type is therefore reading an unset field on every
refund. Zero grep hits, real coupling — the same shape as Stage 1.2's `LegacyPaymentUtils`
false positive, inverted.

**Scoping:** out of scope. MFIN-2088's acceptance criteria are about what
`calculateFee(amount, "RTP")` returns, nothing about the refund path. And unlike most
findings in this repo, **no ticket tracks this one** — which is not a reason to fix it
here. Record it, raise a ticket, leave the change alone. Stage 4's `do_not_change`
discipline applies to debt you discover mid-task, not just debt somebody already filed.

</details>

### 7.2 — Build Your Own Context-Optimization Tool (~25 min)

You will build a working Copilot skill — a reducer, a verifier, or a filter, wired into
chat as `/your-tool-name`, not a script that only runs if someone remembers it exists —
that you can take home.

**Step 1 — Inspect the tool (2 min).** Everyone builds the same reducer this time — for
`mvn dependency:tree`:

```bash
mvn dependency:tree
```

Run it. Count the raw lines. Look for what's actually noise for the decision you'd use
this for — duplicate versions of the same artifact, conflicting transitive dependencies,
something pulled in that has no business being there. Every ecosystem has the same shape
of pain (`npm ls`, `pip freeze`, `go mod graph`, `cargo tree`) — if you'd rather leave
with a tool you'll actually use Monday, run your own repo's equivalent instead and spec
against that; nothing in Step 2 changes either way. Avoid substituting `mvn test` (or its
equivalent) if you go that route: `context-run.sh test` already solved that exact problem
in Stage 2.

**Step 2 — Spec the tool (3 min).** Write this in `outputs/stage-readings.template.md`
**BEFORE touching Copilot.** This is the gate — the spec proves you understood the
pattern, not just the tool.

1. **DECISION:** What engineering question does this tool serve?
2. **RAW SOURCE:** Exact command and output format.
3. **KEEP:** Which 2–3 lines from the raw output actually answer the decision?
4. **DISCARD:** What deliberately stays outside model context, and why?
5. **FAIL CLOSED:** If the underlying command fails, does your tool produce a false
   green, a false red, or a clean error? (It must produce a clean error.)

DISCARD is not an after-the-fact reflection. Deciding what deliberately stays outside
model context is one of the core Context Engineering decisions — it must happen before
Copilot writes the reducer.

**Step 3 — Build with Copilot (10 min).** Paste your five-line spec and ask Copilot to
build a **Copilot skill** — `.github/skills/<your-tool-name>/SKILL.md` — not a bare
script sitting in `scripts/` disconnected from chat. Match the shape of every tool you've
used all lab (`context-map`, `authority`, `context-run`, `context-package`,
`verify-change`): frontmatter (`name`, `description`, `context: fork`,
`disable-model-invocation: true`), an input contract, a one-line `Run:` workflow calling
the underlying command, and an output contract that says *return the digest only, no
prose*. The script it wraps can be as small as one `awk`/`grep` pipeline — the skill file
is what makes it something you type `/your-tool-name` for instead of re-explaining the
ask from scratch every time. Then:

1. Read what Copilot produces against your spec — does it retain only KEEP and exclude
   DISCARD?
2. Invoke your new skill against the real command (or simulated output).
3. **Force a failure** — pipe from `/dev/null`, introduce a compile error, or point at a
   nonexistent path. Confirm non-zero exit, and that the skill reports it instead of
   guessing. Record the exit code.
4. Iterate if needed — the iteration IS the learning.

**Step 4 — Confirm it's the right primitive (3 min).** This is the same decision you
previewed in Stage 3's "when to build what" table, now with your own tool as the input.
A skill is the default here because a dependency tree (or its equivalent) is a
deterministic-command-wrap — same shape as every tool this lab gave you. Check yours
actually fits before you're done:

| What you built | Lives as | Why |
|---|---|---|
| Answers a question, same command every time, stable output shape | **Skill** (`.github/skills/`) | What you almost certainly just built — matches this lab's own pattern exactly |
| No command underneath, just a consistent formatting/reasoning ask | **Prompt file** (`.github/prompts/`) | No tool to wrap — like Stage 3's `/promote-facts` |
| Must automatically block or allow an action, not just answer when asked | **Hook** (`.github/hooks/`) | The only primitive that can deny — see `loop-bound.sh` from Stage 5.4 |
| Must hold on every future change, independent of whether Copilot is even open | CI gate | Outside the harness entirely — the backstop when nobody's in a chat |
| Genuinely one-off, won't recur | Disposable — don't save it | Building infrastructure for a question you'll never ask twice is waste |

State which row yours landed in and why. If it's not actually a skill — say a hook fits
better because the real need is "block this automatically," not "answer when asked" —
say so and explain the mismatch rather than forcing it into skill shape. If the honest
answer is disposable, say that too; choosing not to build infrastructure is a valid
engineering decision.

**Step 5 — Record (2 min).** In your stage readings, add: the noisy command and raw line
count, the reduced output and its line count, what was kept/discarded/why, the failure
mode tested, where the tool lives, and why that deployment choice.

**Step 6 — Seed it into your own repo (5 min).** You just built one tool by hand, so you
know what the pieces are. Now generate the rest for a codebase that isn't Meridian's.

Open **your own repository** in a second VS Code window, copy
`.github/prompts/context-kit.prompt.md` into it, and run **`/context-kit`** there.

It will read your build file and layout, ask only what it can't determine itself, and
generate the `context-map`, `context-run test`, `authority`, and `outline` equivalents
for *your* stack — your test reporter, your dependency-proof tool, your directory
categories — then run each one and force it to fail to prove it fails closed.

If you don't have a work repo handy right now, run it against any repo you have locally;
the point is watching it port to a codebase whose layout it wasn't written for. This is
the answer to "these scripts are Meridian-specific, how do I use them Monday" — you
don't port them by hand, you regenerate them.

### Take it further on your own (optional)

Dependency trees aren't the only noisy command worth taming — they're just the one
everyone in the room shares. On your own time, run the same DECISION/RAW SOURCE/KEEP
/DISCARD/FAIL CLOSED spec from Step 2 against one of these instead:

| Category | Example command |
|---|---|
| Build/compiler warnings | `mvn compile -X`, `gcc -Wall`, `tsc --noEmit` |
| Git history / diff | `git log --oneline -50`, `git blame <file>` |
| Static analysis | `eslint .`, `checkstyle`, `golint ./...` |
| Logs | `tail -100 /var/log/...`, `kubectl logs ...`, `docker logs ...` |

Same caveat as Step 1: skip `mvn test` (or its equivalent) — Stage 2 already solved
that one.

### Success Criteria — Stage 7

- [ ] (7.1) Named which pattern(s) applied, cited deterministic evidence, correctly
      scoped the fix decision
- [ ] (7.2) Wrote the 5-property spec (DECISION/RAW SOURCE/KEEP/DISCARD/FAIL CLOSED)
      BEFORE prompting Copilot
- [ ] (7.2) Built as a Copilot skill (`.github/skills/`), invoked as `/your-tool-name`,
      not a bare script nobody would remember to run
- [ ] (7.2) The skill runs against a real command and produces reduced output
- [ ] (7.2) The skill fails closed — forced failure demonstrated, non-zero exit confirmed
- [ ] (7.2) Can state what was deliberately discarded and why
- [ ] (7.2) Confirmed skill was the right primitive for what you built — or named which
      of prompt file / hook / CI gate / disposable fit better, and why
- [ ] (7.2) Built the reducer from your own 5-property spec, not a copied answer

> **Core rule:** the ten patterns are not a checklist. They are questions — *what's
> actually true, what can be computed, what deserves to survive, who needs it next,
> what needs a human, how do I know I'm right* — and you now bring them to a problem
> yourself, because nobody built the tooling for this one.

---

## Debrief · 3 min

### The Ten Patterns — take-home field guide

These ten questions are the whole point of the lab — memorize the questions, not the
scripts.

| # | Pattern | The question |
|---|---|---|
| 1 | Discover | Before loading content, where does truth about this question likely live? |
| 2 | Authority | Given a claim, what's the strongest evidence source that can actually settle it? |
| 3 | Reduce | What's the minimum signal this decision needs, and what can be computed outside the model? |
| 4 | Promote | Which discoveries deserve to survive this conversation, with what provenance? |
| 5 | Package | What's the minimum sufficient context for the next specific action? |
| 6 | Constrain | Does this role need a capability boundary, not just a prompt boundary? |
| 7 | Handoff | What transfers to the next actor — the decisions, or the whole conversation? |
| 8 | Verify | Which acceptance criteria are non-negotiable enough to become an executable check? |
| 9 | Review | Should the evaluator inherit the producer's reasoning, or only curated evidence? |
| 10 | Rehydrate | Can the engineering state be reconstructed from durable artifacts alone? |

### What you take home

Not the Meridian scripts — they were the worked example, and they were hardcoded to this
codebase on purpose so you'd have something concrete to take apart. Three things
actually leave the room with you:

1. **The ten questions above**, which are stack-agnostic and tool-agnostic.
2. **`.github/prompts/context-kit.prompt.md`** — copy this one file into any repo and
   run `/context-kit` to regenerate the whole kit for that stack. You ran it once
   already in Stage 7.2 Step 6; that was the rehearsal.
3. **The skill you built yourself in Stage 7.2**, already sitting in `.github/skills/`
   where `/your-tool-name` reaches it.

Anything in this repo that isn't one of those three was scaffolding.

### Final reflection

Think back to the option (A–E) you chose at the very beginning, in Stage 0. Would you
make the same choice now? Looking at the tool you just built in the capstone: what would
you establish before deciding which source to trust?

This is a verbal close — no write-up required.

---

## Troubleshooting

See `docs/TROUBLESHOOTING.md` for the full appendix. Quick pointers:

| Symptom | Fix |
|---|---|
| `./scripts/*.sh` says "not recognized as an internal or external command" | Your VS Code integrated terminal is on PowerShell, not Git Bash — see [Windows setup](#windows-setup--read-this-before-stage-1) |
| Agents don't appear in the mode dropdown | Confirm you opened `context-engineering-part-2/` itself as the VS Code workspace root, not a parent folder |
| `context-for.sh` says "nothing has been promoted yet" | Run Stage 3.1 first — copy the **template**, not the example, and fill it in |
| `verify-change.sh` shows all four checks green before Stage 4 | Not expected — at clean baseline, `calculateFee(..., "RTP")` returns `0`, which fails check 4 (`0 < 2.00`) by design. If you see all-green with no RTP code, your working tree has drifted from baseline — run `git status` and `git log` |
| `jshell` not found | It ships with JDK 17+; check `java -version` and that `jshell` is on `PATH` |
| Stage 5's loop reaches thrashing (exit 4) on the very next check | Expected — running `loop.sh check` twice with no code change in between produces an identical verdict hash by design. Make the fix before the second run if you want to see exit 0 instead |

---

## What This Lab Did Not Cover

Deliberately out of scope, and worth knowing exists:

- **Multi-repo context management.** This lab focuses entirely on single-repository
  context engineering. The ten patterns taught here (discover, reduce, promote, package,
  handoff, verify, and the rest) apply when context must cross repository boundaries, but
  the cross-repo coordination exercise itself — identifying the minimal authoritative
  foreign context, recording provenance and freshness across repos, detecting stale
  cross-repo artifacts — is deferred to a future lab. Part 2 teaches the core lifecycle
  well enough that you can reason about multi-repo scenarios; it does not provide a
  worked exercise for them.
- **Mutation testing.** `scripts/mutation.sh` is ported into this lab for tooling parity
  and is available if you want it, but no stage here exercises it — verifying whether a
  test *suite* is thorough is a different lab's subject.
- **Multi-agent cost.** Delegating to isolated agents moves cost off your single-session
  meter; it does not make the work free. Use isolation where it buys correctness, not
  reflexively.
- **Instruction files as an attack surface.** You author `.github/agents/`,
  `.github/skills/`, and `AGENTS.md`; treat a diff to any of them as code and read it in
  review.
- **Other AI tools, other languages.** This lab is deliberately scoped to GitHub Copilot
  and Java for a Windows engineering audience. The ten patterns in the Debrief are not
  Copilot-specific or Java-specific ideas — only the mechanisms you practiced them on
  are. Applying pattern #2 (Authority) in a different tool means finding that tool's
  equivalent of "the model can run a command and read its real output"; it does not mean
  this lab owes you a worked example in that tool.

---

*Copyright 2026 Arula.AI (InRhythm Arula Labs). All Rights Reserved. | Internal - Confidential*
