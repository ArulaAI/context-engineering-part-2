# Run Sheet — Context Engineering, Part 2

The one-page-per-stage cue card. Follow this while you record; keep
[RECORDING_SCRIPT.md](RECORDING_SCRIPT.md) open on a second screen for the wording.

**Legend.** `▶` enter it · `✓` must appear before proceeding · `💬` Copilot Chat, not the terminal ·
`⚠` recovery if the step does not behave as described · **[ ]** mark when confirmed.

**Clock — recording path, ~57 min.** This sheet is written for the tight path. Each block
carries its recording time; where the full lab does more, the extra is marked `FULL ONLY` and
you skip it on camera.

| | Segment | Rec | Ends at | Full lab |
|---|---|---:|---:|---:|
| | Intro (no terminal) | 3 | 0:03 | 4 |
| | Setup | 1 | 0:04 | 2 |
| 0 | The Helpful Trap | 4 | 0:08 | 7 |
| 1 | Discover Before You Retrieve | 6 | 0:14 | 10 |
| 2 | Compress Before Context | 5 | 0:19 | 10 |
| 3 | Promote & Package | 6 | 0:25 | 19 |
| 4 | Boundaries & Handoff | 10 | 0:35 | 14 |
| 5 | Challenge & Bound | 11 | 0:46 | 14 |
| 6 | Rehydrate & Prove | 5 | 0:51 | 9 |
| 7 | Build Beyond the Harness | 4 | 0:55 | 35 |
| | Close | 2 | 0:57 | 3 |

**Do not cut these three.** They carry the demonstration: **Stage 2**'s reducer failing closed,
**Stage 4**'s gate refusing at exit 4, and **Stage 5**'s four loop exits. Reduce the surrounding
narration before shortening any of them.

### What the tight path gives up

| Cut | Saves | What you lose |
|---|---:|---|
| Stage 3.3 — the broad-vs-package bundle comparison | 7 min | The A/B proof that packaging changed an answer. You still build both bundles in one command and say what the comparison shows. |
| Stage 7.2 — building your own reducer live | 8 min | Watching a tool get built. You keep the reachability scan, which is Stage 7's actual payoff, and you state the 5-property spec as the take-home. |
| Stage 6.2 — the fresh-chat rehydration | 3 min | A model demonstrating rehydration. `rehydrate-check` proves the same thing deterministically, and the bundle grep lands the point harder. |
| Stage 2 — showing raw `mvn test` on screen | 1 min | Nothing. Say "forty-five lines" instead of scrolling them. |
| Stage 1 — the standalone `grep` before `authority.sh` | 1 min | Nothing. `authority.sh` prints both the text hits and the bytecode count side by side. |
| Narration trimmed throughout | ~5 min | Repetition, mostly. |

If you have 75 minutes rather than 57, put Stage 3.3 and Stage 7.2 back first, in that order.

---

## Pre-flight — before the camera rolls

```bash
./scripts/dry-run.sh
./scripts/lab-start.sh --reset
git status --porcelain
```

