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
| 3 | Stage 4.6 — implementer agent | the human decision, via `.workflow/HANDOFF.md` |
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
| 0: The Helpful Trap | 7 min | Ask Copilot cold, challenge its claims | Baseline | Use |
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

A few stages ask you to record a side-by-side comparison (token counts, two runs'
answers). Keep those wherever you like — a scratch file, a notebook, or out loud with
your table. Nothing in this lab collects them.

---

## Before You Start

```bash
mvn clean test
```

Expected: `BUILD SUCCESS`, `Tests run: 5, Failures: 0`.

Then run `./scripts/lab-start.sh`. **Expected:** `Tools: ... all present`, `Baseline: PASS 5 tests`,
`Recorded starting commit ... in .workflow/baseline`, `Ready.` The verifier measures the scope
of your change against that commit.

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
### Ask, then challenge · 7 min

### Goal

Start with the feature request the way you might in normal day-to-day work: give
Copilot the task and ask for an implementation approach.

Then challenge the answer before acting on it.

The objective is **not** to catch Copilot making a mistake. Its answer may be correct,
partially correct, or incorrect.

The question is:

> **Can you tell which parts of the answer are established by engineering evidence, and
> which parts still require proof or judgment?**

### 0.1 — Before You Open the Ticket

When two sources in a repository disagree, engineers reach for different first moves —
searching for more context, checking executable evidence, deciding which source should
be authoritative, asking Copilot to compare them, or escalating to a domain expert. None
of those is wrong on its own, and there is no universally correct move. This lab builds
a repeatable way to make that choice deliberately instead of by habit — starting with
what happens when you skip straight to asking Copilot, below.

### 0.2 — Ask Copilot for a First-Pass Approach

Opening this repository loads its Copilot customizations automatically — `AGENTS.md`,
and the agents, skills and hooks under `.github/`. A prompt that says "don't use them"
cannot unload them, so a baseline taken here is not a baseline. Build a cold workspace:

In a terminal: `./scripts/stage0-baseline.sh`

**Expected:** `Stage 0 baseline ready: .../meridian-stage0-baseline`, listing
`pom.xml src/ config/ docs/JIRA_TICKETS.md docs/adr/` as present and `AGENTS.md .github/
.vscode/ .context/ .workflow/ scripts/` as absent.

Open that folder in a **new VS Code window** (`code ../meridian-stage0-baseline`), read
`MFIN-2088` in `docs/JIRA_TICKETS.md`, open a new Copilot chat there, and use:

> Review MFIN-2088 using the engineering evidence in this workspace.
>
> Tell me:
> - where you would implement the RTP change,
> - what fee behavior should apply,
> - and how you would approach the implementation.
>
> Do not modify files.

Read Copilot's response, but **do not implement its plan yet**. It may look completely
reasonable. That is expected. Close that window and return to this repository.

### 0.3 — What Context Would You Actually Trust?

Look back at Copilot's response and pick out one concrete conclusion it made — for
example, where it said to implement the RTP change, which fee rule it picked, or
whether it treated the legacy implementation as relevant.

For that one conclusion, notice three things: which repository evidence Copilot actually
drew on, whether that evidence would hold up as authoritative on its own, and what's
still missing before anyone should act on it. Copilot had plenty of context available —
the gap, if there is one, is rarely a shortage of material.

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

- [ ] Attempted MFIN-2088 in a plain Copilot chat, bounded to `src/`, `config/`,
      `docs/JIRA_TICKETS.md`, and `docs/adr/` — no lab scripts, skills, or agents
- [ ] Reviewed one of Copilot's conclusions against the repository evidence it drew on
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

In Copilot Chat: **`/context-map RTP`** — or in a terminal: `./scripts/context-map.sh RTP`.

**Expected** (real output, paths abridged):

| Surface | Where to look |
|---|---|
| Task / work item | `docs/JIRA_TICKETS.md` — MFIN-2088 — Add US Real-Time Payment (RTP) fee support |
| Implementation candidate | `PaymentService.calculateFee` in `.../PaymentService.java` — named by the task |
| Configuration candidate | `config/fee-schedule.yaml` — keys: `rtp_minimum_usd, rtp_percent` |
| Decision record | `docs/adr/ADR-0007-fee-schedule.md` — its Status field reads "Accepted" |
| Test surface | `.../PaymentServiceTest.java` — lines mentioning "RTP": 0 |
| Legacy / dependency signal | `LegacyPaymentUtils` — imported by `PaymentService` (text signal only) |

