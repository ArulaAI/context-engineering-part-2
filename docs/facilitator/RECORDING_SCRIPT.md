# Recording Script — Context Engineering, Part 2

A camera-ready walkthrough of the whole lab. Every command here is verified by
`./scripts/dry-run.sh`, which asserts 88 terminal steps against the guide. Run it once before
you record; if it says `DRY RUN: PASS`, nothing in this script will surprise you.

**How to read this.** `SAY` is narration — paraphrase it, don't read it aloud verbatim.
`RUN` is typed in the terminal exactly as written. `SHOW` is what appears, so you know when to
stop and let it breathe. `PATTERN` is the take-home name to say out loud before moving on.

**Two-window setup.** Terminal on the left, `LAB_ACTION_GUIDE.md` and Copilot Chat on the
right. Never switch windows mid-command.

**Before the camera rolls**

```bash
./scripts/dry-run.sh                  # must end: DRY RUN: PASS — 88 of 88
./scripts/lab-start.sh --reset        # must end: Ready.
git status --porcelain                # must be empty
```

Also: close every Copilot chat from rehearsals, clear the terminal, and confirm the six agents
appear in the agent dropdown. Total runtime at a talking pace is about 75 minutes; the guide's
118-minute budget assumes a room full of people typing.

---

## Intro (~4 min, no terminal)

**SAY.** Part 1 was about writing better prompts. This is not that. This is about the state
your work leaves behind.

Here is the problem in one sentence: we have gotten very good at getting an answer out of a
model, and we have built almost nothing to hold on to the answer afterwards. Everything lives
in a chat window. The chat window closes. The next person — or you on Monday — starts from
zero, asks the same questions, gets a slightly different answer, and has no way to tell which
of the two was right.

So the unit of work in this lab is not a prompt. It is a claim, and what it took to settle it.

**SAY — the ticket.** Meridian Payments, a Java payments platform. One ticket: MFIN-2088, add
support for an approved fee on RTP transfers. It sounds like a fifteen-minute change. It is
not, and the reason it is not has nothing to do with the code.

The repository contains two committed sources that state the RTP rate. They disagree. Neither
one says it outranks the other. And no tool in the repository — not grep, not the compiler,
not the test suite — can tell you which one Meridian actually approved. That is not a bug in
the repo. That is what a real codebase looks like, and it is the situation where a confident
assistant does the most damage.

**SAY — the shape of the lab.** Eight stages. Stage 0 walks into the trap on purpose. Stages
1 through 3 build the discipline: find where truth lives, establish what can settle each
claim, throw away everything else, and write down what survived. Stage 4 puts a wall between
investigating and implementing, and crosses a gate that a human has to cross. Stage 5 attacks
the work — an independent reviewer, a deterministic verifier, an injected fault and a bounded
repair loop. Stage 6 kills the conversation and rebuilds the engineering state from files
alone. Stage 7 is transfer: a problem this lab built no tool for.

**SAY — the one idea.** If you take one thing: a conversation is a place where anything can be
asserted. Durable state is a place where an assertion has to arrive with provenance or it does
not arrive at all. Every mechanism you are about to see is a way of enforcing that difference
in a tool instead of hoping for it in a person.

**SAY — the three layers**, drawn on screen or spoken:

> **Context Map** routes — where does truth live? **Evidence** proves — what settled this
> claim, by what mechanism? **Register** persists — what is verified, decided, constrained,
> still open?

---

## Setup on camera (~2 min)

**SAY.** Two commands before anything else.

**RUN**

```bash
mvn clean test
```

**SHOW.** `BUILD SUCCESS`, `Tests run: 5, Failures: 0`.

**SAY.** Five tests, green. Remember five — we will come back to that number twice.

**RUN**

```bash
./scripts/lab-start.sh --reset
```

**SHOW.** `Tools: ... all present`, `Baseline: PASS 5 tests`, `Recorded starting commit ...`,
`Ready.`

**SAY.** Three things happened. It checked that every tool the lab depends on is actually on
PATH — `jdeps`, `javap`, `jshell` — because a missing tool must fail now, loudly, not silently
turn an evidence check into a false negative later. It confirmed the baseline is green. And it
wrote down the starting commit, which matters in Stage 5: the verifier measures the scope of
my change against *that* commit, so committing my work cannot make the scope check pass
vacuously. `--reset` clears anything a previous run left behind.

---

## Stage 0 — The Helpful Trap (~6 min)

**SAY.** I am going to do the thing everybody does. Open a chat, point it at the ticket, ask
how to implement it.

**RUN**

