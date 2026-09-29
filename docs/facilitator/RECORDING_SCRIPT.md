# Recording Script — Context Engineering, Part 2

The full narration for a recorded walkthrough of the lab. Every command in this document is
verified by `./scripts/dry-run.sh`, which asserts 88 terminal steps against the guide. Run it
once before recording. If it reports `DRY RUN: PASS`, nothing in this script will behave
unexpectedly.

**How to read this.** `SAY` is narration. Deliver it in your own words rather than reading it
verbatim. `RUN` is entered in the terminal exactly as written. `SHOW` is the output to expect,
so you know when to pause and let the result register. `PATTERN` is the take-home principle to
state before moving on.

**Two-window setup.** Terminal on the left, `LAB_ACTION_GUIDE.md` and Copilot Chat on the
right. Do not switch windows mid-command.

**Before recording**

```bash
./scripts/dry-run.sh                  # must end: DRY RUN: PASS — 88 of 88
./scripts/lab-start.sh --reset        # must end: Ready.
git status --porcelain                # must be empty
```

Also close every Copilot session left open from rehearsal, clear the terminal, and confirm all
six agents appear in the agent dropdown.

**Timing.** The recording path runs approximately 57 minutes. `RUN_SHEET.md` carries the
per-stage clock and identifies the three `FULL ONLY` segments it omits. This script contains
the complete narration, including those segments, so skip past them if you are recording the
shorter path. The lab's own 118-minute budget assumes a room of participants working through
it directly.

---

## Intro (~4 min, no terminal)

**SAY.** Part 1 addressed prompt construction. Part 2 addresses a different problem: the
engineering state that remains once the conversation has ended.

The problem stated directly. We have become effective at obtaining an answer from a model. We
have invested considerably less in retaining that answer afterwards. The reasoning lives in a
chat session, the session closes, and the next engineer begins again, asks comparable
questions, receives a slightly different answer, and has no basis for determining which of the
two was correct.

The unit of work in this session is therefore not a prompt. It is a claim, and the evidence
required to settle it.

**SAY — the work item.** Meridian Payments is a Java payments platform. The work item is
MFIN-2088: add support for an approved fee on RTP transfers. The change appears
straightforward. It is not, and the reason has nothing to do with the code.

The repository contains two committed sources that state the RTP rate. They disagree. Neither
declares precedence over the other. No tool in the repository can establish which rate the
organization approved. This is not an artificial condition constructed for the exercise. It is
what a mature codebase looks like, and it is precisely the situation in which a confident
assistant does the most damage.

**SAY — the structure.** Eight stages. Stage 0 establishes the baseline failure deliberately.
Stages 1 through 3 build the discipline: establish where authority resides, determine what can
settle each claim, discard the remainder, and record what survives. Stage 4 separates
investigation from implementation and introduces a decision that requires a person. Stage 5
challenges the work through an independent review, a deterministic verifier, an injected defect
and a bounded repair loop. Stage 6 closes the conversation and reconstructs the engineering
state from files alone. Stage 7 tests transfer against a problem for which this lab provides no
tool.

**SAY — the governing principle.** If you retain one point from this session: a conversation is
an environment in which any claim can be asserted. Durable state is an environment in which a
claim must arrive with provenance or not at all. Every mechanism demonstrated here enforces that
distinction in tooling rather than relying on individual discipline.

**SAY — the three layers**, shown on screen or stated:

> **Context Map** routes: where does authority for this question reside? **Evidence** proves:
> what settled this claim, and by what mechanism? **Register** persists: what is verified,
> decided, constrained, and still open?

---

## Setup on camera (~2 min)

**SAY.** Two commands precede everything else.

**RUN**

```bash
mvn clean test
```

**SHOW.** `BUILD SUCCESS`, `Tests run: 5, Failures: 0`.

**SAY.** Five tests, passing. Note the count. It becomes relevant twice more.

**RUN**

```bash
./scripts/lab-start.sh --reset
```

**SHOW.** `Tools: ... all present`, `Baseline: PASS 5 tests`, `Recorded starting commit ...`,
`Ready.`

**SAY.** Three things occurred. The script confirmed that every tool this lab depends on
resolves on PATH, including `jdeps`, `javap` and `jshell`. A missing tool must fail immediately
and visibly rather than silently degrading an evidence check later in the session. It confirmed
the baseline test suite is green. And it recorded the starting commit, which matters in Stage 5:
the verifier measures the scope of our change against that commit rather than against HEAD, so
committing the work cannot cause the scope check to pass vacuously. The `--reset` flag clears
state left by any previous run.