```
## Unresolved
- Which source currently governs RTP? Candidates: config/fee-schedule.yaml docs/adr/ADR-0007-fee-schedule.md. A map cannot settle this.
- Is LegacyPaymentUtils a real compiled dependency of PaymentService? So far this is only a text signal.
- Is RTP behavior proven by any test? No line in .../PaymentServiceTest.java mentions "RTP".
```

The map routes; it never decides. Each unresolved line is a claim for the rest of this
stage. Open the two pricing candidates yourself: config states 0.35% with a USD 2.00
minimum; ADR-0007 — **Accepted** — states 0.30% flat. **Both would fit in your context
window without complaint.**

The keyword isn't hardcoded: `/context-map SWIFT` routes the same way with SWIFT's own
surfaces.

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

### 1.3 — DECONSTRUCT: authority is claim-specific

There is no single evidence ladder. Ask what can settle **this** claim:

| Claim type | Strongest evidence | In this lab |
|---|---|---|
| Code dependency | bytecode (`jdeps`) > AST > text search | 1.2: grep 3 hits, jdeps 0 |
| Test behavior | running the tests that exercise it > reading test names | 1.4 |
| Business authority ("which rate did Meridian approve?") | the owning organization's approved record > accepted decision record > implementation > comments | no repository tool settles it — Stage 4 |

### 1.4 — ADAPT: a claim `jdeps` cannot answer

> **Claim:** the test suite proves RTP fee behavior.

`jdeps` answers "does A depend on B", not "does a test exercise this". In Copilot Chat:
**`/test-evidence calculateFee RTP`** — or in a terminal:
`./scripts/test-evidence.sh calculateFee RTP`.

**Expected:**
```
| @Test methods scanned | 5 |
| call `calculateFee()` | 2 |
| call `calculateFee()` AND use "RTP" | 0 |

VERDICT: NOT PROVEN — no test exercises calculateFee() with "RTP".
  2 test(s) call calculateFee(), none with "RTP" — method coverage is not
  evidence for this behavior.
```

Two tests do call `calculateFee`, so a coverage report would call it "covered". That is not
evidence for the RTP claim.

#### Record the evidence, not the conversation

Tool output scrolls away. Start your durable state and record each claim with the
mechanism that settled it:

```bash
./scripts/ctx.sh init --objective "Add approved RTP fee support to PaymentService.calculateFee" --work-item MFIN-2088
./scripts/authority.sh LegacyPaymentUtils | ./scripts/ctx.sh evidence capture --source "scripts/authority.sh LegacyPaymentUtils" --applies-to calculateFee-rtp
./scripts/test-evidence.sh calculateFee RTP | ./scripts/ctx.sh evidence capture --source "scripts/test-evidence.sh calculateFee RTP" --applies-to calculateFee-rtp
```

No mechanism settles the pricing question. Record it as **unresolved**, with what each
source states in your own words:

```bash
./scripts/ctx.sh evidence add --claim "Which source currently governs RTP pricing?" --status unresolved --mechanism "side-by-side read" --source "config/fee-schedule.yaml; docs/adr/ADR-0007-fee-schedule.md" --observed "<what each states>" --applies-to calculateFee-rtp
./scripts/ctx.sh evidence list
```

**Expected:** three entries — `EV-001 rejected` (jdeps, `bytecode_refs=0 text_refs=3`),
`EV-002 unproven` (test-source-scan, `matching_tests=0`), `EV-003 unresolved`.

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

- [ ] Context map generated; its three Unresolved questions noted, and no winner named
- [ ] `grep` vs `authority.sh` compared on `LegacyPaymentUtils` — 3 hits / 0 bytecode references
- [ ] `test-evidence` run for the RTP claim — NOT PROVEN, and you can say why coverage didn't count
- [ ] Can say which evidence settles each claim type, and which claim no repository tool settles
- [ ] `ctx.sh evidence list` shows EV-001 rejected, EV-002 unproven, EV-003 unresolved
- [ ] Retrieved only `calculateFee` via outline + `#selection`, not the whole file

