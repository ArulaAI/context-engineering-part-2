# Lab Action Guide — Context Engineering, Part 2 (Context Lifecycle)
## Advanced Track · Engineering · Meridian Financial

> **Building on Part 1.** Part 1 taught you to control the context you give Copilot in a
> single conversation: target the right file, reuse the cache, isolate a stale session,
> match the mode to the task.
>
> Part 2 moves beyond one conversation. The problem is not just *what you attach*. It is
> how context is **discovered, compressed, preserved, isolated, handed off, challenged,
> and verified** across a task that outgrows a single chat.

> **The question this lab answers:**
> *How do you engineer context so the work stays correct even when the task outgrows one chat?*

This lab runs one workflow from beginning to end — MFIN-2088, adding SEPA transfer fees
to Meridian's payment service — and progressively replaces ad hoc context usage with a
small, repeatable context lifecycle. Every number in this guide was captured from a real
run against this repo; none are estimated.

---

## Quick Reference

| Stage | Duration | What you do | Core Pattern |
|---|---:|---|---|
| 0: Outgrow the Window | 8 min | Attempt MFIN-2088 normally, capture the failure mode | Baseline |
| 1: Discover Before You Retrieve | 12–14 min | Map where truth lives before loading source | Context mapping + authority |
| 2: Compress Before Context | 15 min 🌟 | Reduce noisy tool output before Copilot sees it | Compute, don't paste |
| 3: Promote & Package | 15 min | Turn verified discoveries into durable, task-specific context | Context lifecycle |
| 4: Isolate & Handoff | 18 min 🌟 | Separate investigation from implementation, cross a human gate | Context boundaries + HITL |
| 5: Challenge & Bound | 15 min | Fresh-context review + a deterministic bound outside the model | Independent evaluation + enforcement |
| 6: Rehydrate & Prove | 8–10 min | Start fresh, reconstruct the task from durable artifacts | Rehydration + proof |

**Total:** approximately 90 minutes. Stages 2, 4, and 5 are the core and should not be cut.

Record every reading in `outputs/stage-readings.template.md` as you go.

---

## Before You Start

```bash
mvn clean test
```

Expected: `BUILD SUCCESS`, `Tests run: 5, Failures: 0`.

Open this folder (`lab-context-lifecycle/`) as its own VS Code window — not as a subfolder
of anything else. Copilot's agent, skill, and hook discovery resolves per workspace root,
and this lab ships its own `.github/agents/`, `.github/skills/`, and `.github/hooks/`.

The repository is deliberately constructed so that:

- the SEPA rate is stated in two places that disagree (`config/fee-schedule.yaml` says
  0.35% with a EUR 2.00 minimum; `docs/adr/ADR-0007-fee-schedule.md` says 0.30% flat, no
  minimum, and was never marked superseded),
- `LegacyPaymentUtils` still contains a retired 1% WIRE rate that shows up in a text
  search and reads like a live dependency,
- the task cannot be completed safely by reading everything into one conversation,
- a plausible SEPA implementation can pass a casual read and still violate the ticket.

Do not go looking for any of this yet. Stage 0 is where you first hit it.

---

## STAGE 0 — OUTGROW THE WINDOW
### Baseline failure · 8 min

### Objective

Experience what happens when MFIN-2088 is approached as one large conversation.

### 0.1 — Attempt the ticket normally

Open `docs/JIRA_TICKETS.md` and read MFIN-2088. Then, in a plain Copilot chat — no
`context-map`, `context-run`, or agent modes yet — try to plan the implementation:

```
Meridian is adding SEPA Credit Transfer as a supported payment type per MFIN-2088.
Where should this be implemented, and what rate should it use?
```

Search the repository, ask questions, inspect files, as you normally would.

### 0.2 — Record what happened

You should be able to observe, concretely:

- **Zero hits for "SEPA" anywhere in `src/main`** — the feature doesn't exist yet, so a
  search for it teaches you nothing about where to add it.
- **A rate contradiction if you look in both places** — `config/fee-schedule.yaml` says
  0.35% with a EUR 2.00 minimum; `docs/adr/ADR-0007-fee-schedule.md` says 0.30% flat, no
  minimum. Nothing in the repo tells you which one is current.