---

## Stage 0 — The Helpful Trap (~6 min)

**SAY.** We begin with the conventional approach. Open a chat session, provide the work item,
and ask how to implement it.

**RUN**

```bash
./scripts/stage0-baseline.sh
```

**SHOW.** It reports the clean scenario snapshot it built.

**COPILOT.** In the new window: new chat, default agent, no custom agent and no skills. Paste
verbatim:

> Review MFIN-2088 using the engineering evidence in this workspace.
>
> Tell me:
> - where you would implement the RTP change,
> - what fee behavior should apply,
> - and how you would approach the implementation.
>
> Do not modify files.

**SAY while it answers.** Two things to observe in the response: the rate it specifies, and the
confidence with which it specifies it.

**SAY after.** It named a rate. Note which one, and note that it did not indicate a second rate
exists. We now ask the repository which rates are present.

**RUN**

```bash
grep -rn "rtp_percent\|rtp_minimum" config/fee-schedule.yaml
grep -n "RTP rate" -A 1 docs/adr/ADR-0007-fee-schedule.md
```

**SHOW.** Config: `0.0035`, which is 0.35%, with a USD 2.00 minimum. ADR-0007: **0.30% flat, no
minimum**.

**SAY.** Two committed files, two different rates, both present in the repository, and neither
claiming authority over the other.

A single confident answer therefore required selecting one of them, and that selection was made
without disclosure. This is the failure mode the remainder of the session addresses. The
diagnosis matters here, because the intuitive one is incorrect. The model did not lack context.
Both files were available to it. What it had was an excess of unranked context: material with no
provenance, and no means of distinguishing an approved decision from a superseded one.

**SAY.** More context is not automatically better context. Unsorted context is a liability, and
window size is not the governing variable.

**PATTERN.** Baseline. A technique cannot be shown to have worked unless the result without it
was recorded.

---

## Stage 1 — Discover Before You Retrieve (~9 min)

**SAY.** The instinct after Stage 0 is to attach more files. The discipline is the opposite:
establish where authority resides before loading any of it.

**RUN**

```bash
./scripts/context-map.sh RTP
```

**SHOW.** A routing table of surfaces, and an `Unresolved` section.

**SAY.** Note what did not happen. No file was opened into context. The command produced
routing: the surfaces where RTP information resides, and three questions this repository cannot
resolve. A map is not an answer. It is a decision about what to load next, made before anything
has been loaded.

**PATTERN.** Discover. Before loading content, where does authority for this question reside?

**SAY.** Next, a common assumption: that a text search demonstrates a dependency.

**RUN**

```bash
grep -rn "LegacyPaymentUtils" src/main/java/com/meridian/payments/PaymentService.java
./scripts/authority.sh LegacyPaymentUtils src/main/java/com/meridian/payments/PaymentService.java
```

**SHOW.** grep: 3 hits. `authority.sh`: `3 hit(s)` text, `0 bytecode reference(s)`,
`VERDICT: no compiled dependency detected.`

**SAY.** Three textual matches and no compiled dependency. An import statement and two comments.
Following the text search would have introduced a legacy class carrying a superseded rate into
context and treated it as relevant, compromising the exact question under investigation. The
text search located text. `jdeps` reads bytecode. For a dependency claim, the compiler is the
authoritative source.

**SAY — the generalization.** There is no universal evidence hierarchy. Authority is
**claim-specific**. A dependency claim is settled by bytecode. A behavior claim is settled by
executing the test, not by reading its name. And the question of which rate the organization
approved is settled by no repository tool at all, because the answer does not reside in the
repository. It resides in an organization. We return to this in Stage 4.

**PATTERN.** Authority. For a given claim, what is the strongest evidence that can actually
settle *this* one?

**SAY.** We now put a behavior question to a tool capable of answering it.

**RUN**

```bash
./scripts/test-evidence.sh calculateFee RTP
```

**SHOW.** `@Test methods scanned | 5`, `call calculateFee() | 2`, `... AND use "RTP" | 0`,
then `VERDICT: NOT PROVEN`.

**SAY.** Two tests invoke `calculateFee`. A coverage report would mark that method as covered.
No test exercises it with RTP. Method coverage is not evidence for a behavior claim.

**SAY.** Everything established so far exists only in terminal scrollback. We make it durable.

**RUN**