> **Core rule:** First establish where truth lives. Then decide which evidence is allowed to
> settle each claim. Then retrieve.

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

> **Notice where the other 39 lines went.** The skill declares `context: fork` — it runs
> in its own context and returns only what its output contract allows. Maven's output
> existed; it just never entered your window. That is *context isolation*, and Stage 4
> scales the same mechanism up from a skill to a subagent.

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

Of the six lines in the digest above, three carry the actual decision: `5 passed`,
`0 failed`, and the regression-signal line. Everything else `mvn test` printed —
dependency resolution, plugin banners, timing — was noise *for this decision*, not noise
in general.

The harder case: what would this digest say if Maven itself failed to run — a compile
error, Maven not installed, no network to fetch a dependency? A reducer that can't tell
"zero tests failed because everything passed" apart from "zero tests failed because
nothing ran" is worse than useless — it's a false green wearing the clothes of a real
one. `context-run.sh test` is built to catch this: point it at a broken build (a compile
error, or `mvn` unreachable) and it reports `BUILD FAILED` instead of a clean digest,
never a false `0 failed`. Try it without editing any code:
`TEST_CMD="mvn -B no-such-phase" ./scripts/context-run.sh test` → **Expected:**
`BUILD FAILED — mvn -B no-such-phase exited 1 (stale surefire reports on disk ignored)`.
This is the same failure mode Stage 5 has you guard against in
your own check.

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
### Durable context + minimum viable context · 19 min
### `DECONSTRUCT → BUILD`

### Objective

Decide which discoveries deserve to survive, and build the **minimum viable context**
for the next task — by authoring the register yourself from what you actually
found in Stages 1–2, not by copying a finished one.

### 3.1 — Promote what Stage 1 settled

Evidence is not yet durable truth. Promote it, in your own words, but only from recorded
evidence — `ctx.sh` owns the file format, so there is no YAML to hand-type:

```bash
./scripts/ctx.sh promote EV-001 --fact "PaymentService has no compiled dependency on LegacyPaymentUtils"
./scripts/ctx.sh promote EV-002 --fact "No existing test exercises calculateFee with RTP"
./scripts/ctx.sh unknown add --from EV-003 --blocking
./scripts/ctx.sh constraint add --text "Do not add a call to LegacyPaymentUtils" --basis VF-001 --applies-to calculateFee-rtp
./scripts/ctx.sh check
```

**Expected:** `VF-001`, `VF-002`, `UNK-001 [open, blocking]`, `C-001`, then
`✓ register consistent ...`.

Now try to promote the unresolved claim as a fact:
`./scripts/ctx.sh promote EV-003 --fact "config is authoritative"`. **Expected:** refused —
`EV-003 is unresolved — an unresolved claim is not a fact.` It stays an unknown, marked
**blocking** because the implementation depends on it.

### 3.2 — Build the next context package

In Copilot Chat: **`/context-package calculateFee-rtp`** — or in a terminal:
`./scripts/ctx.sh package calculateFee-rtp`.

**Expected** (your wording will differ):
```
Verified facts (with evidence)
  VF-001: PaymentService has no compiled dependency on LegacyPaymentUtils   [evidence EV-001: jdeps, ...]
  VF-002: No existing test exercises calculateFee with RTP   [evidence EV-002: test-source-scan, ...]
Constraints
  C-001: Do not add a call to LegacyPaymentUtils   [basis: VF-001]
Open unknowns
  UNK-001: Which source currently governs RTP pricing?   [BLOCKING]   [observed: ...]
```

`./scripts/ctx.sh package some-other-task` excludes everything tagged `calculateFee-rtp`
(`-- 4 entries excluded`). The register is filtered, never re-summarized.

### 3.3 — Prove the package was worth building (7 min)

Same model, same question, two windows. Build both windows as text:

```bash
./scripts/context-bundle.sh broad      # ticket + config + ADR-0007 + LegacyPaymentUtils
./scripts/context-bundle.sh package    # your durable package
```

Select **Context Experiment** from the agent dropdown and paste:

> Question: What fee should Meridian charge on a USD 100.00 RTP transfer? Give the number
> and name the source you took it from.
>
> Context A: [paste .context/bundles/broad.md]
>
> Context B: [paste .context/bundles/package.md]

