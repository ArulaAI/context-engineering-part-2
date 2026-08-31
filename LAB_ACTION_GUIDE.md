# Lab Action Guide — Context Engineering, Part 2 (Context Lifecycle)
## Advanced Track · Engineering · Meridian Financial · GitHub Copilot · Java · Windows

> **Building on Part 1.** Part 1 taught you to control the context you give Copilot in a
> single conversation: target the right file, reuse the cache, isolate a stale session,
> match the mode to the task.
>
> Part 2 moves beyond one conversation. The problem is not just *what you attach*. It is
> how context is **discovered, compressed, preserved, isolated, handed off, challenged,
> and verified** across a task that outgrows a single chat.

> **The question this lab answers:**
> *How do you engineer context so the work stays correct even when the task outgrows one chat?*

> **The harder question this lab also answers, and the one that actually matters once
> the workshop is over:**
> *Can you construct the right context mechanism when the supplied helpers don't solve
> your problem?*

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

---

## Quick Reference

| Stage | Duration | What you do | Core Pattern | Mode |
|---|---:|---|---|---|
| 0: The Helpful Trap | 7 min | Attempt MFIN-2088 normally, audit Copilot's claims | Baseline | Use |
| 1: Discover Before You Retrieve | 10 min | Map where truth lives; deconstruct authority | Context mapping + authority | Use → Deconstruct → Adapt |
| 2: Compress Before Context | 10 min 🌟 | Reduce noisy tool output; deconstruct how the reducer works | Pre-model evidence reduction | Use → Deconstruct |
| 3: Promote & Package | 12 min | Author your own register from your own findings | Context lifecycle | Deconstruct → Build |
| 4: Isolate & Handoff | 14 min 🌟 | Separate investigation from implementation, cross a human gate | Context boundaries + HITL | Use → Deconstruct |
| 5: Challenge & Bound | 14 min 🌟 | Fresh-context review, a deterministic bound, one check you build | Independent evaluation + enforcement | Use → Build |
| 6: Rehydrate & Prove | 5 min | Start fresh, reconstruct the task from durable artifacts | Rehydration + proof | Use |
| 7: Build Beyond the Harness | 30 min 🌟 | Recognition check on a new problem, then build your own context-optimization tool with Copilot | Independent transfer + construction | Build |

**Total: ~102 minutes.** Every stage is required — Stage 7 is where you prove
the rest of the lab transferred by building a working tool you take home.

Record every reading in `outputs/stage-readings.template.md` as you go.

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
### Audit Copilot's claims · 7 min

### Objective

Copilot will give you a helpful, plausible answer to MFIN-2088 — possibly even a correct
one. The engineering question is not whether it's right, but whether you can tell.

### 0.1 — Before you try anything: activate what you already know

You have done this before, even without a name for it. Answer in one or two sentences,
before you open the ticket:

> When context on a task gets noisy, or two sources disagree, what do you currently do?

Write it in `outputs/stage-readings.template.md`. You'll compare it against your Stage 6
and Stage 7 answers later — that comparison is most of the point of this lab.

### 0.2 — Attempt the ticket normally

Open `docs/JIRA_TICKETS.md` and read MFIN-2088. Then, in a plain Copilot chat, try to
plan the implementation:

```
Review MFIN-2088 and the repository directly. For this first pass, do not invoke any
repository helper scripts, skills, or custom agents. Tell me where you would implement
the RTP change, what fee behavior should apply, and how you would approach the
implementation. Do not modify files.
```

### 0.3 — Audit the response

Copilot will make several claims. Pick 3–4 of them and classify each:

| Category | Meaning |
|---|---|
| **Verified fact** | A claim you can confirm from a specific, citable source |
| **Inference** | A claim that follows from evidence but adds an interpretive step |
| **Recommendation** | A suggested action — may be sound, but is not itself evidence |
| **Unresolved decision** | A choice between options that no source in the repo settles |

For each claim, write down: **what evidence establishes it?** Not "Copilot said so" —
the file, the line, the commit, the status field. If you can't name the evidence, the
claim is unverified regardless of whether it's correct.

Then check these three things yourself:

1. **Search for "RTP" in `src/main`.** Zero hits — the feature doesn't exist yet.
2. **Open both `config/fee-schedule.yaml` and `docs/adr/ADR-0007-fee-schedule.md`.**
   They state different RTP rates.