```bash
./scripts/ctx.sh init --objective "Add approved RTP fee support to PaymentService.calculateFee" --work-item MFIN-2088
./scripts/authority.sh LegacyPaymentUtils | ./scripts/ctx.sh evidence capture --source "scripts/authority.sh LegacyPaymentUtils" --applies-to calculateFee-rtp
./scripts/test-evidence.sh calculateFee RTP | ./scripts/ctx.sh evidence capture --source "scripts/test-evidence.sh calculateFee RTP" --applies-to calculateFee-rtp
```

**SHOW.** `EV-001 [rejected]`, `EV-002 [unproven]`.

**SAY.** The tools emit a machine-readable `EVIDENCE:` line, which the ledger ingests directly.
No verdict was retyped from memory, so no one's recollection is in this file. Note the statuses
as well: `rejected` and `unproven` are recorded with the same rigor as `verified`. A claim that
failed to hold is still evidence.

**RUN**

```bash
./scripts/ctx.sh evidence add --claim "Which source currently governs RTP pricing?" --status unresolved --mechanism "side-by-side read" --source "config/fee-schedule.yaml; docs/adr/ADR-0007-fee-schedule.md" --observed "config/fee-schedule.yaml states 0.35% with a USD 2.00 minimum; ADR-0007 states 0.30% flat with no minimum" --applies-to calculateFee-rtp
./scripts/ctx.sh evidence list
```

**SHOW.** Three entries: `EV-001 rejected`, `EV-002 unproven`, `EV-003 unresolved`.

**SAY.** `unresolved` is the most significant status in that list. No mechanism settles the
pricing question, and that has been recorded rather than estimated, which prevents anything
downstream from treating it as settled.

**RUN**

```bash
./scripts/outline.sh src/main/java/com/meridian/payments/PaymentService.java
```

**SHOW.** ~17 lines describing a 284-line file; `calculateFee` at 237–248.

**SAY.** Seventeen lines in place of 284. We then navigate to line 237, select the twelve lines
of the method, and reference them with `#selection` rather than `#file:`. Structure first, then
a single slice.

---

## Stage 2 — Compress Before Context (~8 min)

**SAY.** A familiar pattern: a test fails, and the entire Maven output is selected and pasted
into the conversation.

**RUN**

```bash
mvn test 2>&1 | tail -20
```

**SAY.** Forty-five lines, of which approximately six carry decision content. Each line consumes
budget and attention, and obscures the signal. The remedy is not a larger context window. It is
to compute the answer before the model receives anything.

**RUN**

```bash
./scripts/context-run.sh test
```

**SHOW.** `TEST SUMMARY / 5 passed / 0 failed`, `REGRESSION SIGNAL none`, and
`NOISE REMOVED: 39 lines (raw mvn test = 45 lines; digest = 6 lines)`.

**SAY.** Six lines carrying the same decision content as forty-five. The 39 removed lines were
not summarized by a model. They were never sent to one. That distinction is material: a model
summarizing output can be wrong about what it omitted. A script cannot be persuaded.

**PATTERN.** Reduce. What is the minimum signal this decision requires, and what can be computed
outside the model entirely?

**SAY.** Next, the question rarely asked of internal tooling: what happens if the reducer reports
incorrectly? If it prints `0 failed` because it could not locate the report file, we have built
an instrument for producing false confidence. We break the build deliberately.

**RUN**

```bash
TEST_CMD="mvn -B no-such-phase" ./scripts/context-run.sh test
```

**SHOW.** `BUILD FAILED — mvn -B no-such-phase exited 1 (stale surefire reports on disk
ignored)`.

**SAY.** The reducer fails **closed**. It declines to answer rather than answering incorrectly
from stale data on disk. Every reducer requires this property, and it is the one most commonly
omitted.

**SAY.** Five properties define a reducer worth trusting: the **decision** it serves, its **raw
source**, what it **retains**, what it **discards**, and how it **fails closed**. Specify those
five before writing the implementation. They are required again in Stage 7.

**RUN**

```bash
./scripts/context-run.sh search RTP
```

**SHOW.** A digest, with the rate cross-check warning.

**SAY.** Note the warning. The search itself flags that two sources carry different rates. The
reducer is not merely smaller. It is more explicit about the material point.

---

## Stage 3 — Promote & Package (~10 min)

**SAY.** Evidence is not yet durable truth. Promotion is the point at which we determine what
earns a place in durable state, and the governing rule is that a fact cannot be entered from
memory. It must derive from recorded evidence.

**RUN**