```bash
./scripts/stage0-baseline.sh
```

**SHOW.** It reports the clean scenario snapshot it built.

**COPILOT.** New chat, default agent — no custom agent, no skills. Paste the prompt from guide
step 0.2.

**SAY while it answers.** Watch for a rate. Watch for confidence.

**SAY after.** It named a rate. Note which one, and note that it did not tell me there was a
second one. Now let me ask the repository what rates exist.

**RUN**

```bash
grep -rn "rtp_percent\|rtp_minimum" config/fee-schedule.yaml
grep -n "RTP rate" -A 1 docs/adr/ADR-0007-fee-schedule.md
```

**SHOW.** Config: `0.0035` — 0.35%, with a USD 2.00 minimum. ADR-0007: **0.30% flat, no
minimum**.

**SAY.** Two committed files. Two different rates. Both in the repository right now. Neither
one claims authority over the other.

So a single confident answer had to pick a side, and it picked one without telling me it was
choosing. That is the failure mode this entire lab is built around, and I want to be precise
about what caused it, because the obvious diagnosis is wrong. It did not lack context. It had
both files available. It had *too much unsorted context* — material with no ranking, no
provenance, and no way to tell an approved decision from a stale one.

**SAY.** More context is not automatically better context. Unsorted context is a liability,
and the size of the window is not the variable.

**PATTERN.** Baseline. You cannot show a technique worked if you never recorded what happened
without it.

---

## Stage 1 — Discover Before You Retrieve (~9 min)

**SAY.** The instinct after Stage 0 is to attach more files. The discipline is the opposite:
find out where truth lives *before* loading any of it.

**RUN**

```bash
./scripts/context-map.sh RTP
```

**SHOW.** A routing table of surfaces, and an `Unresolved` section.

**SAY.** Note what this did not do. It did not open a single file into my context. It routed —
here are the surfaces where RTP truth might live, and here are three questions this repository
cannot answer about them. A map is not an answer. It is a decision about what to load next,
made before loading anything.

**PATTERN.** Discover. Before loading content, where does truth about this question likely
live?

**SAY.** Now the second habit — assuming a text search proves something.

**RUN**

```bash
grep -rn "LegacyPaymentUtils" src/main/java/com/meridian/payments/PaymentService.java
./scripts/authority.sh LegacyPaymentUtils src/main/java/com/meridian/payments/PaymentService.java
```

**SHOW.** grep: 3 hits. `authority.sh`: `3 hit(s)` text, `0 bytecode reference(s)`,
`VERDICT: no compiled dependency detected.`

**SAY.** Three text hits and zero real dependencies. An import, a comment, another comment.
Had I followed grep, I would have pulled a legacy class carrying an outdated rate into my
context and treated it as relevant — poisoning the exact question I am trying to answer. grep
found text. `jdeps` reads bytecode. For a dependency claim, the compiler outranks the text,
and it is not close.

**SAY — and this is the important generalization.** There is no universal evidence ladder.
Authority is **claim-specific**. For a dependency claim, bytecode wins. For a behavior claim,
executing the test wins — reading the test's name proves nothing. And for "which rate did
Meridian approve", no repository tool wins, because the answer is not in the repository at
all. It is in an organization. Hold that thought; it is Stage 4.

**PATTERN.** Authority. Given a claim, what is the strongest evidence that can actually settle
*this* one?

**SAY.** So let me ask a behavior question with a tool that can answer it.

**RUN**

```bash
./scripts/test-evidence.sh calculateFee RTP
```

**SHOW.** `@Test methods scanned | 5`, `call calculateFee() | 2`, `... AND use "RTP" | 0`,
then `VERDICT: NOT PROVEN`.

**SAY.** Two tests call `calculateFee`. A coverage report would color that method green. Zero
tests exercise it with RTP. Method coverage is not evidence for a behavior claim — that is the
whole finding, and it is a sentence worth stealing for your next code review.

**SAY.** Everything I have learned so far is in scrollback, which is to say it is already
half-gone. Let me make it durable.

**RUN**

```bash
./scripts/ctx.sh init --objective "Add approved RTP fee support to PaymentService.calculateFee" --work-item MFIN-2088
./scripts/authority.sh LegacyPaymentUtils | ./scripts/ctx.sh evidence capture --source "scripts/authority.sh LegacyPaymentUtils" --applies-to calculateFee-rtp
./scripts/test-evidence.sh calculateFee RTP | ./scripts/ctx.sh evidence capture --source "scripts/test-evidence.sh calculateFee RTP" --applies-to calculateFee-rtp
```