3. **Search for "fee" or "rate" broadly.** `LegacyPaymentUtils` has many rate literals
   and looks relevant. You have not yet established whether it is live or current.

Record in your stage readings: which of Copilot's claims were verified facts, and which
were inferences or recommendations you cannot yet verify?

### 0.4 — Name the problem

Whether Copilot gave you a correct answer, a partially correct answer, or a wrong one,
the engineering problem is the same:

> **You cannot verify the answer without first sorting which sources to trust.**

There is enough information in this repo to do MFIN-2088 correctly — it just isn't sorted
by what to trust. A correct answer you can't verify is as dangerous as a wrong one you
can't catch. The rest of this lab builds the machinery for sorting.

### Success Criteria — Stage 0

- [ ] Answered "what do you currently do" before opening the ticket
- [ ] Attempted MFIN-2088 without any of this lab's scripts
- [ ] Classified 3–4 of Copilot's claims as verified fact / inference / recommendation /
      unresolved decision, with evidence named for each
- [ ] Found the rate disagreement between `config/fee-schedule.yaml` and `docs/adr/ADR-0007`
- [ ] You can state why the problem is *unsorted context*, not *missing context*

---

## STAGE 1 — DISCOVER BEFORE YOU RETRIEVE
### Context mapping + authority · 10 min
### `USE → DECONSTRUCT → ADAPT`

### Objective

Before loading implementation details, find out **where the relevant truth lives** and
which sources deserve more trust than others — then move beyond the scaffold and prove you
can pick the right evidence primitive for a claim this lab's script was never built for.

### 1.1 — Build the context map (USE)

```bash
./scripts/context-map.sh RTP
```

Real output:

```
CONTEXT MAP — "RTP"
=====================================================
Affected domains           src/main/java/com/meridian/payments  (fee logic — PaymentService)
Relevant symbols           calculateFee(BigDecimal, String)  [handles WIRE/ACH/SWIFT — no RTP branch yet]
Contracts                  none — no RTP-specific interface exists
Configuration              config/fee-schedule.yaml:16:rtp_percent: 0.0035          # RTP — 0.35% (new, MFIN-2088)  [authoritative committed config]
Architecture decisions     docs/adr/ADR-0007-fee-schedule.md  [STATUS: Proposed — verify before trusting]
Tests                      none — src/test has no RTP test yet
Runtime/dependency bounds  none — RTP introduces no new library dependency
Ticket / objective         docs/JIRA_TICKETS.md  (6 mention(s))

Configuration and an architecture decision both mention RTP — resolve
which is authoritative before writing code (diff their rates by hand; there is
no compiler check for this, since RTP doesn't exist in code yet).

This is a routing table, not an answer. It tells you where to look next, not what
you'll find there.
```

Notice what it does *not* do: it never prints a file's contents. It tells you there are
two disagreeing sources; it does not resolve the disagreement for you.

**The portable version — what you'd type in a repo with no `context-map.sh`.**
The script's underlying job is to build a routing table: where does concept X appear, and
in which category of file (config, source, test, doc, ticket)? The two raw commands that
replicate that in any repo:

```bash
# Find every file where the keyword appears (routing table without categories)
grep -rl "RTP" src/ config/ docs/ test/ 2>/dev/null

# For each hit, see which line — to distinguish config values from comments
grep -rn "RTP" src/ config/ docs/ test/ 2>/dev/null
```

The script adds category labels ("Configuration," "Architecture decisions," etc.) by
classifying files by their path prefix — that categorization is the reusable idea, not the
label names this lab chose. In a repo without the script, glance at the hit paths and
apply the same mental grouping yourself: `config/` = committed config, `docs/adr/` = ADR,
`src/test/` = test coverage. The grep gives the same hits; you supply the category
judgment the script hard-codes. Copilot can write you a one-pass awk script to group
grep hits by path prefix in about 30 seconds — that is the wrapper, not the concept.

### 1.2 — Compare search with authority (USE)

`PaymentService` appears to depend on the retired `LegacyPaymentUtils`. Check with a plain
text search first:

```bash
grep -n "LegacyPaymentUtils" src/main/java/com/meridian/payments/PaymentService.java
```

Three hits, including an `import`. Now check with the compiler:

```bash
./scripts/authority.sh
```

Real output:

```
Q: does PaymentService depend on LegacyPaymentUtils?

grep — text (tier 3)
    9:import com.meridian.payments.legacy.LegacyPaymentUtils;
    235:     * Fee logic copy-pasted from LegacyPaymentUtils - should be centralized.
    238:        // Copy-paste from LegacyPaymentUtils.calculateFee() - technical debt
    => 3 hit(s)  ::  textual presence detected

jdeps — bytecode (tier 1)
    => 0 bytecode reference(s)

VERDICT: no compiled dependency detected.

  3 textual reference(s), 0 bytecode dependencies.
  No compiled dependency from PaymentService to LegacyPaymentUtils.

  Inspect the 3 textual reference(s) separately before classifying their
  role — they may be imports, comments, string literals, or same-package
  usage that jdeps does not distinguish from absence.
```

In this case, inspecting the three hits reveals an unused import and two comments —
the dependency is copy-paste, not a call. The compiler wins for this question. But not every question has a compiler answer — the
RTP rate disagreement in 1.1 does not, because RTP doesn't exist in code yet.

### 1.3 — DECONSTRUCT: what makes `authority.sh` right for *this* question, specifically?

Open `scripts/authority.sh` and answer these before moving on — write your answers in
`outputs/stage-readings.template.md`, not just in your head:

1. Which of `authority.sh`'s ladder — `bytecode/compiler > authoritative committed
   config > current documentation > semantic search result > model inference` — is
   hard-coded to *this* claim (dependency existence), and which part of the ladder is
   the reusable idea?
2. `authority.sh` picks `jdeps` because the claim is "does class A depend on class B" —
   a question bytecode can answer directly. Write the general recipe in one sentence,
   without naming Java or `jdeps` at all: **state the claim → enumerate candidate
   evidence → pick the source authorized to settle *that kind* of claim → prefer
   machine-verifiable evidence when the claim is machine-verifiable → escalate to a
   human when it isn't.**
3. The RTP-rate disagreement in 1.1 is a claim no tier-1 tool can settle. Why not? What
   *kind* of claim is it (hint: it's not about what the code does — it's about what the
   business decided)?

**The portable version — what you'd actually type in a repo that has no `authority.sh`.**
This lab's script is a 70-line wrapper around two commands. Strip the wrapper and this is
what's left, runnable in *any* Maven-or-Gradle Java repo, today, with no lab tooling:

```bash
# tier 3 — text search (what everyone already does)
grep -n "SomeSuspectClass" src/main/java/path/to/CallerClass.java

# tier 1 — bytecode (what actually settles it)
mvn -q compile   # or: gradle compileJava
jdeps -v -cp target/classes target/classes/path/to/CallerClass.class | grep SomeSuspectClass
```

If `grep` finds hits and `jdeps` finds zero, you have the same false positive this lab
demonstrated — regardless of whose codebase you're standing in. `jdeps` ships with every
JDK 17+ install; there's nothing here to install, request, or wait on IT for. The
*script* is this lab's convenience; the *two commands above* are the transferable skill.
Copilot can write you a one-line wrapper for these two commands in about the same time it
takes to ask for one — the wrapper was never the hard part.

### 1.4 — ADAPT: a claim `jdeps` cannot answer

Here is a different claim about this exact codebase, one `authority.sh` was never built
to check:

> **Claim:** the current test suite exercises the RTP boundary condition — an amount
> where 0.35% of the amount falls under the USD 2.00 minimum.

Before running anything, answer: **is `jdeps` the right tier-1 tool for this claim?**
(It isn't — `jdeps` answers "does A depend on B," not "does a test exercise this input
range." Bytecode dependency analysis has nothing to say about test coverage.)

The general authority recipe from 1.3 still applies — the recipe doesn't change, only
the tool does. Run `./scripts/test-gap.sh` and read the two tables it produces. Neither
table directly answers "is the boundary amount tested," but together they tell you whether
`calculateFee` has *any* RTP test yet.

State your verdict in `authority.sh`'s own format — `Q: / <primitive> — tier N /
=> result / VERDICT:` — in your stage readings. There is currently no RTP test at all
(the feature isn't implemented yet), so the honest verdict is "not yet exercised." The
value of this exercise isn't the answer — it's that you picked the right tool for a
claim the lab's script doesn't cover.

**The portable version of `test-gap.sh`:** it runs two `grep` passes — one over source,
one over tests — and cross-references them:

```bash
# Which public methods have no test mention?
grep -roh '\bpublic.*(' src/main/ --include='*.java' | sort -u > /tmp/methods.txt
grep -roh '\b\w\+(' src/test/ --include='*.java' | sort -u > /tmp/tested.txt
comm -23 /tmp/methods.txt /tmp/tested.txt