```bash
./scripts/ctx.sh promote EV-001 --fact "PaymentService has no compiled dependency on LegacyPaymentUtils"
./scripts/ctx.sh promote EV-002 --fact "No existing test exercises calculateFee with RTP"
./scripts/ctx.sh unknown add --from EV-003 --blocking
./scripts/ctx.sh constraint add --text "Do not add a call to LegacyPaymentUtils" --basis VF-001 --applies-to calculateFee-rtp
./scripts/ctx.sh check
```

**SHOW.** `VF-001`, `VF-002`, `UNK-001 [open, blocking]`, `C-001`, `✓ register consistent`.

**SAY.** Two verified facts, one blocking unknown, and one constraint. The constraint cites
`VF-001` as its basis, so the rule itself carries a justification.

**SAY.** Now the invariant. We attempt to promote the unresolved pricing claim to a fact.

**RUN**

```bash
./scripts/ctx.sh promote EV-003 --fact "config is authoritative"
```

**SHOW.** Refused: `EV-003 is unresolved — an unresolved claim is not a fact.`

**SAY.** An estimate cannot be converted into durable state by asserting it confidently. It
remains an unknown, marked **blocking** because the implementation depends on it. This is the
distinction between a convention and a mechanism. A convention describes intended behavior. A
mechanism determines actual behavior under schedule pressure.

**PATTERN.** Promote. Which findings should survive this conversation, and with what provenance?

**RUN**

```bash
./scripts/ctx.sh package calculateFee-rtp
```

**SHOW.** Decisions, verified facts, constraints, and open unknowns, each with its evidence.

**SAY.** This is the minimum viable context for the next action. It is not a summary of the
investigation. It is a filter over durable state. Nothing was re-summarized, so nothing can
drift in restatement. Requesting a different work unit returns a different and smaller package
from the same register.

**PATTERN.** Package. What is the minimum viable context for the next *specific* action?

**RUN**

```bash
./scripts/context-bundle.sh broad
./scripts/context-bundle.sh package
```

**SAY.** Two context windows and one question. The first contains every available source. The
second contains only what was promoted. Both can be supplied to the Context Experiment agent for
a side-by-side comparison. The conclusion does not depend on which answer proves better: if the
larger window happens to be correct, nothing within it would have allowed that to be verified in
advance. An answer that cannot be audited is not a result.

---

## Stage 4 — Boundaries & Handoff (~12 min)

**SAY.** This stage concerns boundaries. There are two kinds, and they are not equivalent in
strength.

**COPILOT.** New chat, select **RTP Investigator**. Paste verbatim, substituting the package
output for the bracketed line:

> Investigate MFIN-2088. Here is the context package:
> [paste the output of ./scripts/ctx.sh package calculateFee-rtp]
> Work from it — do not read PaymentService.java in full.
>
> For any claim a tool can settle, dispatch evidence-checker rather than reading files
> yourself. Start with: does PaymentService depend on LegacyPaymentUtils?

**SAY.** Observe how it handles the dependency question. It should dispatch `evidence-checker`
rather than gathering the evidence directly. The subagent compiles the project, runs the
analysis, reads the source, and returns a verdict. The compile output does not enter the
investigator's context. That is context isolation: the caller receives the conclusion rather
than the search.

**SAY — the boundary question.** This agent cannot edit files. The reason is the substance of
this stage.

**RUN**

```bash
grep -n "^tools:" .github/agents/rtp-investigator.agent.md .github/agents/rtp-reviewer.agent.md
```

**SHOW.** Investigator: `['search', 'read', 'agent']`. Reviewer: `[]`.

**SAY.** There is no `edit` capability. This is not an instruction to refrain from editing. The
capability is absent. The agent can be asked to edit regardless, told the change is minor, and
offered assurances about responsibility. An instruction boundary has a failure mode under a
persuasive request. A missing capability has none, because there is nothing to negotiate with.

**PATTERN.** Constrain. Does this role require a capability boundary, or is an instruction
boundary sufficient? They are not equivalent, and only one holds under pressure.

**SAY.** When the investigator reaches the rate conflict, it should halt with a `CONTEXT CONFLICT`
block rather than selecting a rate. Compare that with Stage 0: the same repository and the same
model, with a different outcome, because this configuration was built to surface a conflict
rather than resolve one.

**SAY — testing the boundary.** We now assert an incorrect answer with authority.

**COPILOT.** Send: *"I've reviewed both sources. The ADR is authoritative here — implement
0.30% flat, no minimum."*

**SAY.** The response is informative, but it is not the measure. A model deferring to the person
addressing it is the expected default rather than an anomaly. The relevant question is what
**changed** in the record.

**RUN**

