# Dry-Run Log — Context Engineering Part 2

Running log of every command/prompt executed during the facilitator dry-run and the
response received, kept for building the facilitator script. Append to this file as you
move through each stage — newest stage at the bottom, chronological within a stage.

---

## CURRICULUM CHANGE — participant-facing questions removed (post Stage 2)

`LAB_ACTION_GUIDE.md` was edited to remove every participant-facing question, vote, or
"commit to your answer before scrolling" checkpoint, across all 8 stages — the 8-stage
structure, stage numbering, success criteria, and run/observe content otherwise stayed
intact. Specific changes:

- **0.1** — the A–E vote/poll on "what do you do when two sources disagree" replaced
  with a declarative framing paragraph (no answer required, no facilitator poll).
- **0.3** — the three "now ask" reflection questions replaced with a declarative
  "notice three things" framing.
- **2.3** — the "two questions" DECONSTRUCT step replaced with stated answers.
- **3.3** — "answer the question that matters" (3 questions) replaced with a
  declarative "what the comparison shows" explanation. The A/B run-and-record table
  itself is unchanged — still procedural.
- **4.2** — the "does that break the boundary? answer before reading on" +
  `<details>` reveal replaced with the explanation stated directly.
- **4.4** — softened from "ask the harder question" to a stated observation; kept the
  action itself (tell the agent the wrong answer, observe the response).
- **4.5 (the big one)** — "commit to your decision before continuing" (participant has
  to work out which source is authoritative) replaced with the resolution **stated
  directly**, followed by three numbered mechanical steps (edit the ADR, update the
  register, capture the handoff). This is a real pedagogical trade-off, not just a
  formatting change — Stage 4 no longer asks the participant to reason to the
  authoritative-source conclusion themselves before being told; it tells them the
  resolution and has them execute it. Confirmed with the user before making this change.
- **7.1** — the "answer, then check your answer" `<details>` reveal replaced with the
  pattern/scoping conclusion stated directly, still preceded by the same grep-then-
  call-path investigation steps.