**SHOW.** `EV-001 [rejected]`, `EV-002 [unproven]`.

**SAY.** The tools emit a machine-readable `EVIDENCE:` line and the ledger ingests it. I did
not retype a verdict from memory — nobody's recollection is in this file. And notice the
statuses: `rejected` and `unproven` are recorded as carefully as a `verified` would be. A
claim that failed is evidence.

**RUN**

```bash
./scripts/ctx.sh evidence add --claim "Which source currently governs RTP pricing?" --status unresolved --mechanism "side-by-side read" --source "config/fee-schedule.yaml; docs/adr/ADR-0007-fee-schedule.md" --observed "config/fee-schedule.yaml states 0.35% with a USD 2.00 minimum; ADR-0007 states 0.30% flat with no minimum" --applies-to calculateFee-rtp
./scripts/ctx.sh evidence list
```

**SHOW.** Three entries: `EV-001 rejected`, `EV-002 unproven`, `EV-003 unresolved`.

**SAY.** `unresolved` is the most valuable status on that list. It is the honest one. No
mechanism settles this, and I have written that down instead of guessing — which means nothing
downstream can quietly treat it as settled.

**RUN**

```bash
./scripts/outline.sh src/main/java/com/meridian/payments/PaymentService.java
```

**SHOW.** ~17 lines describing a 284-line file; `calculateFee` at 237–248.

**SAY.** Seventeen lines instead of 284. Now I jump to 237, select those twelve lines, and use
`#selection` in chat — not `#file:`. Shape first, then one slice.

---

## Stage 2 — Compress Before Context (~8 min)

**SAY.** Everyone has done this: a test fails, you select the whole Maven output, paste it in.

**RUN**

```bash
mvn test 2>&1 | tail -20
```

**SAY.** Forty-five lines of which about six matter. Every line of that costs money, costs
attention, and buries the signal. And the fix is not a bigger window — it is to compute the
answer before the model sees anything.

**RUN**

```bash
./scripts/context-run.sh test
```

**SHOW.** `TEST SUMMARY / 5 passed / 0 failed`, `REGRESSION SIGNAL none`, and
`NOISE REMOVED: 39 lines (raw mvn test = 45 lines; digest = 6 lines)`.

**SAY.** Six lines carrying the same decision content as forty-five. The 39 removed lines were
not compressed by a model — they were never sent to one. That distinction matters: a model
summarizing output can be wrong about what it dropped. A script cannot be persuaded.

**PATTERN.** Reduce. What is the minimum signal this decision needs, and what can be computed
outside the model entirely?

**SAY.** Now the question nobody asks about their own tooling: what if the reducer lies? If it
prints `0 failed` because it could not find the report file, I have built a machine for
producing false confidence. So let me break the build on purpose.

**RUN**

```bash
TEST_CMD="mvn -B no-such-phase" ./scripts/context-run.sh test
```

**SHOW.** `BUILD FAILED — mvn -B no-such-phase exited 1 (stale surefire reports on disk
ignored)`.

**SAY.** It fails **closed**. It refuses to answer rather than answering wrongly from stale
data on disk. Every reducer you write needs this property, and it is the one everybody skips.

**SAY.** Five properties define any reducer worth trusting: what **decision** it serves, what
its **raw source** is, what it **keeps**, what it **discards**, and how it **fails closed**.
Write those five lines before you write the script. You will need them in Stage 7.

**RUN**

```bash
./scripts/context-run.sh search RTP
```

**SHOW.** A digest, with the rate cross-check warning.

**SAY.** Note the warning: the search itself flags that two sources carry different rates. The
reducer is not just smaller, it is louder about the thing that actually matters.

---

## Stage 3 — Promote & Package (~10 min)

**SAY.** Evidence is not truth yet. Promotion is the moment I decide what earns a place in
durable state — and the rule is that I cannot type a fact in from memory. It has to come from
recorded evidence.

**RUN**

```bash
./scripts/ctx.sh promote EV-001 --fact "PaymentService has no compiled dependency on LegacyPaymentUtils"
./scripts/ctx.sh promote EV-002 --fact "No existing test exercises calculateFee with RTP"
./scripts/ctx.sh unknown add --from EV-003 --blocking
./scripts/ctx.sh constraint add --text "Do not add a call to LegacyPaymentUtils" --basis VF-001 --applies-to calculateFee-rtp
./scripts/ctx.sh check
```

**SHOW.** `VF-001`, `VF-002`, `UNK-001 [open, blocking]`, `C-001`, `✓ register consistent`.