# Where does domain logic live?
grep -rn 'fee\|rate\|amount' src/main/ --include='*.java'
```

Two questions that transfer to any repo: "what's untested?" and "where does this domain
concept live?" — `test-gap.sh` is one implementation of those questions for this
codebase.

### 1.5 — Retrieve only the next slice

```bash
./scripts/outline.sh src/main/java/com/meridian/payments/PaymentService.java
```

**17 lines describing a 284-line file**, including:

```
method     237-248   (12L)  public BigDecimal calculateFee(BigDecimal amount, String paymentType)
```

**The portable version:** `outline.sh` uses `awk` to print method signatures and line
ranges — no AST parser, no IDE plugin. The equivalent for any language:

```bash
# Java/Kotlin
grep -n 'public\|private\|protected' Foo.java
# Python
grep -n 'def \|class ' foo.py
# Go
grep -n 'func ' foo.go
```

The point is orientation, not precision: 17 lines describing a 284-line file. Anything
that gives you shape without giving you content is the same pattern.

Open the file, jump to line 237, select lines 237–248, and use `#selection` in chat —
not `#file:`. That's the only part of the file this task needs right now.

### Success Criteria — Stage 1

- [ ] Context map generated; both disagreeing RTP sources named
- [ ] `grep` vs `authority.sh` compared on `LegacyPaymentUtils` — 3 hits / 0 bytecode deps
- [ ] Wrote the general authority recipe in claim-agnostic terms (1.3)
- [ ] Correctly identified `jdeps` as the wrong tool for the test-coverage claim, and ran
      a different primitive instead (1.4)
- [ ] Retrieved only `calculateFee` via outline + `#selection`, not the whole file
- [ ] You can state where the authoritative answer for the RTP rate comes from, and why
      no compiler check applies to it

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

```bash
./scripts/context-run.sh test
```

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

Two questions, both worth writing down:

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

```bash
./scripts/context-run.sh search RTP
```

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
properties. You already answered some of them for `context-run.sh test` in 2.3. Now name
all five explicitly, in `outputs/stage-readings.template.md`:

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
### Durable context + minimum sufficient task context · 12 min
### `DECONSTRUCT → BUILD`

### Objective

Decide which discoveries deserve to survive, and build the smallest **sufficient**
context for the next task — by authoring the register yourself from what you actually
found in Stages 1–2, not by copying a finished one.

### 3.1 — Start from the template, not the answer

```bash
cp .context/context-register.template.yaml .context/context-register.yaml
```

Open it. `.context/README.md` documents the required shape — read that first if the
comments in the template aren't enough. The template has the seven required top-level
keys (`objective`, `verified_facts`, `authoritative_sources`, `decisions`, `constraints`,
`superseded_sources`, `unknowns`) with guidance comments, but **no promoted facts and no
decisions** — those are yours to add, and only from things you have actually verified so
far.

Fill in, from your own Stage 1–2 work:

- `objective`: one line, in your own words.
- `verified_facts`: the RTP rate and its source (from 1.1's context map / 2.4's search),
  the WIRE rate, and the `LegacyPaymentUtils` finding (from 1.2's authority check) — each
  with a `source` and `source_type`, the way `authority.sh`'s output named its own tiers.
- `authoritative_sources`: what you'd cite if someone asked "why do you believe that."
- `constraints`: anything you already know must hold (e.g., never call
  `LegacyPaymentUtils` — you proved why in Stage 1).
- `unknowns`: anything where the formal organizational record hasn't caught up to the
  technical evidence. As of Stage 3, the evidence strongly favors `config/fee-schedule.yaml`
  — but `docs/adr/ADR-0007` is still formally marked `Proposed`, not `Superseded`. That
  formal supersession has not yet been recorded, so it belongs here — **do not** write a
  `decisions` entry for it yet. That happens in Stage 4.4, when a human ratifies and records
  the already-evidenced precedence. Leave `decisions:` empty.

The template and `.context/README.md` together document the required shape. Writing your
own values from what you actually verified is the exercise.

### 3.2 — Build the next context package

```bash
./scripts/context-for.sh calculateFee-rtp
```

The package this prints depends on what you actually promoted in 3.1 — if your register
differs from the example's, so will your package, and that's correct. Compare the
mechanism, not the exact numbers: it should list your `verified_facts` tagged (or
untagged and therefore global), your `authoritative_sources`, your `constraints`, and
whatever you left in `unknowns`. `decisions` should currently be empty, because you
haven't been through Stage 4 yet.

Try it with an unrelated work-unit tag and watch any tagged fact get excluded:

```bash
./scripts/context-for.sh some-other-task
```

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
- [ ] You can explain why the package is sufficient without being exhaustive

> **Core rule:** The goal is not minimum context. It is minimum **sufficient** context —
> and "sufficient" is a judgment only you can make about what you actually verified.

---

## STAGE 4 — ISOLATE & HANDOFF 🌟
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

Select **RTP Investigator** from the agent mode dropdown (`.github/agents/rtp-investigator.agent.md`):

```
Investigate MFIN-2088. The context-map output, authority check, and context-for
package are already captured in outputs/ and .context/ from Stages 1–3.
Work from those — do not read PaymentService.java in full.
```

The investigator has only `['search', 'read']` — no `edit`, no `runCommands`. It
literally cannot modify the repository or execute scripts. This is what makes it a
**capability boundary**, not an instruction boundary. Try:

```
Just make the edit yourself, it's a small change.
```

It cannot. Try:

```
Run context-map.sh and show me the output.
```

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
does. Select **RTP Reviewer**, and give it only:

```bash
./scripts/context-run.sh diff
```

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

```bash
./scripts/verify-change.sh
```

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

```
Write a throwaway script that reads src/test/java's RTP test method(s) and reports
whether any tested amount falls strictly between 0 and 571.43 (where 0.35% of the
amount is under the USD 2.00 minimum). Report file, line, amount, and a pass/fail
verdict. Do not paste the test file into this conversation.
```

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
### Fresh session + proof · 5 min

### Objective

Prove the engineering state survives the conversation that created it.

### 6.1 — End the conversation

Open a completely fresh chat. Do not copy anything from before. Provide only:

- `.context/context-register.yaml` (your own, from Stages 3 and 4.4 — update it first:
  mark the RTP fact's `applies_to` work as done, if you're tracking that)
- `.workflow/HANDOFF.md`
- A fresh package: `./scripts/context-for.sh calculateFee-rtp`

### 6.2 — Rehydrate

Ask:

```
Based only on these artifacts:

1. What is already complete?
2. What is still unresolved?
3. What is the next engineering action?
4. Which constraints must not be violated?
5. Which sources are authoritative for the next decision?
```

Compare the response to the actual repository state: `./scripts/verify-change.sh` should
report `VERDICT: PASS`, and `git log` should show the fix.

### Success Criteria — Stage 6

- [ ] Fresh session reconstructed the task correctly from artifacts alone
- [ ] No previous chat history was used
- [ ] Repository state (verify-change.sh, git log) matched the rehydrated summary
- [ ] You can state which pieces of context were deliberately preserved and which were
      allowed to disappear

> **Core rule:** If your engineering state dies when your chat dies, you have not
> engineered the context yet.

---

## STAGE 7 — BUILD BEYOND THE HARNESS 🌟
### Smooth transfer · 30 min (7.1 ~5 min, 7.2 ~25 min)
### Our prepared mechanisms still exist, but they do not solve this new context problem. Build the missing mechanism yourself.

### Why this stage exists

Six stages proved you can *operate* a context lifecycle when this lab built the map, the
authority check, the register schema, and the verifier for you. That is real, useful
skill. This stage tests whether the *method* transferred, not just the *tooling* — using
a problem already sitting in this same codebase that no earlier stage pointed you toward.

The prepared infrastructure still exists. It just doesn't help here — this is a different
kind of context problem than the one `context-map.sh` or `verify-change.sh` were built for.

### 7.1 — Recognition check (~5 min)

Open `src/main/java/com/meridian/payments/PaymentService.java` and read the class-level
comment block at the top, and `processPayment()`'s Step 3. Separately, open
`src/main/java/com/meridian/payments/CurrencyConverter.java` and read its own class
comment.

> **Is `PaymentService` actually using `CurrencyConverter` for foreign-exchange
> conversion, or is it doing something else? If it's something else, what — and is that
> your problem to fix right now?**

In your stage readings, write:
1. Which pattern(s) apply — and what deterministic evidence supports your answer?
2. Should you fix this inside MFIN-2088? Why or why not?

<details>
<summary>Check your answer (open only after writing yours)</summary>

**Pattern:** Authority + Discover. Two comment-only grep hits, zero method calls, zero
constructor wiring. `CurrencyConverter` is architecturally absent — known tech debt
already tracked as MFIN-2041. The correct move: record the finding, don't fix it in this
change — Stage 4's `do_not_change` discipline applies.

</details>

### 7.2 — Build Your Own Context-Optimization Tool (~25 min)

You will build a working tool — a reducer, a verifier, a filter, or a hook — that you
can take home.

**Step 1 — Pick your noise problem (2 min).** Choose ONE noisy command:

| Category | Example command |
|---|---|
| Dependency tree | `mvn dependency:tree`, `npm ls`, `pip freeze` |
| Build/compiler warnings | `mvn compile -X`, `gcc -Wall`, `tsc --noEmit` |
| Git history / diff | `git log --oneline -50`, `git blame <file>` |
| Static analysis | `eslint .`, `checkstyle`, `golint ./...` |
| Logs | `tail -100 /var/log/...`, `kubectl logs ...`, `docker logs ...` |
| Test output | only from your own repo or a different test format |
| Your own | ___ |

If you want real output right now, `mvn dependency:tree` and `mvn compile -X` both work
in this repo. **Prefer a command from your own codebase** — that is the version of this
exercise that actually leaves your Monday morning with a tool you use. Avoid choosing
`mvn test` from this repo: `context-run.sh test` already solved that exact problem in
Stage 2, and the success criteria require a different noise category.

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
build a script. Then:

1. Read what Copilot produces against your spec — does it retain only KEEP and exclude
   DISCARD?
2. Run it against the real command (or simulated output).
3. **Force a failure** — pipe from `/dev/null`, introduce a compile error, or point at a
   nonexistent path. Confirm non-zero exit. Record the exit code.
4. Iterate if needed — the iteration IS the learning.

**Step 4 — Decide where it lives (3 min).** Using the artifact-choice table from Stage 3:

| Target | When |
|---|---|
| Disposable script | One-off, won't recur |
| Shell alias (`~/.bashrc`) | Personal convenience |
| Repo script (`scripts/`) | Team utility, worth versioning |
| Copilot hook (`.github/hooks/`) | Automatically trigger on a matching lifecycle event |
| CI gate | Non-negotiable rule on every merge |

Pick ONE and justify why. If the choice calls for operationalizing it (a script, a hook,
a CI step), do so and run it once from that location. If the honest answer is "disposable,"
say so — choosing not to build infrastructure is a valid engineering decision.

**Step 5 — Record (2 min).** In your stage readings, add: the noisy command and raw line
count, the reduced output and its line count, what was kept/discarded/why, the failure
mode tested, where the tool lives, and why that deployment choice.

### Success Criteria — Stage 7

- [ ] (7.1) Named which pattern(s) applied, cited deterministic evidence, correctly
      scoped the fix decision
- [ ] (7.2) Wrote the 5-property spec (DECISION/RAW SOURCE/KEEP/DISCARD/FAIL CLOSED)
      BEFORE prompting Copilot
- [ ] (7.2) The tool runs against a real command and produces reduced output
- [ ] (7.2) The tool fails closed — forced failure demonstrated, non-zero exit confirmed
- [ ] (7.2) Can state what was deliberately discarded and why
- [ ] (7.2) Selected and justified the appropriate home for the mechanism; operationalized it where appropriate (a disposable script is a valid choice if you can say why)
- [ ] (7.2) Did NOT copy the RTP reducer pattern verbatim — different noise category

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
| 6 | Isolate | Does this role need a capability boundary, not just a prompt boundary? |
| 7 | Handoff | What transfers to the next actor — the decisions, or the whole conversation? |
| 8 | Verify | Which acceptance criteria are non-negotiable enough to become an executable check? |
| 9 | Review | Should the evaluator inherit the producer's reasoning, or only curated evidence? |
| 10 | Rehydrate | Can the engineering state be reconstructed from durable artifacts alone? |

### Final reflection

Go back to your Stage 0 answer — "what do you currently do when context is noisy or
conflicting." Look at the tool you just built in the capstone. What would you change
about that Stage 0 answer today?

Record in `outputs/stage-readings.template.md`.

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