- Likely, **an unprompted mention of `LegacyPaymentUtils`** if the model searches broadly
  for "fee" or "rate" — it's the file with the most rate literals in the tree, and none
  of them are current.

### 0.3 — Name the failure

> Did Copilot fail because it had too little context, or because the context it
> assembled was noisy, incomplete, stale, or conflicting?

The honest answer is usually the second one. There's enough information in this repo to
do MFIN-2088 correctly — it just isn't sorted by what to trust.

### Success Criteria — Stage 0

- [ ] Attempted MFIN-2088 without any of this lab's scripts
- [ ] Confirmed zero hits for "SEPA" in `src/main`
- [ ] Found the rate disagreement between `config/fee-schedule.yaml` and `docs/adr/ADR-0007`
- [ ] You can state why "more context" would not automatically fix this

---

## STAGE 1 — DISCOVER BEFORE YOU RETRIEVE
### Context mapping + authority · 12–14 min

### Objective

Before loading implementation details, find out **where the relevant truth lives** and
which sources deserve more trust than others.

### 1.1 — Build the context map

```bash
./scripts/context-map.sh SEPA
```

Real output:

```
CONTEXT MAP — "SEPA"
=====================================================
Affected domains           src/main/java/com/meridian/payments  (fee logic — PaymentService)
Relevant symbols           calculateFee(BigDecimal, String)  [handles WIRE/ACH/SWIFT — no SEPA branch yet]
Contracts                  none — no SEPA-specific interface exists
Configuration              config/fee-schedule.yaml:16:sepa_percent: 0.0035          # SEPA — 0.35% (new, MFIN-2088)  [authoritative committed config]
Architecture decisions     docs/adr/ADR-0007-fee-schedule.md  [STATUS: Proposed — verify before trusting]
Tests                      none — src/test has no SEPA test yet
Runtime/dependency bounds  none — SEPA introduces no new library dependency
Ticket / objective         docs/JIRA_TICKETS.md  (6 mention(s))

Configuration and an architecture decision both mention SEPA — resolve
which is authoritative before writing code (diff their rates by hand; there is
no compiler check for this, since SEPA doesn't exist in code yet).

This is a routing table, not an answer. It tells you where to look next, not what
you'll find there.
```

Notice what it does *not* do: it never prints a file's contents. It tells you there are
two disagreeing sources; it does not resolve the disagreement for you.

### 1.2 — Compare search with authority

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
    => 3 hit(s)  ::  reads as A LIVE DEPENDENCY

jdeps — bytecode (tier 1)
    => 0 bytecode reference(s)

VERDICT: the search result is a FALSE POSITIVE.

  3 textual hits, 0 bytecode dependencies. The import is dead and the rest
  are comments. The duplication is copy-paste, not a call — so "remove the
  dependency" is the wrong ticket. The compiler disproved the search for free.

  A model asked the same question reads the same 3 lines and agrees with grep.
```

The compiler wins for this question. But not every question has a compiler answer — the
SEPA rate disagreement in 1.1 does not, because SEPA doesn't exist in code yet. That's
the useful hierarchy for this lab:

```
bytecode/compiler > authoritative committed config > current documentation
> semantic search result > model inference
```

For the SEPA rate, `config/fee-schedule.yaml` is the highest tier with an actual answer.

### 1.3 — Retrieve only the next slice

```bash
./scripts/outline.sh src/main/java/com/meridian/payments/PaymentService.java
```

**17 lines describing a 284-line file**, including:

```
method     237-248   (12L)  public BigDecimal calculateFee(BigDecimal amount, String paymentType)
```

Open the file, jump to line 237, select lines 237–248, and use `#selection` in chat —
not `#file:`. That's the only part of the file this task needs right now.

### Success Criteria — Stage 1

- [ ] Context map generated; both disagreeing SEPA sources named
- [ ] `grep` vs `authority.sh` compared on `LegacyPaymentUtils` — 3 hits / 0 bytecode deps
- [ ] Retrieved only `calculateFee` via outline + `#selection`, not the whole file
- [ ] You can state where the authoritative answer for the SEPA rate comes from, and why
      no compiler check applies to it

> **Core rule:** First establish where truth lives. Then retrieve it.

---

## STAGE 2 — COMPRESS BEFORE CONTEXT 🌟
### Compute, don't paste · 15 min