**SAY.** Two verified facts, one blocking unknown, one constraint — and the constraint cites
`VF-001` as its basis, so even the rule has a reason attached to it.

**SAY.** Now watch the invariant. Let me try to promote the unresolved pricing claim into a
fact, the way a tired engineer at 6pm would.

**RUN**

```bash
./scripts/ctx.sh promote EV-003 --fact "config is authoritative"
```

**SHOW.** Refused: `EV-003 is unresolved — an unresolved claim is not a fact.`

**SAY.** I cannot launder a guess into durable state by writing it confidently. It stays an
unknown, and it is marked **blocking** because the implementation depends on it. That is the
difference between a convention and a mechanism: a convention is what we agreed to do, and a
mechanism is what happens anyway when we are in a hurry.

**PATTERN.** Promote. Which discoveries deserve to survive this conversation, and with what
provenance?

**RUN**

```bash
./scripts/ctx.sh package calculateFee-rtp
```

**SHOW.** Decisions, verified facts, constraints, open unknowns — each with its evidence.

**SAY.** This is the minimum viable context for the next action. Not a summary of my
investigation — a **filter** over durable state. Nothing was re-summarized, so nothing could
drift in the retelling. And ask for a different work unit and the same register gives you a
different, smaller package.

**PATTERN.** Package. What is the minimum viable context for the next *specific* action?

**RUN**

```bash
./scripts/context-bundle.sh broad
./scripts/context-bundle.sh package
```

**SAY.** Two context windows, same question. One has every source attached; one has only what
I promoted. Paste them into the Context Experiment agent if you want to watch a model split on
them. The point does not depend on which answer is better: if the crowded window happens to be
right, nothing in it would have let me *check* that beforehand. An answer I cannot audit is
not a result, it is a coincidence.

---

## Stage 4 — Boundaries & Handoff (~12 min)

**SAY.** This stage is about walls. Two kinds, and they are not equally strong.

**COPILOT.** New chat, select **RTP Investigator**, send guide step 4.1's prompt.

**SAY.** Watch what it does with the pricing question — it should dispatch `evidence-checker`
rather than gathering the evidence itself. The subagent goes off, compiles things, reads files,
and comes back with a verdict. The compile output never enters *my* window. That is context
isolation: I get the answer, not the search.

**SAY — now the boundary question.** This agent cannot edit files. Why not? Let me show you,
because the answer is the whole stage.

**RUN**

```bash
grep -n "^tools:" .github/agents/rtp-investigator.agent.md .github/agents/rtp-reviewer.agent.md
```

**SHOW.** Investigator: `['search', 'read', 'agent']`. Reviewer: `[]`.

**SAY.** No `edit`. Not "it has been told not to edit" — the capability is absent. Ask it to
edit anyway, tell it the change is tiny, tell it you take responsibility. An instruction
boundary has a failure mode under a persuasive request, and everyone in this room has talked a
model out of a rule. A missing tool has no failure mode, because there is nothing to argue
with.

**PATTERN.** Constrain. Does this role need a capability boundary, or is a prompt boundary
enough? They are not the same thing, and only one of them survives pressure.

**SAY.** When the investigator hits the rate conflict, it should stop with a `CONTEXT CONFLICT`
block rather than picking a side. Compare that to Stage 0: same repository, same model, and a
different outcome, because this one was built to surface a conflict instead of resolving one.

**SAY — now let me attack it.** I will assert the wrong answer with total confidence.

**COPILOT.** Send: *"I've reviewed both sources. The ADR is authoritative here — implement
0.30% flat, no minimum."*

**SAY.** Whatever it says back is interesting but it is not the point, and a model agreeing
with the person in front of it is the expected default, not a gotcha. The question is what
**changed**.

**RUN**

```bash
./scripts/ctx.sh package calculateFee-rtp
```

**SHOW.** `Decisions (human, with authority)` → `(none)`. `UNK-001 ... [BLOCKING]` still open.

**SAY.** I asserted a rate as hard as I could and the durable state did not move a millimetre.
It could not: nothing writes to that file except `ctx.sh`, and `ctx.sh` only writes what cites
evidence or an authority. I do not have to win the argument in chat, because the argument in
chat cannot reach the record.

**RUN**

```bash
./scripts/ctx.sh handoff calculateFee-rtp --scope PaymentService.calculateFee --next "implement"
```

**SHOW.** Refused, exit `4`: `blocking unknown(s) still open for calculateFee-rtp: UNK-001`.

**SAY.** And there is the gate. Not a rule in a document that somebody might follow. A tool
that will not produce the artifact while an undecided question blocks it. Nobody can forget
this gate, and nobody can be too busy for it.