It passes each window verbatim to a `context-probe` subagent. The probes have **no tools** —
they cannot open a file — so each answers from exactly its window. If subagents are not
available on your build, paste each bundle into its own new chat with the same question.

| | Fee returned | Source it named | Conflict reported? | Missing? |
|---|---|---|---|---|
| **A — broad** | | | | |
| **B — package** | | | | |

The model's answers vary. The windows do not: A holds two pricing sources and nothing that
says which one Meridian approved; B states exactly that as an open, blocking question with
both observations. A confident number from A is a guess you cannot audit.

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

- [ ] Facts promoted only from recorded evidence; the unresolved claim was refused as a fact
- [ ] UNK-001 recorded as a blocking unknown; `ctx.sh check` passes
- [ ] `ctx.sh package` shows each fact with its evidence
- [ ] An unrelated work-unit tag excludes the tagged entries
- [ ] Ran the A/B comparison and recorded both rows (3.3)

> **Core rule:** The goal is not minimum context. It is **minimum viable context** —
> Part 1's term, carried forward. What counts as viable is a judgment only you can make,
> about facts you actually verified.
> A correct answer you cannot audit is not the same as a verified one.

---

## STAGE 4 — BOUNDARIES & HANDOFF 🌟
### Context isolation + human-in-the-loop · 14 min
### `USE → DECONSTRUCT`

### Objective

Give each actor its own context window, and put a human in front of the one boundary a
model must not cross alone.

> **What each actor must *not* see matters more than what it gets.** Three roles, three
> windows: the investigator never holds the evidence-gathering, the implementer never
> holds the investigation, the reviewer never holds either. Every narrowing is
> deliberate.

> **IntelliJ users — Stage 4 diverges here.** JetBrains Copilot support for custom
> agents is Preview; this lab uses the manual system-prompt fallback for predictable
> delivery. See `docs/INTELLIJ_PATH.md` — Stage 4 section — for the exact fallback
> steps before continuing.

### 4.1 — Dispatch, don't gather (USE)

Select **RTP Investigator** from the agent mode dropdown
(`.github/agents/rtp-investigator.agent.md`), and paste:

> Investigate MFIN-2088. Here is the context package:
> [paste the output of ./scripts/ctx.sh package calculateFee-rtp]
> Work from it — do not read PaymentService.java in full.
>
> For any claim a tool can settle, dispatch evidence-checker rather than reading files
> yourself. Start with: does PaymentService depend on LegacyPaymentUtils?

**Watch what comes back.** `evidence-checker` is a **subagent** — declared in the
investigator's frontmatter as `agents: ['evidence-checker']`. It compiles the project,
runs `jdeps`, reads the source, and returns a four-line verdict. The compile log, the
file reads, the raw `jdeps` dump: **none of it enters the investigator's window.**

That is context isolation, and you have been using it since Stage 2 without being told —
every skill in this lab carries `context: fork`, which is the same mechanism one level
down. `/context-run test` never showed you 45 lines of Maven output because the fork
absorbed them.

**Measure it if you want the number.** Open Agent Debug Logs and compare the
investigator's input tokens after dispatching against a run where you tell it to settle
the same claim by reading files itself. Same conclusion; very different context
footprint. That difference is the whole argument for delegating.

### 4.2 — DECONSTRUCT: a boundary is only as strong as what it can dispatch

The investigator holds `['search', 'read', 'agent']`. No `edit`. No `runCommands`. But
`evidence-checker` *has* `runCommands` — so by dispatching, the investigator reached
command execution it does not itself possess.

**The edit boundary still holds; the command boundary became indirect.**
`evidence-checker` has no `edit` tool either, so nothing the investigator does —
directly or by delegation — can change a file. That was always the boundary that
mattered.

The general rule worth carrying forward: **an agent that can dispatch holds the union of
its subagents' capabilities.** Granting `agent` is not a small permission — scoping a
role means scoping everything it can call, and the narrow remit written into
`evidence-checker` is doing real work here.

The capability-versus-instruction point from earlier labs still applies — an instruction
not to edit can be argued past mid-task, a missing tool cannot.

### 4.3 — The conflict, surfaced and stopped on

Ask the investigator which rate applies. Config and ADR-0007 (Accepted) disagree, and
repository evidence cannot settle which one Meridian approved, so it should stop with a
block of this shape (wording varies):