### Objective

Reduce noisy tool output **before** it reaches the model.

### 2.1 — The expensive path

```bash
mvn test
```

Raw output: **45 lines** even in this small, dependency-cached repo (a real project's raw
`mvn test` runs to hundreds or thousands of lines). Almost none of it is a decision input.

### 2.2 — The compressed path

```bash
./scripts/context-run.sh test
```

Real output:

```
TEST SUMMARY
5 passed
0 failed

REGRESSION SIGNAL
none — all fee-calculation tests (WIRE/ACH/SWIFT) unaffected

NOISE REMOVED: 39 lines  (raw `mvn test` = 45 lines; digest = 6 lines)
```

The noise-removed figure is computed from the actual byte counts of both runs, not
asserted.

### 2.3 — Search, compressed and cross-checked

```bash
./scripts/context-run.sh search SEPA
```

Real output:

```
11 raw hits across 3 files → 3 shown (dedup: comment/doc noise removed)

FILE                                 LINE   EVIDENCE
--------------------------------------------------------------
config/fee-schedule.yaml             16     sepa_percent: 0.0035          # SEPA — 0.35% (new, MFIN-20
docs/JIRA_TICKETS.md                 11     ## MFIN-2088 — Add SEPA Credit Transfer fee support (Stage
docs/adr/ADR-0007-fee-schedule.md    1      # ADR-0007 — SEPA Transfer Fee Schedule

RATE CROSS-CHECK: config and an ADR both state a SEPA rate. Compare them by hand — THEY MAY DISAGREE.

NOISE REMOVED: 11 lines → 3 lines
```

This is the same disagreement Stage 1 found, surfaced automatically as a cross-check —
you don't have to remember to look for it every time.

### 2.4 — Let Copilot compute instead of read

In Agent mode, for a question the prebuilt scripts don't cover:

```
Write a throwaway shell script that finds every place in src/main/java where a
BigDecimal.valueOf() literal looks like a rate (a number under 1, or a flat fee).
Run it. Return only the resulting table — file, line, value.
Do not paste the source files into this conversation.
```

Watch it write, run, and report without the source files ever entering the window.

### Success Criteria — Stage 2

- [ ] Raw `mvn test` (45 lines) compared against `context-run.sh test` (6-line digest)
- [ ] `context-run.sh search SEPA` run; the rate cross-check warning noted
- [ ] Agent wrote and ran a throwaway script for a question the scripts don't cover
- [ ] You can name a task in your own work where this pattern is sitting unused

> **Core rule:** The cheapest token is the one that never enters the context window.

---

## STAGE 3 — PROMOTE & PACKAGE
### Durable context + minimum sufficient task context · 15 min

### Objective

Decide which discoveries deserve to survive, and build the smallest **sufficient**
context for the next task.

### 3.1 — Promote verified information

Copy the example register to start yours:

```bash
cp .context/context-register.yaml.example .context/context-register.yaml
```

Read it. It promotes exactly three facts (the SEPA rate, the WIRE rate, and the dead
`LegacyPaymentUtils` dependency — each with a source and a tier), records two decisions
a human would make in Stage 4, marks `ADR-0007` as superseded with a warning, and leaves
one open question (`unknowns`). Everything else from Stages 0–2 — the raw `mvn test`
output, the search noise, your own false starts — is deliberately not in it.

### 3.2 — Build the next context package

```bash
./scripts/context-for.sh calculateFee-sepa
```

Real output:

```
CONTEXT PACKAGE — calculateFee-sepa
=====================================================
Objective
  Implement SEPA transfer fee support in calculateFee() per MFIN-2088.

Relevant source files
  src/main/java/com/meridian/payments/legacy/LegacyPaymentUtils.java
  config/fee-schedule.yaml

Applicable verified facts
  - SEPA fee is 0.35% of amount with a EUR 2.00 minimum, applied to the computed fee
    (source: config/fee-schedule.yaml, committed configuration)
  - WIRE fee is 0.25%, current
    (source: config/fee-schedule.yaml, committed configuration)
  - LegacyPaymentUtils WIRE rate (1%) is retired, never current
    (source: src/main/java/com/meridian/payments/legacy/LegacyPaymentUtils.java, bytecode (jdeps: 0 references from PaymentService))

Authoritative contracts/config
  config/fee-schedule.yaml
  docs/adr/ADR-0007-fee-schedule.md is SUPERSEDED by config/fee-schedule.yaml — cites 0.30% flat, no minimum — do not implement from this

Constraints
  - Never call LegacyPaymentUtils
  - Never inline a fee rate outside calculateFee

Decisions
  - The EUR 2.00 minimum compares against the computed fee, not the raw amount  (approved by: human, Stage 4.3)
  - config/fee-schedule.yaml supersedes docs/adr/ADR-0007-fee-schedule.md  (approved by: human, Stage 4.3)

Open questions
  - Should calculateFee read config/fee-schedule.yaml at runtime instead of a hardcoded constant?

-- 3 promoted fact(s) packaged; 0 excluded (not tagged for this work unit).
```

Try it with an unrelated work-unit tag and watch the promoted SEPA fact get excluded:

```bash
./scripts/context-for.sh some-other-task
```

The tagged fact drops out; the untagged, global ones stay. That's the mechanism, not
just the concept — the register is filtered, not re-summarized.

### Success Criteria — Stage 3

- [ ] `.context/context-register.yaml` created from the example, read in full
- [ ] `context-for.sh calculateFee-sepa` run; package matches the register's promoted facts
- [ ] Confirmed that an unrelated work-unit tag excludes the tagged fact
- [ ] You can explain why the package is sufficient without being exhaustive

> **Core rule:** The goal is not minimum context. It is minimum **sufficient** context.

---

## STAGE 4 — ISOLATE & HANDOFF 🌟
### Context boundaries + human-in-the-loop · 18 min

### Objective

Separate investigation from implementation, and put a human in front of the boundary
that actually needs one.

### 4.1 — Run the investigator

Select **SEPA Investigator** from the agent mode dropdown (`.github/agents/sepa-investigator.agent.md`):

```
Investigate MFIN-2088. Use context-map and context-for — do not read
PaymentService.java in full.
```

Its `tools:` list is `['search', 'read', 'runCommands']` — no `edit`. It can run the
lab's scripts but cannot modify the repository, even if you ask it to. Try:

```
Just make the edit yourself, it's a small change.
```

It cannot. That's a capability boundary, not a policy — note *how* it declines.

### 4.2 — The conflict, surfaced and stopped on

Because `config/fee-schedule.yaml` and `docs/adr/ADR-0007-fee-schedule.md` disagree and
neither marks the other superseded, the investigator should stop and emit:

```
CONTEXT CONFLICT

Source A: config/fee-schedule.yaml          — SEPA 0.35% + EUR 2.00 minimum (committed)
Source B: docs/adr/ADR-0007-fee-schedule.md — SEPA 0.30% flat, no minimum (Status: Proposed)

No explicit supersession found.

HUMAN DECISION REQUIRED
```

It does not write `.workflow/HANDOFF.md` yet. This is deliberate: an agent resolving an
authority conflict on its own is exactly the failure mode this lab is teaching you to
design out.

### 4.3 — The human decision

Resolve it. `config/fee-schedule.yaml` is the committed configuration — it wins.
Mark the ADR by hand:

Open `docs/adr/ADR-0007-fee-schedule.md` and change `**Status:** Proposed` to
`**Status:** Superseded by config/fee-schedule.yaml`. This is a real file edit made by
a person, not a chat message.

Tell the investigator the decision is made. It should now write `.workflow/HANDOFF.md`
(compare your output against `.workflow/HANDOFF.md.example`) and stop.

### 4.4 — Implement, from the handoff only

Switch to **SEPA Implementer**. Its input contract is the handoff file — not the
conversation you just had. Apply the pre-seeded implementation:

```bash
git apply fixtures/sepa-implementation.diff
```

This adds a SEPA branch to `calculateFee()` whose comment correctly says "0.35% fee with
a EUR 2.00 minimum" — read it before continuing to Stage 5. Do not fix anything yet.

### Success Criteria — Stage 4

- [ ] Investigator produced a plan without reading the full source, and could not edit
- [ ] The `CONTEXT CONFLICT` block appeared and the investigator stopped on it
- [ ] A human (you) resolved the conflict and edited the ADR's Status by hand
- [ ] `.workflow/HANDOFF.md` written only after the human decision
- [ ] The implementer received the handoff, not the investigation conversation