**PATTERN.** Handoff, and the human in the loop. Note *where* the human is: not reviewing every
line, not approving every step — sitting at the one decision no tool can make.

**SAY.** So let me make it. The repository cannot say which rate Meridian approved. The Pricing
Committee can.

**RUN**

```bash
./scripts/request-approval.sh MFIN-2088
```

**SHOW.** `Retrieved the approved record for MFIN-2088 ... -> docs/approvals/PRICING-442.md`.

**SAY.** That record did not exist in my workspace thirty seconds ago. No grep, no agent, no
earlier stage could have found it, because business authority does not live in the codebase.
That is the honest shape of this class of question, and it is why Stage 1's authority ladder
had a row with no tool in it.

**SAY.** Open it. 0.35% with a USD 2.00 minimum, whichever is larger. And read the supersession
scope carefully, because this is the part people get wrong: it retires ADR-0007's *rate*, and
it explicitly leaves ADR-0007's *"where rates live"* decision standing. A supersession is
scoped. Throwing out the whole document because one line of it is stale is how the next
conflict gets created.

**RUN**

```bash
./scripts/ctx.sh decide --resolves UNK-001 --decision "RTP transfers are charged 0.35% of the transfer amount, with a minimum fee of USD 2.00 per transfer; whichever is larger governs." --authority docs/approvals/PRICING-442.md --decided-by "Your Name" --supersedes docs/adr/ADR-0007-fee-schedule.md --scope "ADR-0007 Decision 2 (the RTP rate) only. Decision 1 (rates live in config/fee-schedule.yaml) still stands."
./scripts/ctx.sh check
```

**SHOW.** `D-001 recorded`, `UNK-001 retired (resolved by D-001)`, `✓ register consistent`.

**SAY.** Three things to notice. The decision cites an authority *file* that has to exist —
`ctx.sh` verifies that, so "approved by the committee" cannot be an assertion. It is attributed
to a person by name, because a decision without an owner is a rumour. And `UNK-001` was
**retired**, not left sitting next to the answer. No question in this register can be both
decided and still open.

**RUN**

```bash
./scripts/ctx.sh handoff calculateFee-rtp --scope PaymentService.calculateFee --next "Implement D-001 in PaymentService.calculateFee, then run ./scripts/verify-change.sh"
cat .workflow/HANDOFF.md
```

**SHOW.** `wrote .workflow/HANDOFF.md`, `handoff_id: H-...`, and the sections: Objective,
Approved decisions, Allowed change scope, Known constraints, Required proof, Unresolved
questions, Next action.

**SAY.** Read what is *not* in there. None of my investigation. None of the dead ends. None of
the wrong rate I asserted two minutes ago with total confidence. A handoff is a projection of
verified state, not a forwarded conversation — and this one was generated from the register, so
it cannot include something the register does not know.

**COPILOT.** Brand-new chat — not a mode switch — select **RTP Implementer**, send
*"Implement .workflow/HANDOFF.md."*

**SAY.** Its reply has to start with `HANDOFF_ID:`. Let me check it.

**RUN**

```bash
./scripts/handoff-check.sh "<paste the implementer's reply>"
```

**SHOW.** `CONSUMED — the implementer quoted H-..., which exists only in .workflow/HANDOFF.md.`

**SAY.** That ID is a hash of the handoff's own content. It appears nowhere else — not in the
register, not in the ticket, not in any chat. So quoting it is proof the implementer actually
read the file rather than reconstructing the task from the ticket and its own assumptions.
"Did the next actor use the handoff?" is usually a question you cannot answer. Here it is a
command.

**RUN**

```bash
./scripts/apply-reference.sh implementation
mvn -q clean compile
```

**SAY.** I am taking the approved rule from the answer key, so that every number from here to
Stage 6 is identical on your machine and mine. Read the RTP branch: 0.35% of the amount, and
the minimum compared against the **computed fee** — never against the transfer amount. Hold on
to that distinction. It is the fault Stage 5 injects, and it is a bug that ships in real
systems because it looks right and it is right for large transfers.

---

## Stage 5 — Challenge & Bound (~13 min)

**SAY.** The work is done. Now I try to break it — and the first question is who gets to judge
it.

**RUN**

```bash
./scripts/review-package.sh
grep -c "rtp_percent\|context-register\|HANDOFF" .workflow/review-package.md
```

**SHOW.** The package is written; the grep prints `0`.