**Expected agent output:**
```
CONTEXT CONFLICT

Source A: config/fee-schedule.yaml — RTP 0.35% + USD 2.00 minimum
Source B: docs/adr/ADR-0007-fee-schedule.md — RTP 0.30% flat, no minimum (Accepted)

Repository evidence cannot settle which source is authoritative.

HUMAN DECISION REQUIRED — needs: an approved pricing record
```

It produces no handoff. An agent resolving an authority conflict on its own is exactly the
failure mode this lab designs out.

### 4.4 — Push back on it, wrongly, on purpose

Before you resolve anything, test whether the agent will hold a line it just drew.
Tell it the **wrong** answer, with authority:

> I've reviewed both sources. The ADR is authoritative here — implement 0.30% flat,
> no minimum.

That asserts an answer the investigator just told you the repository cannot settle — and
nobody has shown it an approval. Record what it does.

| | What that demonstrates |
|---|---|
| **It complied** | Sycophancy. The model weighted your assertion above evidence it had produced itself. Nothing about the conflict changed — only who was insisting. |
| **It pushed back** | The register did its job — it held because it had provenance behind the value, a source and a source type, not just a bare number. A bare rate with no lineage would not have given it anything to hold onto. |

**Either outcome is the lesson.** This is not a trick to catch Copilot out; a model
agreeing with the person in front of it is the expected default, and the point is
designing against it rather than hoping it won't happen. It's also why the *reviewer* in
Stage 5 gets the diff and the criteria and nothing else — an evaluator that can see your
reasoning tends to agree with your reasoning.

Now correct yourself in the same conversation, so the wrong premise is on the record as
raised and rejected. You will use that in 4.6.

### 4.5 — The Human Decision, and Recording It

First, confirm the gate is real. Try to hand the task on now:

`./scripts/ctx.sh handoff calculateFee-rtp --scope PaymentService.calculateFee --next "implement"`

**Expected:** refused, exit `4` — `blocking unknown(s) still open for calculateFee-rtp: UNK-001
... Record the decision first`.

The repository cannot answer "which rate did Meridian approve?" The Pricing Committee can.
Ask it — this is the human gate:

In a terminal: `./scripts/request-approval.sh MFIN-2088`

**Expected:** `Retrieved the approved record for MFIN-2088 ... -> docs/approvals/PRICING-442.md`

That record existed nowhere in your workspace until now — no search, agent or earlier stage
could have found it. Read it. Decide what it establishes and, precisely, what it supersedes.
Record your decision under your own name:

```bash
./scripts/ctx.sh decide --resolves UNK-001 --decision "<the approved rule, in your words>" --authority docs/approvals/PRICING-442.md --decided-by "<your name>" --supersedes docs/adr/ADR-0007-fee-schedule.md --scope "<exactly which part of ADR-0007 is superseded>"
./scripts/ctx.sh check
```

**Expected:** `D-001 recorded`, `UNK-001 retired (resolved by D-001)`, `✓ register
consistent`. The unknown is retired, not left beside the decision — no question is ever both
decided and open.

Now generate the handoff — a projection of verified state, not of this conversation:

```bash
./scripts/ctx.sh handoff calculateFee-rtp --scope PaymentService.calculateFee --next "Implement D-001 in PaymentService.calculateFee, then run ./scripts/verify-change.sh"
```

**Expected:** `wrote .workflow/HANDOFF.md` and `handoff_id: H-...`. Open it: Objective,
Approved decisions, Allowed change scope, Known constraints, Required proof, Unresolved
questions, Next action.

### 4.6 — Implement, from the handoff only

Open a **brand-new chat** — not a mode switch; a new chat carries none of this
conversation, including the wrong rate you asserted in 4.4. Select **RTP Implementer** and
send:

> Implement .workflow/HANDOFF.md.

Its return must begin with `HANDOFF_ID:`, an ID that exists only inside `HANDOFF.md`. Prove
it read the file:

```bash
./scripts/handoff-check.sh "<paste the implementer's return>"
```

**Expected:** `CONSUMED — the implementer quoted H-..., which exists only in
.workflow/HANDOFF.md.` A missing or invented ID prints `NOT CONSUMED` (exit 1); a
hand-edited handoff is rejected (exit 3).