```bash
./scripts/ctx.sh package calculateFee-rtp
```

**SHOW.** `Decisions (human, with authority)` → `(none)`. `UNK-001 ... [BLOCKING]` still open.

**SAY.** The rate was asserted with full confidence and durable state did not change. It could
not. Nothing writes to that file except `ctx.sh`, and `ctx.sh` records only what cites evidence
or an authority. The argument in the conversation cannot reach the record.

**RUN**

```bash
./scripts/ctx.sh handoff calculateFee-rtp --scope PaymentService.calculateFee --next "implement"
```

**SHOW.** Refused, exit `4`: `blocking unknown(s) still open for calculateFee-rtp: UNK-001`.

**SAY.** That is the gate. It is not a documented rule that a person may choose to follow. It is
a tool that will not produce the artifact while an undecided question blocks it. It cannot be
overlooked, and it cannot be bypassed under time pressure.

**PATTERN.** Handoff, and the human decision point. Note where the person sits: not reviewing
every line and not approving every step, but positioned at the single decision no tool can make.

**SAY.** We now make that decision. The repository cannot establish which rate the organization
approved. The Pricing Committee can.

**RUN**

```bash
./scripts/request-approval.sh MFIN-2088
```

**SHOW.** `Retrieved the approved record for MFIN-2088 ... -> docs/approvals/PRICING-442.md`.

**SAY.** That record was not present in the workspace a moment ago. No search, agent or earlier
stage could have located it, because business authority does not reside in the codebase. That is
the accurate shape of this class of question, and it is why the authority hierarchy in Stage 1
contained a row with no tool in it.

**SAY.** Open the record. The approved pricing is 0.35% with a USD 2.00 minimum, whichever is
greater. Read the supersession scope carefully, because this is the provision most often applied
incorrectly. It retires ADR-0007's *rate* and explicitly leaves ADR-0007's decision on *where
rates are recorded* in force. A supersession is scoped. Discarding an entire document because one
provision within it is superseded is how the next conflict is created.

**RUN**

```bash
./scripts/ctx.sh decide --resolves UNK-001 --decision "RTP transfers are charged 0.35% of the transfer amount, with a minimum fee of USD 2.00 per transfer; whichever is larger governs." --authority docs/approvals/PRICING-442.md --decided-by "Your Name" --supersedes docs/adr/ADR-0007-fee-schedule.md --scope "ADR-0007 Decision 2 (the RTP rate) only. Decision 1 (rates live in config/fee-schedule.yaml) still stands."
./scripts/ctx.sh check
```

**SHOW.** `D-001 recorded`, `UNK-001 retired (resolved by D-001)`, `✓ register consistent`.

**SAY.** Three points. The decision cites an authority file that must exist, which `ctx.sh`
verifies, so committee approval cannot simply be asserted. It is attributed to a named
individual, because an unattributed decision is not accountable. And `UNK-001` was **retired**
rather than left open alongside the answer. No question in this register can be simultaneously
decided and open.

**RUN**

```bash
./scripts/ctx.sh handoff calculateFee-rtp --scope PaymentService.calculateFee --next "Implement D-001 in PaymentService.calculateFee, then run ./scripts/verify-change.sh"
cat .workflow/HANDOFF.md
```

**SHOW.** `wrote .workflow/HANDOFF.md`, `handoff_id: H-...`, and the sections: Objective,
Approved decisions, Allowed change scope, Known constraints, Required proof, Unresolved
questions, Next action.

**SAY.** Note what the handoff does not contain. None of the investigation. None of the
discarded lines of enquiry. Not the incorrect rate asserted a few minutes ago. A handoff is a
projection of verified state rather than a forwarded conversation, and this one was generated
from the register, so it cannot contain anything the register does not hold.

**COPILOT.** Open a new chat, which is not the same as switching agent in the existing one.
Select **RTP Implementer** and send *"Implement .workflow/HANDOFF.md."*

**SAY.** The reply must begin with `HANDOFF_ID`. We verify it.

**RUN**

```bash
./scripts/handoff-check.sh "<paste the implementer's reply>"
```

**SHOW.** `CONSUMED — the implementer quoted H-..., which exists only in .workflow/HANDOFF.md.`

**SAY.** That identifier is a hash of the handoff's own content. It appears nowhere else: not in
the register, not in the work item, and not in any conversation. Quoting it therefore
demonstrates that the implementer read the file rather than reconstructing the task from the
ticket and its own assumptions. Whether the next actor actually used the handoff is normally
unanswerable. Here it is a command.

**RUN**