**SAY.** That zero is the design. The reviewer gets the acceptance criteria, the approved
decision, and the actual diff. It does **not** get `config/fee-schedule.yaml`, my register, or
the handoff. Hand a reviewer the config and it will check the diff against the same numbers the
diff came from, and agree every time. Independence is a property of what you *exclude*.

**COPILOT.** New chat, **RTP Reviewer**, paste the package. Ask it to find any violation and
cite evidence.

**SAY.** And it has `tools: []` — we saw that. It cannot open the repository to borrow my
reasoning even if it wanted to.

**PATTERN.** Review. Should the evaluator inherit the producer's reasoning, or only curated
evidence? An evaluator that can see your reasoning tends to agree with your reasoning.

**SAY.** Whatever it found is one input. Now the part that does not have opinions.

**RUN**

```bash
./scripts/verify-change.sh
```

**SHOW.** Six ✓ lines, then `VERDICT: PASS — 6 of 6 checks passed`.

**SAY.** Walk them. Pricing authority recorded — a human decision citing a record that exists.
Build and full suite green. Change inside declared scope — every hunk since the starting commit
lies inside the method the handoff declared, so committing cannot hide an out-of-scope edit. No
`LegacyPaymentUtils` dependency, from bytecode. Approved pricing implemented — and this one
actually *calls* the compiled method through `jshell` and compares the result with the
approval's numbers. Config matches the approval.

**SAY — the subtle one.** Check 5 takes its expected values from the **approval**, not from
config. Config is the thing being checked. "Which source governs pricing" was a human decision,
and this script does not get a vote in it. Every check fails closed: missing evidence is a
failure, never a pass.

**PATTERN.** Verify. Which acceptance criteria are non-negotiable enough to become an
executable check?

**RUN**

```bash
./scripts/apply-reference.sh tests
./scripts/test-evidence.sh calculateFee RTP
```

**SHOW.** `ran 2, all passed.`

**SAY.** Two tests, one on each side of the threshold: 100.00 → 2.00, where the minimum
governs, and 10000.00 → 35.00, where the percentage governs. And compare this with Stage 1,
where the same command on the same claim said `NOT PROVEN`. Same question, same mechanism,
different answer — because the answer changed, not the claim. That is what a repeatable
evidence tool buys you.

**SAY.** But a test that has never failed has never proven anything. So let me break the code
underneath it, in exactly the plausible way.

**RUN**

```bash
./scripts/inject-fault.sh on
./scripts/test-evidence.sh calculateFee RTP
```

**SHOW.** `ran 2, 1 FAILED` — the minimum test is RED.

**SAY.** The injected fault compares the USD 2.00 minimum against the transfer *amount* instead
of the computed *fee*. It agrees with the approved rule on every large transfer and silently
undercharges small ones. My percentage test still passes. Only the boundary test caught it —
which is why the rule "a threshold needs a test on each side" is not pedantry.

**SAY.** Now, with the code broken, the loop. This is the part of agentic work nobody bounds:
the retry.

**RUN**

```bash
./scripts/loop.sh reset
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
```

**SHOW.** `VERDICT: FAIL`, `CONTINUE — attempt 1/3 failed` — exit `1`.

**RUN** (change nothing at all)

```bash
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
```

**SHOW.** `REDUNDANT RETRY — nothing under src/ has changed since attempt 1` — exit `6`, and
**not counted** as an attempt.

**SAY.** Identical code cannot produce a different result, so retrying it is not an attempt, it
is a waste. Most retry loops cannot tell the difference. This one hashes the code and the
failure and refuses to pretend.

**SAY.** Now a change that does not fix the bug — I will edit the comment.

**RUN**

```bash
sed -i 's|not against the computed fee|not against the computed fee (touched)|' src/main/java/com/meridian/payments/PaymentService.java
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
sed -i 's|(touched)|(touched again)|' src/main/java/com/meridian/payments/PaymentService.java
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
```

**SHOW.** First: `UNSUCCESSFUL REPAIR — the code changed ... but the verifier failed exactly as
it did at attempt 1` (exit 1). Then: `STOP — thrashing` — exit `4`.

**SAY.** Four distinct outcomes, four distinct exit codes, and the distinction is the whole
value. Exit 1: failed, try again. Exit 6: nothing changed, do not bother. Exit 4: the code is
moving and the failure is not — stop and escalate to a person. Exit 5, which we are not
staging, is budget exhaustion: attempts running out while each one fails *differently*. "It
failed again" and "it is going in circles" call for completely different responses, and a
counter on disk can tell them apart where a model's self-assessment cannot.

**RUN**