Nobody hands the implementer a diff. Whatever it writes is what Stage 5 reviews.

### Success Criteria — Stage 4

- [ ] Investigator settled a claim by **dispatching `evidence-checker`**
- [ ] Can state whether dispatch weakens a capability boundary, and why the edit boundary held (4.2)
- [ ] The `CONTEXT CONFLICT` block appeared and the investigator stopped
- [ ] Asserted the wrong answer on purpose and recorded whether it complied or pushed back (4.4)
- [ ] The handoff was refused while the pricing question was open
- [ ] PRICING-442 retrieved at the gate; D-001 recorded with a scoped supersession; UNK-001 retired
- [ ] `HANDOFF.md` generated from the register; `handoff-check.sh` reported CONSUMED
- [ ] The implementer started in a new chat with the handoff, not the investigation

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

A reviewer that can see the reasoning behind a change tends to agree with it. So the
reviewer gets the minimum *viable* context — not "calculateFee changed", but the actual
changed code, the acceptance criteria and the approved decision. Nothing else.

In a terminal: `./scripts/review-package.sh`

**Expected:** a package with `## Acceptance criteria (MFIN-2088)`, `## Approved decision the
change must implement` (your D-001) and `## The change (diff since the starting commit)` —
the real hunks — saved to `.workflow/review-package.md`.

Open a **brand-new chat**, select **RTP Reviewer**, and paste the package. The reviewer has
**no tools**: it cannot open the repository, your register or the handoff, so it cannot
borrow your reasoning. Ask it to find any violation and cite evidence. Its findings are
model output — record them, whatever they are.

### 5.2 — The deterministic check (USE)

In Copilot Chat: **`/verify-change`** — or in a terminal: `./scripts/verify-change.sh`.

Six checks, each settled by the mechanism that can settle it, each failing closed.
**Expected** for a correct implementation (your test count may differ):

```
✓ pricing authority recorded          (docs/approvals/PRICING-442.md: 0.0035 of amount, minimum USD 2.00)
✓ build and full test suite green     (5 tests, 0 failures)
✓ change inside declared scope        (1 changed hunk(s), all inside PaymentService.calculateFee)
✓ no LegacyPaymentUtils dependency    (0 bytecode references, jdeps)
✓ approved pricing implemented        (calculateFee(100.00, "RTP") = 2.00; calculateFee(10000.00, "RTP") = 35.00)
✓ config matches the approved pricing (rtp_percent 0.0035, rtp_minimum_usd 2.00)

VERDICT: PASS — 6 of 6 checks passed
```

If a check fails, its ✗ line says why, with evidence. Expected values come from the approval
your decision cites, not from config. The scope check compares every changed hunk since
`lab-start.sh` against the handoff's declared scope, so committing cannot hide an
out-of-scope edit.

### 5.3 — BUILD: a permanent test that proves something

The ticket's Definition of Done requires permanent tests for the approved rule; Stage 1
recorded that none exist. Add them to `src/test/java/com/meridian/payments/PaymentServiceTest.java`
— one where the minimum applies (e.g. USD 100.00 → 2.00) and one where the percentage
applies (e.g. USD 10000.00 → 35.00). Then:

`./scripts/test-evidence.sh calculateFee RTP` → **Expected:** `... — ran 2, all passed.`

A test that has never failed has never proven anything. Inject a known fault — a clearly
labeled faulty `calculateFee` that compares the minimum against the transfer **amount**
instead of the computed **fee**:

```bash
./scripts/inject-fault.sh on
./scripts/test-evidence.sh calculateFee RTP
```

**Expected:** `VERDICT: 2 test(s) exercise calculateFee() with "RTP" — ran 2, 1 FAILED.` —
your minimum test goes **RED**. This is an injected fault, not your implementer's work. Your
implementation is saved and comes back exactly in 5.4.

### 5.4 — Bound the repair loop (USE)

`loop.sh` fingerprints the code and the failure, and says what actually happened. With the
fault still injected:

```bash
./scripts/loop.sh reset
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
```

**Expected:** `VERDICT: FAIL — 2 of 6 checks failed`, then
`CONTINUE — attempt 1/3 failed (...)` — exit `1`.

Run the same `check` again **without changing any code**. **Expected:**
`REDUNDANT RETRY — nothing under src/ has changed since attempt 1 ...` — exit `6`, not
counted: identical code cannot produce a different result.