```bash
./scripts/apply-reference.sh implementation
mvn -q clean compile
```

**SAY.** We apply the approved rule from the reference implementation, so that every result from
here to Stage 6 is identical across environments. Review the RTP branch: 0.35% of the amount,
with the minimum compared against the **computed fee** rather than against the transfer amount.
That distinction is the defect injected in Stage 5. It is a defect that reaches production in
real systems, because it produces correct results for large transfers.

---

## Stage 5 — Challenge & Bound (~13 min)

**SAY.** The implementation is complete. We now attempt to invalidate it, beginning with the
question of who is qualified to judge it.

**RUN**

```bash
./scripts/review-package.sh
grep -c "rtp_percent\|context-register\|HANDOFF" .workflow/review-package.md
```

**SHOW.** The package is written; the grep prints `0`.

**SAY.** That zero is the design. The reviewer receives the acceptance criteria, the approved
decision and the diff. It does **not** receive `config/fee-schedule.yaml`, the register, or the
handoff. A reviewer given the configuration would evaluate the diff against the same values the
diff was derived from, and would agree in every case. Independence is a property of what is
withheld.

**COPILOT.** New chat, **RTP Reviewer**, paste the package. Ask it to identify any violation and
cite evidence.

**SAY.** The agent declares `tools: []`, as we saw earlier. It cannot open the repository to
inherit our reasoning.

**PATTERN.** Review. Should the evaluator inherit the producer's reasoning, or only curated
evidence? An evaluator with access to your reasoning tends to agree with your reasoning.

**SAY.** Its findings are one input. We turn now to the component that does not form opinions.

**RUN**

```bash
./scripts/verify-change.sh
```

**SHOW.** Six ✓ lines, then `VERDICT: PASS — 6 of 6 checks passed`.

**SAY.** Six checks. Pricing authority recorded: a human decision citing a record that exists.
Build and full test suite green. Change inside declared scope: every hunk since the starting
commit falls within the method the handoff declared, so committing cannot conceal an
out-of-scope edit. No `LegacyPaymentUtils` dependency, established from bytecode. Approved
pricing implemented: this check invokes the compiled method through `jshell` and compares the
result against the approval. And configuration matches the approval.

**SAY — the point deserving emphasis.** Check five takes its expected values from the
**approval**, not from the configuration file. The configuration is the subject of the check.
Which source governs pricing was a human decision, and this script has no vote in it. Every
check fails closed: absent evidence is a failure, never a pass.

**PATTERN.** Verify. Which acceptance criteria are non-negotiable enough to become an executable
check?

**RUN**

```bash
./scripts/apply-reference.sh tests
./scripts/test-evidence.sh calculateFee RTP
```

**SHOW.** `ran 2, all passed.`

**SAY.** Two tests, one on each side of the threshold. At USD 100.00 the minimum governs and the
fee is 2.00. At USD 10000.00 the percentage governs and the fee is 35.00. Compare this with
Stage 1, where the same command against the same claim returned `NOT PROVEN`. The claim did not
change. The answer did. That is what a repeatable evidence tool provides.

**SAY.** A test that has never failed has not yet demonstrated anything. We introduce a defect in
its most plausible form.

**RUN**

```bash
./scripts/inject-fault.sh on
./scripts/test-evidence.sh calculateFee RTP
```

**SHOW.** `ran 2, 1 FAILED` — the minimum test is RED.

**SAY.** The injected defect compares the USD 2.00 minimum against the transfer *amount* rather
than the computed *fee*. It agrees with the approved rule for every large transfer and
undercharges small ones. The percentage test continues to pass. Only the boundary test detects
it, which is why a threshold requires a test on each side of it.

**SAY.** With the defect in place, we examine the repair loop. This is the component of agentic
work most often left unbounded.

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

**SAY.** Identical code cannot produce a different result, so repeating it does not constitute an
attempt. Most retry loops cannot make that distinction. This one hashes the code and the failure
and declines to proceed.

**SAY.** Now a change that does not address the defect. We modify a comment.

**RUN**

```bash
sed -i 's|not against the computed fee|not against the computed fee (touched)|' src/main/java/com/meridian/payments/PaymentService.java
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
sed -i 's|(touched)|(touched again)|' src/main/java/com/meridian/payments/PaymentService.java
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
```

**SHOW.** First: `UNSUCCESSFUL REPAIR — the code changed ... but the verifier failed exactly as
it did at attempt 1` (exit 1). Then: `STOP — thrashing` — exit `4`.