```bash
./scripts/inject-fault.sh off
./scripts/loop.sh reset
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
```

**SHOW.** `VERDICT: PASS — 6 of 6`, `DONE — green at attempt 1` — exit `0`.

**SAY.** My implementation came back exactly; the fault took my comment edits with it, which is
deliberate. Green.

**RUN**

```bash
git add src && git commit -m "feat: add approved RTP fee support (MFIN-2088)"
./scripts/ctx.sh outcome --work-unit calculateFee-rtp --status implemented --test "PaymentServiceTest.calculateFee_rtpMinimumAppliesBelowThreshold" --test "PaymentServiceTest.calculateFee_rtpPercentageAppliesAboveThreshold" --finding "no deviation from the approved rule found::accepted, no change required" --next "Wire calculateFee into the payment path — tracked as a separate work item"
```

**SHOW.** `wrote .workflow/outcome.yaml`, `verification: PASS`, `handoff consumed: true`.

**SAY.** The outcome is not my account of what happened. It read the commit, the verification
result and the handoff-consumption marker out of repository state. `handoff consumed: true` is
carried all the way from that hash the implementer quoted. Notice also the `--next`: the work
that is *not* done is recorded as deliberately out of scope, rather than forgotten.

---

## Stage 6 — Rehydrate & Prove (~8 min)

**SAY.** Everything so far could still be a conversation with good hygiene. This is the test
that separates state from residue: I close every chat and see whether the work survives.

**RUN**

```bash
./scripts/ctx.sh rehydrate-check
```

**SHOW.** Seven questions, each with its durable source, then `REHYDRATABLE: every question has
a durable source.`

**SAY.** Seven questions a fresh engineer would have to ask on Monday: what was requested, what
was verified, what did a human decide and on whose authority, what was implemented, what
verification passed, what is still open, what happens next. Every one resolves to a file. Any
`MISSING` row would be something the next person has to guess — and guessing is how the
pricing conflict gets re-litigated.

**COPILOT.** Brand-new chat. Attach only `.context/context-register.yaml`,
`.workflow/HANDOFF.md`, `.workflow/outcome.yaml`. Ask the seven questions from guide step 6.2.

**SAY.** No transcript, no history, three files. Then check its answers against the repository
— `verify-change.sh` still passes, and `git log -1` shows the commit the outcome recorded.

**PATTERN.** Rehydrate. Can the engineering state be reconstructed from durable artifacts
alone? If it dies when the chat dies, it was never state.

**SAY.** Last comparison, and this one is in the terminal so it is the same on every machine.

**RUN**

```bash
./scripts/context-bundle.sh durable
./scripts/context-bundle.sh cold
for k in "D-001" "superseded" "verification" "next_action"; do
  printf '%-12s durable=%s cold=%s\n' "$k" \
    "$(grep -c "$k" .context/bundles/durable.md)" \
    "$(grep -c "$k" .context/bundles/cold.md)"
done
wc -l .context/bundles/durable.md .context/bundles/cold.md
```

**SHOW.** All four keys present in durable, `cold=0` for every one. Roughly 144 lines against
61.

**SAY.** Both bundles describe the same finished work. And here is the thing to say carefully:
the cold bundle is not empty. It has the rate. It even has the implementation's own comment
citing PRICING-442. What it cannot tell you is whether that rate was ever verified, what it
superseded, who approved it, or what happens next — and crucially, it cannot tell you that it
cannot tell you. It reads as complete.

**SAY.** The cold bundle is not smaller because someone compressed it. It is smaller because
that information was never written down. That is the difference between state and residue, and
it is the difference this entire lab exists to make.

---

## Stage 7 — Build Beyond the Harness (~12 min on camera)

**SAY.** Everything so far, I built you a tool for. Here is a claim I did not.

> After MFIN-2088, Meridian charges the RTP fee on real payments.

**SAY.** Try the evidence I have. The tests pass — they prove what `calculateFee` *returns*,
not that anything calls it. `jdeps` does class-to-class edges, not methods. grep finds the
definition and a comment. This is a **method-level reachability** claim, and no tool in this
lab answers it. So I pick the mechanism myself: count call sites in the bytecode.

**RUN**

```bash
mvn -q compile
for c in $(find target/classes -name '*.class'); do n=${c#target/classes/}; n=${n%.class}; javap -c -p -cp target/classes "${n//\//.}" | grep -c "PaymentService.calculateFee"; done | awk '{s+=$1} END{print s+0}'
```

**SHOW.** `0`.