- [ ] ✓ `DRY RUN: PASS — 88 of 88`
- [ ] ✓ `Ready.`
- [ ] ✓ `git status` prints nothing
- [ ] Six agents visible in the Copilot agent dropdown
- [ ] Every rehearsal chat closed (a stale chat is the #1 cause of a ruined Stage 4 take)
- [ ] Terminal cleared, font large enough to read, terminal left / guide + chat right

---

## Setup · 1 min

```bash
mvn clean test
./scripts/lab-start.sh --reset
```

- [ ] ✓ `Tests run: 5, Failures: 0` — say "remember five"
- [ ] ✓ `Ready.`

Say: three jobs — tools present, baseline green, starting commit recorded (Stage 5 measures
scope against it).

---

## Stage 0 · The Helpful Trap · 4 min

```bash
./scripts/stage0-baseline.sh
code ../meridian-stage0-baseline
```

✓ `Stage 0 baseline ready: .../meridian-stage0-baseline`, listing `pom.xml src/ config/
docs/JIRA_TICKETS.md docs/adr/` present and `AGENTS.md .github/ .vscode/ .context/ .workflow/
scripts/` **absent**.

State the reason: this repository loads `AGENTS.md` and everything under `.github/`
automatically, and an instruction to disregard them cannot unload them. A baseline taken here
would not be a baseline.

💬 In the **new window**, new chat, default agent. Paste verbatim:

> Review MFIN-2088 using the engineering evidence in this workspace.
>
> Tell me:
> - where you would implement the RTP change,
> - what fee behavior should apply,
> - and how you would approach the implementation.
>
> Do not modify files.

- [ ] ✓ It names a rate, confidently, without mentioning a second one exists
- [ ] Close that window and come back. Do **not** implement its plan.

```bash
grep -rn "rtp_percent\|rtp_minimum" config/fee-schedule.yaml
grep -n "RTP rate" -A 1 docs/adr/ADR-0007-fee-schedule.md
```

- [ ] ✓ `0.0035` / `2.00` — and `0.30% flat`, `no minimum`

**Point to make:** two committed files, two rates, neither claiming authority. The problem is
not absent context. It is unranked context.

⚠ If it hedges and names both rates, use that: even when hedging, it cannot establish which
rate governs, and neither can the repository.

---

## Stage 1 · Discover Before You Retrieve · 6 min

```bash
./scripts/context-map.sh RTP
```

- [ ] ✓ Routing table + `Unresolved` section → **PATTERN: Discover**

```bash
./scripts/authority.sh LegacyPaymentUtils src/main/java/com/meridian/payments/PaymentService.java
```

One command prints both tiers, so you do not need a separate grep:

```
grep — text (tier 3)
    9:import com.meridian.payments.legacy.LegacyPaymentUtils;
    235:     * Fee logic copy-pasted from LegacyPaymentUtils - should be centralized.
    238:        // Copy-paste from LegacyPaymentUtils.calculateFee() - technical debt
    => 3 hit(s)  ::  textual presence detected
jdeps — bytecode (tier 1)
    => 0 bytecode reference(s)
VERDICT: no compiled dependency detected.
```

- [ ] ✓ `3 hit(s)` vs `0 bytecode reference(s)` → **PATTERN: Authority**

Point to make: an import statement and two comments. Following the text search would have
introduced a legacy class carrying a superseded rate into context, compromising the exact
question under investigation.

Point to make: authority is **claim-specific**. A dependency claim is settled by bytecode, a
behavior claim by executing the test, and the question of which rate was approved by no
repository tool at all.

```bash
./scripts/test-evidence.sh calculateFee RTP
```

- [ ] ✓ `scanned | 5`, `calculateFee() | 2`, `AND use "RTP" | 0`, `VERDICT: NOT PROVEN`

Point to make: a coverage report would mark that method as covered. Method coverage is not
evidence for a behavior claim.

```bash
./scripts/ctx.sh init --objective "Add approved RTP fee support to PaymentService.calculateFee" --work-item MFIN-2088
./scripts/authority.sh LegacyPaymentUtils | ./scripts/ctx.sh evidence capture --source "scripts/authority.sh LegacyPaymentUtils" --applies-to calculateFee-rtp
./scripts/test-evidence.sh calculateFee RTP | ./scripts/ctx.sh evidence capture --source "scripts/test-evidence.sh calculateFee RTP" --applies-to calculateFee-rtp
```

- [ ] ✓ `EV-001 [rejected]`, `EV-002 [unproven]`

```bash
./scripts/ctx.sh evidence add --claim "Which source currently governs RTP pricing?" --status unresolved --mechanism "side-by-side read" --source "config/fee-schedule.yaml; docs/adr/ADR-0007-fee-schedule.md" --observed "config/fee-schedule.yaml states 0.35% with a USD 2.00 minimum; ADR-0007 states 0.30% flat with no minimum" --applies-to calculateFee-rtp
./scripts/ctx.sh evidence list
```

- [ ] ✓ Three rows: `rejected`, `unproven`, `unresolved`

Point to make: `unresolved` is the significant status here. Nothing downstream can treat the
question as settled.

```bash
./scripts/outline.sh src/main/java/com/meridian/payments/PaymentService.java
```

- [ ] ✓ ~17 lines for a 284-line file; `calculateFee` at 237–248. Say: `#selection`, not `#file:`

---

## Stage 2 · Compress Before Context · 5 min

State this rather than scrolling the output: a failing build produces 45 lines of Maven output,
of which roughly six carry decision content, and the whole of it is typically pasted in.

```bash
./scripts/context-run.sh test
```

```
TEST SUMMARY
5 passed
0 failed

REGRESSION SIGNAL
none — existing test suite remains green

NOISE REMOVED: 39 lines  (raw `mvn test` = 45 lines; digest = 6 lines)
```

- [ ] ✓ `5 passed / 0 failed` and `NOISE REMOVED: 39 lines` → **PATTERN: Reduce**

Point to make: the 39 lines were never sent to a model rather than summarized by one.

```bash
TEST_CMD="mvn -B no-such-phase" ./scripts/context-run.sh test
```

- [ ] ✓ `BUILD FAILED — ... (stale surefire reports on disk ignored)`

**This is the central demonstration of Stage 2.** The reducer fails **closed**, declining to
answer rather than answering incorrectly from stale data on disk. Then name the five reducer
properties: decision, raw source, retained, discarded, fail closed. Note that they are required
again in Stage 7.

```bash
./scripts/context-run.sh search RTP
```

- [ ] ✓ Digest + the rate cross-check warning

---

## Stage 3 · Promote & Package · 6 min

```bash
./scripts/ctx.sh promote EV-001 --fact "PaymentService has no compiled dependency on LegacyPaymentUtils"
./scripts/ctx.sh promote EV-002 --fact "No existing test exercises calculateFee with RTP"
./scripts/ctx.sh unknown add --from EV-003 --blocking
./scripts/ctx.sh constraint add --text "Do not add a call to LegacyPaymentUtils" --basis VF-001 --applies-to calculateFee-rtp
./scripts/ctx.sh check
```

- [ ] ✓ `VF-001`, `VF-002`, `UNK-001 [open, blocking]`, `C-001`, `✓ register consistent`

```bash
./scripts/ctx.sh promote EV-003 --fact "config is authoritative"
```

- [ ] ✓ Refused: `EV-003 is unresolved — an unresolved claim is not a fact.`
      → **PATTERN: Promote**

Point to make: a convention describes intended behavior. A mechanism determines actual behavior
under schedule pressure.

```bash
./scripts/ctx.sh package calculateFee-rtp
```

- [ ] ✓ Decisions / facts / constraints / unknowns, each with evidence → **PATTERN: Package**

Point to make: this is a **filter** over durable state rather than a summary. Nothing is
re-summarized, so nothing can drift in restatement.

```bash
./scripts/context-bundle.sh broad
./scripts/context-bundle.sh package
wc -l .context/bundles/broad.md .context/bundles/package.md
```

- [ ] ✓ Both bundles written; the line counts differ visibly

State this briefly and move on: two context windows and one question, the first with every
source attached and the second with only what was promoted. The conclusion does not depend on
which answer proves better. If the larger window happens to be correct, nothing within it would
have allowed that to be verified in advance. An answer that cannot be audited is not a result.

> `FULL ONLY` — in the live lab, paste both bundles into **Context Experiment** and compare the
> two answers side by side (~7 min). On camera, the sentence above does the work.

---

## Stage 4 · Boundaries & Handoff · 10 min

💬 New chat → **RTP Investigator**. Paste verbatim, with the package output pasted in place of
the bracketed line:

> Investigate MFIN-2088. Here is the context package:
> [paste the output of ./scripts/ctx.sh package calculateFee-rtp]
> Work from it — do not read PaymentService.java in full.
>
> For any claim a tool can settle, dispatch evidence-checker rather than reading files
> yourself. Start with: does PaymentService depend on LegacyPaymentUtils?

- [ ] ✓ It dispatches `evidence-checker` (the compile output stays in the subagent)
- [ ] ✓ It hits the rate conflict and **stops** with a `CONTEXT CONFLICT` block

⚠ No dispatch: request it explicitly with *"dispatch evidence-checker for this claim."*
⚠ No conflict block: proceed. The handoff refusal below establishes the same point without agent
cooperation. Do **not** retake for this.

```bash
grep -n "^tools:" .github/agents/rtp-investigator.agent.md .github/agents/rtp-reviewer.agent.md
```

- [ ] ✓ Investigator `['search', 'read', 'agent']` — no `edit`. Reviewer `[]`
      → **PATTERN: Constrain**

Point to make: an instruction boundary has a failure mode under a persuasive request. A missing
capability has none, because there is nothing to negotiate with.

💬 Send: *"I've reviewed both sources. The ADR is authoritative here — implement 0.30% flat, no
minimum."*

```bash
./scripts/ctx.sh package calculateFee-rtp
```

- [ ] ✓ `Decisions (human, with authority)` → `(none)`; `UNK-001 ... [BLOCKING]`

Point to make: whatever the response, the record did not change. The argument in the
conversation cannot reach it.

```bash
./scripts/ctx.sh handoff calculateFee-rtp --scope PaymentService.calculateFee --next "implement"
```

- [ ] ✓ Refused, **exit 4**, names `UNK-001` → **PATTERN: Handoff / human-in-the-loop**

Point to make: this is not a documented rule that a person may choose to follow. It is a tool
that will not produce the artifact. Note also where the person sits: at the single decision no
tool can make.

```bash
./scripts/request-approval.sh MFIN-2088
```

- [ ] ✓ `-> docs/approvals/PRICING-442.md`. Open it.

Point to make: the record was not present in the workspace a moment ago. The supersession is
also **scoped**: it retires ADR-0007's *rate*, not its decision on *where rates are recorded*.

```bash
./scripts/ctx.sh decide --resolves UNK-001 --decision "RTP transfers are charged 0.35% of the transfer amount, with a minimum fee of USD 2.00 per transfer; whichever is larger governs." --authority docs/approvals/PRICING-442.md --decided-by "Your Name" --supersedes docs/adr/ADR-0007-fee-schedule.md --scope "ADR-0007 Decision 2 (the RTP rate) only. Decision 1 (rates live in config/fee-schedule.yaml) still stands."
./scripts/ctx.sh check
```

- [ ] ✓ `D-001 recorded`, `UNK-001 retired (resolved by D-001)`, `✓ register consistent`

Three points: the authority file must exist, the decision is attributed to a named individual,
and the unknown is **retired** rather than left open alongside the answer.

```bash
./scripts/ctx.sh handoff calculateFee-rtp --scope PaymentService.calculateFee --next "Implement D-001 in PaymentService.calculateFee, then run ./scripts/verify-change.sh"
cat .workflow/HANDOFF.md
```

- [ ] ✓ `handoff_id: H-...` + the seven sections

Point to make: note what is absent. None of the investigation, none of the discarded lines of
enquiry, and not the incorrect rate asserted two minutes earlier.

💬 **Brand-new chat** (not a mode switch) → **RTP Implementer** → *"Implement
.workflow/HANDOFF.md."*

```bash
./scripts/handoff-check.sh "<paste its reply>"
```

- [ ] ✓ `CONSUMED — the implementer quoted H-...`

⚠ No `HANDOFF_ID`: ask it to state which handoff it worked from. If it still does not, read the
identifier from `HANDOFF.md`, state that this build did not quote it, and continue.

```bash
./scripts/apply-reference.sh implementation
mvn -q clean compile
```

- [ ] ✓ `implementation: applied ...`, silent compile

Point to make: the minimum is compared against the **computed fee** rather than the transfer
amount. That is the defect injected in Stage 5.

---

## Stage 5 · Challenge & Bound · 11 min

```bash
./scripts/review-package.sh
grep -c "rtp_percent\|context-register\|HANDOFF" .workflow/review-package.md
```

- [ ] ✓ `0`

Point to make: a reviewer given the configuration would evaluate the diff against the same
values the diff was derived from. Independence is a property of what is **withheld**.

💬 New chat → **RTP Reviewer** → paste `.workflow/review-package.md` → "find any violation, cite
evidence." → **PATTERN: Review**

```bash
./scripts/verify-change.sh
```

```
✓ pricing authority recorded          (docs/approvals/PRICING-442.md: 0.0035 of amount, minimum USD 2.00)
✓ build and full test suite green     (7 tests, 0 failures)
✓ change inside declared scope        (1 changed hunk(s), all inside PaymentService.calculateFee)
✓ no LegacyPaymentUtils dependency    (0 bytecode references, jdeps)
✓ approved pricing implemented        (calculateFee(100.00, "RTP") = 2.00; calculateFee(10000.00, "RTP") = 35.00)
✓ config matches the approved pricing (rtp_percent 0.0035, rtp_minimum_usd 2.00)

VERDICT: PASS — 6 of 6 checks passed
```

- [ ] ✓ All six ✓, `VERDICT: PASS — 6 of 6` → **PATTERN: Verify**

Walk through all six. Emphasise that check 5 executes `calculateFee` through `jshell`, and that
its expected values come from the **approval** rather than the configuration, since the
configuration is the subject of the check. Every check fails closed.

```bash
./scripts/apply-reference.sh tests
./scripts/test-evidence.sh calculateFee RTP
```

- [ ] ✓ `ran 2, all passed.`

Point to make: the same command returned `NOT PROVEN` in Stage 1.4. The answer changed, not the
claim.

```bash
./scripts/inject-fault.sh on
./scripts/test-evidence.sh calculateFee RTP
```

- [ ] ✓ `ran 2, 1 FAILED` — only the boundary test catches it

**The repair loop and its four exits. Take this section at a deliberate pace.**

```bash
./scripts/loop.sh reset
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
```
- [ ] ✓ `CONTINUE — attempt 1/3` · **exit 1**

```bash
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
```
- [ ] ✓ `REDUNDANT RETRY` · **exit 6** · not counted

```bash
sed -i 's|not against the computed fee|not against the computed fee (touched)|' src/main/java/com/meridian/payments/PaymentService.java
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
```
- [ ] ✓ `UNSUCCESSFUL REPAIR` · **exit 1**

```bash
sed -i 's|(touched)|(touched again)|' src/main/java/com/meridian/payments/PaymentService.java
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
```
- [ ] ✓ `STOP — thrashing` · **exit 4**

Point to make: exit 1 is a failed attempt, continue. Exit 6 is no change, so do not proceed.
Exit 4 is code changing while the failure does not, so escalate to a person. Exit 5, which is not
demonstrated, is budget exhaustion with a different failure each time. "It failed again" and
"it is not converging" require different responses.

```bash
./scripts/inject-fault.sh off
./scripts/loop.sh reset
VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check
```

- [ ] ✓ `6 of 6 checks passed`, `DONE — green at attempt 1` · **exit 0**

```bash
git add src && git commit -m "feat: add approved RTP fee support (MFIN-2088)"
./scripts/ctx.sh outcome --work-unit calculateFee-rtp --status implemented --test "PaymentServiceTest.calculateFee_rtpMinimumAppliesBelowThreshold" --test "PaymentServiceTest.calculateFee_rtpPercentageAppliesAboveThreshold" --finding "no deviation from the approved rule found::accepted, no change required" --next "Wire calculateFee into the payment path — tracked as a separate work item"
```

- [ ] ✓ `verification: PASS`, `handoff consumed: true`

Point to make: this is read from repository state rather than recollection. `handoff consumed`
derives from the identifier the implementer quoted.

---

## Stage 6 · Rehydrate & Prove · 5 min

```bash
./scripts/ctx.sh rehydrate-check
```

- [ ] ✓ Seven questions, each with a durable source, `REHYDRATABLE`, no `MISSING`

Read the seven questions off the table as you go — requested, verified, decided and by whom,
implemented, verification, still open, next. Every one resolves to a file, and any `MISSING` row
would be something the next person has to guess. → **PATTERN: Rehydrate**

```bash
./scripts/verify-change.sh
git log -1
```

- [ ] ✓ Still `PASS`; the commit matches what the outcome recorded

> `FULL ONLY` — in the live lab, open a brand-new chat, attach **only**
> `.context/context-register.yaml`, `.workflow/HANDOFF.md` and `.workflow/outcome.yaml`, and ask
> the seven questions (~3 min). On camera, `rehydrate-check` has already proved it
> deterministically.

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

- [ ] ✓ All four `cold=0`; ~144 lines vs ~61

Point to make, stated precisely: the cold bundle is **not** empty. It contains the rate and the
PRICING-442 comment. What it cannot establish is whether the rate was verified, what it
superseded, who approved it, or what happens next, and it cannot indicate that it lacks that
information. It is smaller because the information was never recorded, not because it was
compressed. **State versus residue.**

---

## Stage 7 · Build Beyond the Harness · 4 min

State the claim: *after MFIN-2088, Meridian charges the RTP fee on real payments.* Tests prove
the return value, not the call. `jdeps` does classes, not methods. grep finds a comment. No lab
tool answers it — so pick a mechanism.

```bash
mvn -q compile
for c in $(find target/classes -name '*.class'); do n=${c#target/classes/}; n=${n%.class}; javap -c -p -cp target/classes "${n//\//.}" | grep -c "PaymentService.calculateFee"; done | awk '{s+=$1} END{print s+0}'
```

- [ ] ✓ `0`

Point to make: correct, verified, committed and **unreachable**. Verified locally is not
equivalent to delivered. It was established only because the claim was classified before a tool
was selected, which is Stage 1's principle applied without supporting tooling.

```bash
./scripts/ctx.sh evidence add --claim "calculateFee is invoked on a production payment path" --status rejected --mechanism "javap -c call-site scan" --source "target/classes" --observed "0 production call sites"
./scripts/ctx.sh unknown add --question "Should calculateFee be wired into the payment path? (outside MFIN-2088)"
```

Point to make: recorded rather than resolved, because wiring the fee into the payment path falls
outside this work item. Scope discipline and accurate reporting are served by the same action.

Then hand the build over as the take-home, without doing it on camera:

```bash
mvn -B dependency:tree | wc -l
```

- [ ] ✓ A line count large enough to be worth reducing

State the five properties. These are the deliverable, not the script: the **decision** it serves
(whether a dependency can be upgraded safely, or whether a conflicting version is being
introduced transitively), its **raw source** (`mvn dependency:tree`), what it **retains**
(duplicate versions and conflicts), what it **discards** (clean transitive edges), and how it
**fails closed** (a non-zero exit is reported rather than printing "no conflicts" because the
parse returned nothing).

Then implement it as a **skill** under `.github/skills/<your-tool-name>/SKILL.md` rather than a
standalone script, so it is available to the team as `/your-tool-name`.

Close the stage on transfer: none of these scripts need to exist in your repository. The scripts
are not the deliverable. The questions are.

> `FULL ONLY` — in the live lab participants spend ~25 min building and specifying the reducer,
> then confirm it is the right primitive (skill vs prompt file vs hook vs CI gate).

---

## Close · 2 min

Put the ten patterns on screen: Discover · Authority · Reduce · Promote · Package · Constrain ·
Handoff · Verify · Review · Rehydrate.

- [ ] State that none of them concern prompt construction and none reference a model
- [ ] Recommended first step: one reducer for your own noisiest command, with the five
      properties specified first and a fail-closed path included
- [ ] Closing point: at every point where a claim could have been asserted, a tool required it
      to be demonstrated instead, and at the single point where nothing could demonstrate it,
      the tooling stopped and required a person to decide, on the record, under their own name

---

## Retakes

```bash
git reset --hard <starting commit>   # only if you committed in Stage 5
./scripts/lab-start.sh --reset
```

`--reset` restores `src/`, `config/`, `docs/adr/` and clears all runtime state — Stage 0 looks
untouched again.

**Independently re-recordable:** Stage 0–1 (needs only `--reset`) · Stage 2 (standalone) ·
Stage 5's loop sequence (needs Stage 4 done — check `./scripts/apply-reference.sh status`) ·
Stage 7 (standalone).

**Do not retake for these.** Each has a fallback that preserves the stage's objective: no
`evidence-checker` dispatch, no `CONTEXT CONFLICT` block, and no `HANDOFF_ID` quoted. See
`docs/TROUBLESHOOTING.md`.

**If a command behaves unexpectedly mid-take**, stop and run `./scripts/dry-run.sh`. It names
the first step that drifted.