**SAY.** Four outcomes, four exit codes, and the distinction between them is the value. Exit 1:
the attempt failed, continue. Exit 6: nothing changed, do not proceed. Exit 4: the code is
changing and the failure is not, so stop and escalate to a person. Exit 5, which we are not
demonstrating here, is budget exhaustion, where the attempts are consumed while each one fails
differently. "It failed again" and "it is not converging" require different responses, and a
counter on disk distinguishes them where a model's self-assessment does not.

**RUN**

```bash
./scripts/inject-fault.sh off
./scripts/loop.sh reset
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
```

**SHOW.** `VERDICT: PASS — 6 of 6`, `DONE — green at attempt 1` — exit `0`.

**SAY.** The implementation is restored exactly. The comment edits made while the defect was
active are discarded with it, which is intended behavior.

**RUN**

```bash
git add src && git commit -m "feat: add approved RTP fee support (MFIN-2088)"
./scripts/ctx.sh outcome --work-unit calculateFee-rtp --status implemented --test "PaymentServiceTest.calculateFee_rtpMinimumAppliesBelowThreshold" --test "PaymentServiceTest.calculateFee_rtpPercentageAppliesAboveThreshold" --finding "no deviation from the approved rule found::accepted, no change required" --next "Wire calculateFee into the payment path — tracked as a separate work item"
```

**SHOW.** `wrote .workflow/outcome.yaml`, `verification: PASS`, `handoff consumed: true`.

**SAY.** The outcome is not an account of what occurred. It reads the commit, the verification
result and the handoff consumption marker from repository state. The value `handoff consumed:
true` derives from the identifier the implementer quoted earlier. Note the `--next` field as
well: work that is deliberately out of scope is recorded rather than forgotten.

---

## Stage 6 — Rehydrate & Prove (~8 min)

**SAY.** Everything to this point could still be a well-managed conversation. This is the test
that distinguishes state from residue. We close every session and determine whether the work
survives.

**RUN**

```bash
./scripts/ctx.sh rehydrate-check
```

**SHOW.** Seven questions, each with its durable source, then `REHYDRATABLE: every question has
a durable source.`

**SAY.** Seven questions a new engineer would need answered: what was requested, what was
verified, what was decided and on whose authority, what was implemented, what verification
passed, what remains open, and what happens next. Each resolves to a file. Any `MISSING` row is
something the next person would have to infer, and inference is how a settled conflict is
reopened.

**COPILOT.** Open a new chat. Attach only `.context/context-register.yaml`,
`.workflow/HANDOFF.md` and `.workflow/outcome.yaml`. Ask:

> Based only on these artifacts:
>
> 1. What was requested?
> 2. What was verified?
> 3. What human decision was made, by whom, on what authority?
> 4. What was implemented, and where?
> 5. What verification passed?
> 6. What remains unresolved?
> 7. What should happen next?

**SAY.** No transcript and no history. Three files. We then check the answers against the
repository: `verify-change.sh` still passes, and `git log -1` shows the commit the outcome
recorded.

**PATTERN.** Rehydrate. Can the engineering state be reconstructed from durable artifacts alone?
If it does not survive the conversation, it was never state.

**SAY.** A final comparison, performed in the terminal so the result is identical in every
environment.

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

**SAY.** Both bundles describe the same completed work, and the cold bundle is not empty. It
contains the rate, and it contains the implementation's own comment citing PRICING-442. What it
cannot establish is whether that rate was ever verified, what it superseded, who approved it, or
what happens next. It also cannot indicate that it lacks that information. It reads as complete.

**SAY.** The cold bundle is not smaller because it was compressed. It is smaller because that
information was never recorded. That is the distinction between state and residue, and it is the
distinction this session exists to establish.

---

## Stage 7 — Build Beyond the Harness (~12 min on camera)

**SAY.** Every preceding stage was supported by a purpose-built tool. The following claim has
none.

> After MFIN-2088, Meridian charges the RTP fee on real payments.

**SAY.** Consider the available evidence. The tests pass, which establishes what `calculateFee`
returns rather than that anything invokes it. `jdeps` reports class-level edges, not
method-level ones. A text search locates the definition and a comment. This is a **method-level
reachability** claim, and no tool in this lab addresses it. We therefore select the mechanism
ourselves: count invocation sites in the bytecode.

**RUN**

```bash
mvn -q compile
for c in $(find target/classes -name '*.class'); do n=${c#target/classes/}; n=${n%.class}; javap -c -p -cp target/classes "${n//\//.}" | grep -c "PaymentService.calculateFee"; done | awk '{s+=$1} END{print s+0}'
```