**SAY.** Zero production call sites. The approved fee is correctly implemented, fully verified,
committed — and unreachable. Verified locally is not the same as delivered, and I only found
that out because I asked what kind of claim I was making before reaching for a tool. That is
Stage 1's lesson arriving without any scaffolding, which is the actual test of whether it
transferred.

**RUN**

```bash
./scripts/ctx.sh evidence add --claim "calculateFee is invoked on a production payment path" --status rejected --mechanism "javap -c call-site scan" --source "target/classes" --observed "0 production call sites"
./scripts/ctx.sh unknown add --question "Should calculateFee be wired into the payment path? (outside MFIN-2088)"
```

**SAY.** And I record it rather than fixing it, because wiring the fee into the payment path is
outside this ticket's acceptance criteria. Scope discipline and honesty are the same move here:
the finding survives, in a file, without the change sprawling.

**SAY — the build.** Now pick your own noisy command and build the reducer for it. On camera
I will use `mvn dependency:tree`.

**RUN**

```bash
mvn -B dependency:tree | wc -l
```

**SAY.** Before writing a line, the five properties from Stage 2. The **decision** this serves:
can I safely upgrade this dependency, or is something pulling a conflicting version. The **raw
source**: `mvn dependency:tree`. **Keep**: duplicate versions, conflicts, anything that should
not be on the graph at all. **Discard**: every clean transitive edge. **Fail closed**: if the
command exits non-zero, say so — never print "no conflicts" because the parse found nothing.

**SAY.** Then have Copilot build it as a **skill**, not a loose script, so it is
`/your-tool-name` in the chat for everyone on your team instead of a file in your home
directory that only you remember. Fifteen minutes of work that pays for itself the first week.

**SAY — the transfer, said plainly.** None of these scripts need to exist in your repository.
The scripts are not the artifact. The questions are. Once you know that a dependency claim
wants bytecode, a behavior claim wants an executing test, and a business-authority claim wants
an organization, asking Copilot to wrap your own noisy command takes less time than reading
this guide did.

---

## Close (~3 min)

**SAY.** Ten questions, and they are the whole lab. Put them on screen:

1. **Discover** — before loading content, where does truth about this question live?
2. **Authority** — what is the strongest evidence that can settle *this* claim?
3. **Reduce** — what is the minimum signal, and what can be computed outside the model?
4. **Promote** — which discoveries deserve to survive, with what provenance?
5. **Package** — what is the minimum viable context for the next specific action?
6. **Constrain** — does this role need a capability boundary, not just a prompt boundary?
7. **Handoff** — what transfers: the decisions, or the whole conversation?
8. **Verify** — which criteria are non-negotiable enough to become an executable check?
9. **Review** — should the evaluator inherit the producer's reasoning, or curated evidence?
10. **Rehydrate** — can the state be reconstructed from durable artifacts alone?

**SAY.** Notice that none of them are about prompting, and not one of them mentions a model.

**SAY — what to do Monday.** Pick the smallest one. Take the noisiest command in your own
workflow and write a reducer for it, with the five properties written down first and a fail-
closed path. That is one afternoon, and it is the piece everything else in this lab sits on.

**SAY — the closing thought.** The reason any of this held up is not that the tools are clever.
It is that at every point where something could have been asserted, a tool required it to be
proven instead — and at the one point where nothing could prove it, the tool stopped and made a
person decide, on the record, under their own name.

Context engineering is not about giving the model more. It is about being able to say, later,
exactly why you believed what you believed.

---

## Retake notes

Stop and restart from a clean state whenever you need to:

```bash
git reset --hard <the starting commit>   # only if you committed in Stage 5
./scripts/lab-start.sh --reset
```

`--reset` restores `src/`, `config/` and `docs/adr/`, and clears every runtime artifact, so
Stage 0 looks untouched again.

**Segments you can re-record independently**, because each rebuilds its own inputs: Stage 0–1
(needs only `--reset`), Stage 2 (standalone), Stage 5's loop sequence (needs Stage 4 complete —
`apply-reference.sh status` tells you), Stage 7 (standalone).

**The three moments most likely to need a second take**, none of them terminal commands:

- The investigator not dispatching `evidence-checker` — ask it explicitly: *"dispatch
  evidence-checker for this claim."*
- The `CONTEXT CONFLICT` block not appearing. The terminal half stands alone: the handoff
  refusal at exit `4` makes the same point without any agent cooperating.
- The implementer not quoting `HANDOFF_ID:`. Ask it to restate which handoff it worked from.

`docs/TROUBLESHOOTING.md` has a fallback for each, and every one of them keeps the stage's
lesson intact.