> **Core rule:** A handoff is a controlled context boundary, not a forwarded conversation.

---

## STAGE 5 — CHALLENGE & BOUND
### Independent evaluation + deterministic limits · 15 min

### Objective

Don't let the context that produced a change be the only context that validates it.
Then move the hard requirement outside the model entirely.

### 5.1 — Fresh-context review

**Open a brand-new Copilot chat — do not just switch modes in this one.** Mode-switching
inside the same thread does not clear what the model has already seen; only a new chat
does. Select **SEPA Reviewer**, and give it only:

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
(`calculateFee(100.00, "SEPA")`) rather than pattern-matching the comment against the
acceptance criteria, and catch that it returns `0.35`, not the required `2.00`.

### 5.2 — The deterministic check

```bash
./scripts/verify-change.sh
```

Real output, against the seeded fixture:

```
✓ required behavior preserved       (5 tests, 0 failures — WIRE/ACH/SWIFT unaffected)
✓ existing path unchanged            (diff touches only calculateFee, lines 237-254)
✓ prohibited dependency absent       (0 bytecode references to LegacyPaymentUtils)
✗ authoritative configuration respected
    calculateFee(100.00, "SEPA") = 0.35 — config/fee-schedule.yaml requires >= 2.00
    for any amount where 0.35% of amount is under the EUR 2.00 minimum (amount < 571.43)

VERDICT: FAIL — 1 of 4 checks failed
```

The comment on the buggy branch says "EUR 2.00 minimum" and is telling the truth about
intent. The bug is that it compares the *raw amount* to 2.00 instead of the *computed
fee* to 2.00 — correct for large transfers, wrong for everything roughly between EUR 2
and EUR 571. This script doesn't read the comment. It calls the compiled method and
checks the number.

### 5.3 — Bound the repair loop

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

Now fix the bug: compare the computed fee, not the raw amount.

```java
BigDecimal sepaFee = amount.multiply(BigDecimal.valueOf(0.0035)).setScale(2, RoundingMode.HALF_UP);
if (sepaFee.compareTo(BigDecimal.valueOf(2.00)) >= 0) {
    return sepaFee;
}
return BigDecimal.valueOf(2.00);
```

```bash
./scripts/loop.sh reset
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
```

Real output:

```
✓ required behavior preserved       (5 tests, 0 failures — WIRE/ACH/SWIFT unaffected)
✓ existing path unchanged            (diff touches only calculateFee, lines 237-255)
✓ prohibited dependency absent       (0 bytecode references to LegacyPaymentUtils)
✓ authoritative configuration respected   (calculateFee(100.00, "SEPA") = 2.0)

VERDICT: PASS — 4 of 4 checks passed
DONE — green.
```
Exit code `0`.

### Success Criteria — Stage 5

- [ ] Fresh reviewer found (or you can explain why it should have found) the
      amount-vs-computed-fee bug, citing a concrete example
- [ ] `verify-change.sh` reproduced the same failure deterministically
- [ ] You ran the loop into thrashing (exit 4) on purpose and can say why it differs
      from budget exhaustion (exit 5)
- [ ] The fix took the loop to exit 0, and you can point to the exact line that changed

> **Core rule:** Use context to reason. Use deterministic systems to establish bounds.

---

## STAGE 6 — REHYDRATE & PROVE
### Fresh session + proof · 8–10 min

### Objective

Prove the engineering state survives the conversation that created it.

### 6.1 — End the conversation

Open a completely fresh chat. Do not copy anything from before. Provide only:

- `.context/context-register.yaml` (update it first: mark the SEPA fact's `applies_to`
  work as done, if you're tracking that)
- `.workflow/HANDOFF.md`
- A fresh package: `./scripts/context-for.sh calculateFee-sepa`

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

### 6.3 — Compare baseline with engineered workflow

| Baseline (Stage 0) | Engineered (Stages 1–6) |
|---|---|
| repository repeatedly rediscovered | context map routes discovery |
| raw `mvn test` output enters the chat | deterministic digests enter the chat |
| the rate conflict is found by luck, if at all | the conflict is surfaced and gated on a human |
| every task inherits the whole conversation | task-specific packages |
| investigation and implementation blur together | role/context boundaries, enforced by missing tools |
| the boundary bug ships if nobody re-derives it | a fresh reviewer and a deterministic check both catch it |
| a bound is a request in an instructions file | a bound is a counter on disk, checked by a script |
| decisions die with the chat | the handoff and register survive it |

### Success Criteria — Stage 6

- [ ] Fresh session reconstructed the task correctly from artifacts alone
- [ ] No previous chat history was used
- [ ] Repository state (verify-change.sh, git log) matched the rehydrated summary
- [ ] You can state which pieces of context were deliberately preserved and which were
      allowed to disappear

> **Core rule:** If your engineering state dies when your chat dies, you have not
> engineered the context yet.

---

## Debrief

### The lifecycle

```text
DISCOVER → RETRIEVE → COMPRESS → PROMOTE → PACKAGE → ISOLATE → HANDOFF → CHALLENGE → BOUND → REHYDRATE
```

You do not need every step for every ticket. The standing question is:

> **At this point in the workflow, what context should exist, where should it live, who
> should receive it, and what should be enforced outside the model?**

### Seven Takeaways

| # | Technique | Rule |
|---|---|---|
| 1 | Context mapping | Discover where truth lives before loading source |
| 2 | Authority over recall | The compiler disproves a false-positive search for free; not every question has a compiler answer |
| 3 | Compute, don't paste | Reduce data before it reaches the model — 45 lines of raw output became a 6-line digest here |
| 4 | Context promotion | Persist verified facts and decisions; let temporary observations expire |
| 5 | Task packaging | Give each work unit the smallest sufficient context, filtered by tag, not re-summarized |
| 6 | Context isolation | Separate investigation, implementation, and evaluation — with a missing tool, not just an instruction |
| 7 | Deterministic bounds | A comment can state a rule correctly and the code can still violate it — verify behavior, not recall |

### Reflection

1. Where in your own work do you repeatedly rediscover the same context?
2. Which tool output could be reduced before it reaches Copilot?
3. Which facts from your current tickets deserve durable promotion?
4. Which task would benefit from a fresh-context reviewer?
5. What important rule on your team is currently only an instruction, but should be a
   deterministic bound?

Record your final reflection in `outputs/stage-readings.template.md`.

---

## Troubleshooting

See `docs/TROUBLESHOOTING.md` for the full appendix. Quick pointers:

| Symptom | Fix |
|---|---|
| Agents don't appear in the mode dropdown | Confirm you opened `lab-context-lifecycle/` itself as the VS Code workspace root, not a parent folder |
| `context-for.sh` says "nothing has been promoted yet" | Run Stage 3.1 first — copy the example register |
| `verify-change.sh` shows all four checks green before Stage 4 | Not expected — at clean baseline, `calculateFee(..., "SEPA")` returns `0`, which fails check 4 (`0 < 2.00`) by design. If you see all-green with no SEPA code, your working tree has drifted from baseline — run `git status` and `git log` |
| `jshell` not found | It ships with JDK 17+; check `java -version` and that `jshell` is on `PATH` |
| Stage 5.3's loop reaches thrashing (exit 4) on the very next check | Expected — running `loop.sh check` twice with no code change in between produces an identical verdict hash by design. Make the fix before the second run if you want to see exit 0 instead |

---

## What This Lab Did Not Cover

Deliberately out of scope, and worth knowing exists:

- **Mutation testing.** `scripts/mutation.sh` is ported into this lab for tooling parity
  and is available if you want it, but no stage here exercises it — verifying whether a
  test *suite* is thorough is a different lab's subject (see the companion
  `LAB_ACTION_GUIDE_UPDATED.md` at the parent repo root).
- **Multi-agent cost.** Delegating to isolated agents moves cost off your single-session
  meter; it does not make the work free. Use isolation where it buys correctness, not
  reflexively.
- **Instruction files as an attack surface.** You author `.github/agents/`,
  `.github/skills/`, and `AGENTS.md`; treat a diff to any of them as code and read it in
  review.

---

*Copyright 2026 Arula.AI (InRhythm Arula Labs). All Rights Reserved. | Internal - Confidential*