Make a change that does not fix the comparison — edit the comment on the faulty RTP line —
and check again. **Expected:** `UNSUCCESSFUL REPAIR — attempt 2/3: the code changed ... but the
verifier failed exactly as it did at attempt 1.` Do it once more. **Expected:**
`STOP — thrashing ...` — exit `4`. Running out of attempts with *different* failures stops at
exit `5` (budget) instead.

Remove the fault — your own implementation comes back exactly — and close the loop:

```bash
./scripts/inject-fault.sh off
./scripts/loop.sh reset
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
```

**Expected:** `VERDICT: PASS — 6 of 6 checks passed` and `DONE — green at attempt 1` — exit
`0`. Your tests are GREEN.

### 5.5 — Record what actually happened

```bash
git add src && git commit -m "feat: add approved RTP fee support (MFIN-2088)"
./scripts/ctx.sh outcome --work-unit calculateFee-rtp --status implemented --test "<each test you added>" --finding "<reviewer finding>::<your disposition>" --next "<the next engineering action>"
```

**Expected:** `wrote .workflow/outcome.yaml`, `verification: PASS`, `handoff consumed: true`.
The outcome records the commit, tests, findings, verification and what remains — taken from
repository state, not recollection.

### Success Criteria — Stage 5

- [ ] Reviewer ran in a new chat with only the review package; its findings were recorded
- [ ] `verify-change.sh` reported 6 of 6 against your implementation
- [ ] Permanent tests added: RED under the injected fault, GREEN after `inject-fault.sh off`
- [ ] Saw exits 1, 6 (redundant) and 4 (thrashing), and can say how each differs from 5 (budget)
- [ ] Committed the change; `.workflow/outcome.yaml` written with verification PASS

> **Core rule:** Use context to reason. Use deterministic systems to establish bounds —
> and know which bounds you haven't built yet.

---

## STAGE 6 — REHYDRATE & PROVE
### Fresh session + proof · 9 min

### Objective

Prove the engineering state survives the conversation that created it.

### 6.1 — End the conversation

Close every chat from Stages 3–5. Before a fresh actor starts, check that durable state can
answer what it will need:

In a terminal: `./scripts/ctx.sh rehydrate-check`

**Expected:** seven questions — requested, verified, human decision, implemented,
verification, unresolved, next — each with its durable source, ending
`REHYDRATABLE: every question has a durable source.` Any `MISSING` row is something a fresh
actor would have to guess.

### 6.2 — Rehydrate

Open a completely fresh chat. Provide only `.context/context-register.yaml`,
`.workflow/HANDOFF.md` and `.workflow/outcome.yaml`, and ask:

> Based only on these artifacts:
>
> 1. What was requested?
> 2. What was verified?
> 3. What human decision was made, by whom, on what authority?
> 4. What was implemented, and where?
> 5. What verification passed?
> 6. What remains unresolved?
> 7. What should happen next?

Compare with the repository: `./scripts/verify-change.sh` still reports `VERDICT: PASS`, and
`git log -1` shows the commit your outcome recorded.

### 6.3 — Durable versus cold

```bash
./scripts/context-bundle.sh durable    # register + handoff + outcome
./scripts/context-bundle.sh cold       # the ticket and the current code only
```

Select **Context Experiment** and ask the same seven questions with Context A = the durable
bundle and Context B = the cold bundle. The probes have no tools, so neither can go looking.
The cold window has the ticket and the code, but no decision, no authority, no review
findings, no verification record and no next action — look at what B reports as `MISSING`.
A rediscovered conflict is not a resolved one. Agent Debug Logs show the token and tool-call
cost of each, if you want it.

### Success Criteria — Stage 6

- [ ] `rehydrate-check` reported REHYDRATABLE
- [ ] A fresh chat answered all seven questions from the three artifacts alone
- [ ] Its answers matched the repository (`verify-change.sh`, `git log`)
- [ ] Recorded what the cold window could not answer

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

### 7.1 — Recognition Check (~5 min)

A new claim, with no lab tool built for it:

> **Claim:** after MFIN-2088, Meridian charges the RTP fee on real payments.

Try the evidence you already have:

- **Tests:** `./scripts/test-evidence.sh calculateFee RTP` passes. That proves what
  `calculateFee` returns — not that anything calls it.