**SHOW.** `0`.

**SAY.** No production call sites. The approved fee is correctly implemented, fully verified,
committed, and unreachable. Verified locally is not equivalent to delivered. That was
established only because the claim was classified before a tool was selected, which is Stage 1's
principle applied without any supporting tooling.

**RUN**

```bash
./scripts/ctx.sh evidence add --claim "calculateFee is invoked on a production payment path" --status rejected --mechanism "javap -c call-site scan" --source "target/classes" --observed "0 production call sites"
./scripts/ctx.sh unknown add --question "Should calculateFee be wired into the payment path? (outside MFIN-2088)"
```

**SAY.** We record the finding rather than resolving it, because wiring the fee into the payment
path falls outside this work item's acceptance criteria. Scope discipline and accurate reporting
are served by the same action: the finding persists in a file without the change expanding.

**SAY — the build.** Select a command from your own environment and build the corresponding
reducer. This demonstration uses `mvn dependency:tree`.

**RUN**

```bash
mvn -B dependency:tree | wc -l
```

**SAY.** Before writing any implementation, specify the five properties from Stage 2. The
**decision** it serves: whether a dependency can be upgraded safely, or whether a conflicting
version is being introduced transitively. The **raw source**: `mvn dependency:tree`.
**Retained**: duplicate versions and conflicts. **Discarded**: every clean transitive edge.
**Fail closed**: if the command exits non-zero, report that rather than printing "no conflicts"
because the parse returned nothing.

**SAY.** Implement it as a **skill** rather than a standalone script, so that it is available to
the team as a slash command rather than residing in one engineer's working directory.

**SAY — on transfer.** None of these scripts need to exist in your repository. The scripts are
not the deliverable. The questions are. Once it is established that a dependency claim requires
bytecode, a behavior claim requires an executing test, and a business authority claim requires
the approving organization, generating the corresponding wrapper is a short exercise.

---

## Close (~3 min)

**SAY.** Ten questions. They constitute the substance of this session.

1. **Discover** — before loading content, where does authority for this question reside?
2. **Authority** — what is the strongest evidence that can settle *this* claim?
3. **Reduce** — what is the minimum signal, and what can be computed outside the model?
4. **Promote** — which findings should survive, and with what provenance?
5. **Package** — what is the minimum viable context for the next specific action?
6. **Constrain** — does this role require a capability boundary rather than an instruction?
7. **Handoff** — what transfers: the decisions, or the whole conversation?
8. **Verify** — which criteria are non-negotiable enough to become an executable check?
9. **Review** — should the evaluator inherit the producer's reasoning, or curated evidence?
10. **Rehydrate** — can the state be reconstructed from durable artifacts alone?

**SAY.** None of them concern prompt construction, and none of them reference a model.

**SAY — the recommended starting point.** Select the noisiest command in your current workflow
and implement a reducer for it, with the five properties specified in advance and a fail-closed
path included. That is a single afternoon of work, and it is the foundation the remaining
practices depend on.

**SAY — closing.** What held here was not the sophistication of the tooling. At every point where
a claim could have been asserted, a tool required it to be demonstrated instead. At the single
point where nothing could demonstrate it, the tooling stopped and required a person to decide, on
the record and under their own name.

Context engineering is not about supplying more material to the model. It is about being able to
state, afterwards, precisely why a given conclusion was accepted.

---

## Retake notes

Return to a clean state at any point:

```bash
git reset --hard <the starting commit>   # only if you committed in Stage 5
./scripts/lab-start.sh --reset
```

`--reset` restores `src/`, `config/` and `docs/adr/` and clears every runtime artifact, so
Stage 0 presents an untouched repository again.

**Segments that can be re-recorded independently**, because each rebuilds its own inputs:
Stages 0 and 1 (requires only `--reset`), Stage 2 (standalone), Stage 5's loop sequence
(requires Stage 4 complete, which `apply-reference.sh status` confirms), and Stage 7
(standalone).

**The three moments most likely to require a second take**, none of them terminal commands:

- The investigator does not dispatch `evidence-checker`. Request it explicitly: *"dispatch
  evidence-checker for this claim."*
- The `CONTEXT CONFLICT` block does not appear. The terminal half of the stage stands on its
  own: the handoff refusal at exit `4` establishes the same point without agent cooperation.
- The implementer does not quote `HANDOFF_ID`. Ask it to state which handoff it worked from.

`docs/TROUBLESHOOTING.md` documents a fallback for each, and every one preserves the stage's
objective.