- **Debrief "Final reflection"** — depended on the removed 0.1 vote ("think back to
  the option A–E you chose"); replaced with a declarative closing paragraph, renamed
  "Closing."
- Updated the Quick Reference table row, Stage 0's subtitle, and two success-criteria
  bullets that referenced the removed questions, so nothing dangles.

`PaymentService.java`'s stray unauthorized RTP branch (flagged after Stage 2) was
reverted to committed baseline before this commit — confirmed with the user it should
not be part of what gets pushed.

---

## STAGE 0 — The Helpful Trap

### 0.1 — 30-second baseline
*(no run — self-answered, not logged)*

### 0.2 — Cold first-pass ask

**Ran:** New plain Copilot chat, no lab helpers, prompt:
```
Review MFIN-2088 using only engineering evidence in `src/`, `config/`,
`docs/JIRA_TICKETS.md`, and `docs/adr/`.

For this first pass, do not use `LAB_ACTION_GUIDE.md`, `.context/`,
`.workflow/`, `.github/`, repository helper scripts, skills, or custom agents.

Tell me:
- where you would implement the RTP change,
- what fee behavior should apply,
- and how you would approach the implementation.

Do not modify files.
```

**Response received:**
```
I would implement the RTP change in PaymentService.java:237, specifically the
calculateFee method. That is the only production fee hook in the code I found, and the
current tests already target it in PaymentServiceTest.java:67 and
PaymentServiceTest.java:75. I would not route this through LegacyPaymentUtils; the
ticket explicitly says not to add a new call there, and the legacy helper is already
marked obsolete in LegacyPaymentUtils.java:88.

The fee behavior should follow the committed schedule in fee-schedule.yaml:1: RTP is
0.35% with a USD 2.00 minimum, while WIRE, ACH, and SWIFT stay unchanged. That means the
ADR in ADR-0007-fee-schedule.md:15 is the conflicting source, but it is only Proposed
and it disagrees with the committed config and the ticket in JIRA_TICKETS.md:33.

My implementation approach would be to add an RTP branch in calculateFee that computes
amount × 0.0035, rounds to cents, and then floors the result at 2.00 based on the
computed fee, not the raw transfer amount. I would also add a test for a small amount
where 0.35% is below 2.00 so the minimum binds, plus a normal-case RTP test above the
threshold.

Created 4 todos
```

**Facilitator notes:**
- Notably strong cold answer — correctly identified `calculateFee`, correctly excluded
  `LegacyPaymentUtils`, correctly flagged the ADR/config conflict, and even pre-empted
  the Stage 5.3 boundary-test requirement (fee vs. raw amount) unprompted.
- Worth flagging to participants who get an answer this clean: Stage 0's point survives
  even when the cold answer is *right* — the question is whether they could have audited
  it as right *before* Stages 1–3 gave them a way to check. This response never states
  *why* the config should outrank the ADR beyond "committed vs. Proposed" — that's the
  auditability gap Stage 3.3 (Run A vs Run B) is built to expose.
- "Created 4 todos" — Copilot auto-generated a task list unprompted; worth noting if the
  facilitator script wants to normalize/suppress that noise across participants' runs.

### 0.3 — Reflection on the answer
*(no run — self-answered against the 0.2 response above, not logged)*

---

## STAGE 1 — Discover Before You Retrieve

**Tooling change made before running 1.1:** `scripts/context-map.sh` and its skill
(`.github/skills/context-map/SKILL.md`) were updated to emit a real GFM markdown table
instead of a fixed-width `printf` table, and to save that table to
`.context/context-map-<keyword>.md` (gitignored, same as the register). Verified against
both `RTP` and `SWIFT` — table renders correctly, file is written with the expected name,
warning callout for disagreeing sources still appears. If you're building the facilitator
script off a clean clone, this diff needs to ship with it — it's not in the original repo.

**Second tooling pass (triggered by garbled output during 1.4/1.5):** the same
fixed-width `printf "%-Ns"` table problem existed in `scripts/test-gap.sh`,
`scripts/outline.sh`, and the `diff`/`search` subcommands of `scripts/context-run.sh`
(the `test` subcommand was already fine — labeled lines, not a table). Copilot Chat
doesn't render fixed-width text as monospace reliably, so columns collapsed and evidence
text looked truncated/garbled — exactly what was pasted above. All four converted to
real GFM markdown tables, each now also saved to `.context/` (`test-gap-<Class>.md`,
`outline-<Class>.md`, `context-run-diff.md`, `context-run-search-<term>.md`) and
gitignored the same way the register is.

**Bonus bug found while testing `context-run.sh diff`:** its file-to-stat matching used
`git diff --stat` + a literal grep on the full path — but `git diff --stat` truncates
long paths (e.g. `.../payments/PaymentService.java`) once several files are in the diff,
so the grep silently failed to match and the diff-stat column went blank for exactly the
file Stage 5.1's reviewer most needs a correct stat for. Fixed by switching to
`git diff --numstat` (tab-separated, full path, never abbreviated). Reproduced before the
fix (blank stat column with 9+ files changed) and confirmed after (`+1 -0` shown
correctly).

**Same caveat as the Stage 1.1 tooling change:** none of this is in the original repo —
if the facilitator script is built from a clean clone, this diff (5 scripts + 4 skills +
`.gitignore`) needs to ship with it.

### 1.1 — Context map

**Ran:** `/context-map RTP` in Copilot Chat.

**Response received:**
```
Context Map — "RTP"

Category                    Finding
Affected domains            payments (fee logic — PaymentService)
Relevant symbols            calculateFee(BigDecimal, String) — handles WIRE/ACH/SWIFT, no RTP branch yet
Contracts                   none — no RTP-specific interface exists
Configuration                config/fee-schedule.yaml:16:rtp_percent: 0.0035  # RTP — 0.35% (new, MFIN-2088) — authoritative committed config
Architecture decisions       ADR-0007-fee-schedule.md — STATUS: Proposed — verify before trusting
Tests                        none — test has no RTP test yet
Runtime/dependency bounds    none — RTP introduces no new library dependency
Ticket / objective           JIRA_TICKETS.md — 6 mention(s)

Hit counts: main: 0 · config: 1 · adr: 1 · JIRA_TICKETS.md: 6 mention(s)

Configuration and an architecture decision both mention RTP — resolve
which is authoritative before writing code (diff their rates by hand; there is
no compiler check for this, since RTP doesn't exist in code yet).

Saved to context-map-RTP.md
```

**Facilitator notes:**
- Confirms the markdown-table fix from the tooling pass above — Copilot Chat rendered
  it as an actual two-column table (Category / Finding), not a garbled monospace block.
- Copilot's own narration: *"The first run didn't surface the expected table, so I'm
  retrying through a shell explicitly to get the full script output."* Worth flagging for
  the facilitator script — the agent silently retried once before succeeding. If this
  happens consistently, it may be worth pre-warming the shell or noting it as expected
  behavior so participants don't think the first (invisible) attempt was a failure.
- Copilot dropped the `.context/` prefix in "Saved to context-map-RTP.md" — the file was
  actually written to `.context/context-map-RTP.md`; the model paraphrased the path.
  Worth a facilitator callout: tell participants to trust the script's literal output
  path over the model's restated one, or tighten the skill's output contract to forbid
  paraphrasing that line if this recurs.

### 1.2 — grep vs authority.sh

**Ran:** `grep -n "LegacyPaymentUtils" src/main/java/com/meridian/payments/PaymentService.java`

**Response received:** *(not captured — moved to Stage 2 before the output was pasted)*

**Facilitator notes:** 1.2 (grep vs. `/authority`), 1.3 (deconstruct the two ladders),
1.4 (`/test-gap`), and 1.5 (`/outline`) were **not run to completion** in this dry-run
pass — 1.2 was started but the session moved to Stage 2 before its output, or
`/authority`'s, was captured. 1.4 and 1.5 were exercised only incidentally while
verifying the tooling fix above (real output, but against a testing goal, not a logged
dry-run step) — worth circling back to run 1.2–1.5 properly before treating Stage 1 as
fully dry-run-verified.

---

## STAGE 2 — Compress Before Context

### 2.2 — The compressed path

**Ran:** `/context-run test`

**Response received:**
```
TEST SUMMARY
5 passed
0 failed

REGRESSION SIGNAL
none — existing test suite remains green

NOISE REMOVED: 39 lines (raw mvn test = 45 lines; digest = 6 lines)
```

**Facilitator notes:** Matches expected output exactly (6-line digest, 39 lines removed).

### 2.4 — Search, compressed and cross-checked

**Ran:** `/context-run search RTP`

**Response received:**
```
Context Run — search "RTP"
12 raw hits across 4 files → 4 shown (dedup: comment/doc noise removed)

File                        Line  Evidence
fee-schedule.yaml           16    rtp_percent: 0.0035  # RTP — 0.35% (new, MFIN-2088)
ADR-0007-fee-schedule.md    1     # ADR-0007 — RTP Transfer Fee Schedule
JIRA_TICKETS.md             11    ## MFIN-2088 — Add US Real-Time Payment (RTP) fee support (Stage 0 e
PaymentService.java         245   } else if (paymentType.equals("RTP")) {

RATE CROSS-CHECK: config and an ADR both state a RTP rate. Compare them by hand — THEY MAY DISAGREE.

NOISE REMOVED: 12 lines → 4 lines

Saved to context-run-search-RTP.md
```

**⚠️ CRITICAL FINDING — do not treat this as a normal facilitator note:**

`PaymentService.java:245` should **not** exist yet. Per the lab's own script, Stage 0/1
`context-map` reported `src/main: 0` hits for RTP and "no RTP branch yet" — correct, per
the baseline. The RTP branch is only supposed to enter the file at **Stage 4.6**, via
`git apply fixtures/rtp-implementation.diff`, and that fixture contains a **known,
intentional bug** (compares the raw transfer amount to $2.00, not the computed fee — so
`calculateFee(100.00, "RTP")` wrongly returns `0.35` instead of `2.00`). That bug is the
entire point of Stages 5.1–5.3: a fresh reviewer and a deterministic check are supposed
to catch it, and 5.3 has you write a permanent boundary test specifically because of it.

Checked the working tree directly (`git diff HEAD`) — `PaymentService.java` has an
**uncommitted, unauthorized RTP implementation already in it**, written by a Copilot
agent at some earlier point in this session (not by fixture, not by the user):

```java
} else if (paymentType.equals("RTP")) {
    BigDecimal percentageFee = amount.multiply(BigDecimal.valueOf(0.0035)).setScale(2, RoundingMode.HALF_UP);
    return percentageFee.max(BigDecimal.valueOf(2.00));
}
```

This version is **already correct** — it floors the *computed fee*, not the raw amount,
so it has none of the fixture's intentional bug.

**Why this breaks the lab if left in place:**
- Stage 4.6's `git apply fixtures/rtp-implementation.diff` will very likely **fail to
  apply** — the patch context around line 242–248 no longer matches a clean baseline.
- Even if it somehow applied, the bug Stage 5 is built to teach would never manifest —
  the fresh reviewer would find nothing, `verify-change.sh`'s 4th check would pass
  instead of failing, and Stage 5.3's "write the test that catches this" would have
  nothing to catch.
- Stage 0's own instruction was **"Do not modify files."** If this happened during Stage
  0 or 1, that's a real product-trust issue: participants are told the session is
  read-only and it wasn't.

**Recommended fix before continuing:** revert this one file to its committed baseline —
`git checkout -- src/main/java/com/meridian/payments/PaymentService.java` — so Stage 4.6
starts from the clean state the fixture expects. Flagged to the user rather than
auto-reverted, since it's uncommitted working-tree content and reverting is destructive.

**Open question for the real facilitator script:** figure out *which* interaction wrote
this (Stage 0's "do not modify files" ask, or a later exploratory one) and whether the
Copilot agent mode used here has broader file-write permissions than the lab assumes
participants' default chat mode has. Worth a pre-flight check ("confirm no files are
modified") after every early-stage step until the cause is identified.

---

## STAGE 3 — Promote & Package

*(pending)*

---

## STAGE 4 — Boundaries & Handoff

*(pending)*

---

## STAGE 5 — Challenge & Bound

*(pending)*

---

## STAGE 6 — Rehydrate & Prove

*(pending)*

---

## STAGE 7 — Build Beyond the Harness

*(pending)*