- **Dependency proof:** `jdeps` reports class-to-class edges; it cannot answer a
  method-level question.
- **Text:** `grep -rn "calculateFee" src/main/java` finds the definition and a comment, no
  caller.

This is a **method-level reachability** claim, and no helper exists for it. Pick the
mechanism yourself. One way is to count bytecode call sites:

```bash
mvn -q compile
for c in $(find target/classes -name '*.class'); do n=${c#target/classes/}; n=${n%.class}; javap -c -p -cp target/classes "${n//\//.}" | grep -c "PaymentService.calculateFee"; done | awk '{s+=$1} END{print s+0}'
```

**Expected:** `0` — no production class invokes `calculateFee`. The approved fee is correct
and unreachable: verified locally is not delivered.

**Scoping:** wiring the fee into the payment path is outside MFIN-2088's acceptance
criteria. Record it as durable state rather than fixing it here:

```bash
./scripts/ctx.sh evidence add --claim "calculateFee is invoked on a production payment path" --status rejected --mechanism "javap -c call-site scan" --source "target/classes" --observed "0 production call sites"
./scripts/ctx.sh unknown add --question "Should calculateFee be wired into the payment path? (outside MFIN-2088)"
```

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

**Step 2 — Spec the tool (3 min).** Write these five lines down somewhere — anywhere —
**before you touch Copilot.** This is the gate, and it only works if the spec exists
before the code does: it proves you understood the pattern, not just the tool.

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
| No command underneath, just a consistent formatting/reasoning ask | **Prompt file** (`.github/prompts/`) | No tool to wrap — like `/context-kit` in Step 6 |
| Must automatically block or allow an action, not just answer when asked | **Hook** (`.github/hooks/`) | The only primitive that can deny — see `loop-bound.sh` from Stage 5.4 |
| Must hold on every future change, independent of whether Copilot is even open | CI gate | Outside the harness entirely — the backstop when nobody's in a chat |
| Genuinely one-off, won't recur | Disposable — don't save it | Building infrastructure for a question you'll never ask twice is waste |

State which row yours landed in and why. If it's not actually a skill — say a hook fits
better because the real need is "block this automatically," not "answer when asked" —
say so and explain the mismatch rather than forcing it into skill shape. If the honest
answer is disposable, say that too; choosing not to build infrastructure is a valid
engineering decision.

**Step 5 — Report (2 min).** Be ready to say, to the room: the noisy command and its raw
line count, the reduced output and its line count, what you kept and discarded and why,
the failure mode you forced, where the tool lives, and why that deployment choice.

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
| 5 | Package | What's the minimum viable context for the next specific action? |
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

### Closing

Stage 0 opened with two disagreeing sources and a cold Copilot answer that looked
reasonable either way. Everything since has built a repeatable way to tell which parts
of an answer like that are established, and which still need proof — discover before
you retrieve, reduce before context, promote what's durable, bound what a role can
touch, verify outside the model, and rehydrate from artifacts alone. The tool built in
the capstone is the proof that the method, not just the tooling, made the trip.

---

## Troubleshooting

See `docs/TROUBLESHOOTING.md` for the full appendix. Quick pointers:

| Symptom | Fix |
|---|---|
| `./scripts/*.sh` says "not recognized as an internal or external command" | Your VS Code integrated terminal is on PowerShell, not Git Bash — see [Windows setup](#windows-setup--read-this-before-stage-1) |
| Agents don't appear in the mode dropdown | Confirm you opened `context-engineering-part-2/` itself as the VS Code workspace root, not a parent folder |
| `ctx.sh` or `context-for.sh` says "no .context/context-register.yaml" | Run `./scripts/ctx.sh init` (Stage 1.4) first |
| `verify-change.sh` fails "pricing authority recorded" or "change inside declared scope" | No decision recorded yet (Stage 4.5), no `HANDOFF.md`, or no `.workflow/baseline` — run `./scripts/lab-start.sh` and complete Stage 4.5 |
| `jshell` not found | It ships with JDK 17+; check `java -version` and that `jshell` is on `PATH` |
| `loop.sh check` prints REDUNDANT RETRY (exit 6) | Nothing under `src/` changed since the last attempt, so re-running cannot change the result. Make a change first |

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
