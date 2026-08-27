# Context Lifecycle Lab — Pre-Delivery Verification

**Run this in full on a machine matching the participants' setup before any delivery.**
Budget 30 minutes. Checks A1–A5 are automated and take under a minute. Checks B1–B5 must
be run by hand in VS Code because they depend on the Copilot build actually installed.

Three of the manual checks can force a change to the lab structure. They are marked
**STRUCTURAL**. Run those first.

Record results in the table at the bottom and keep the completed copy with the run sheet.

---

## Part A — Automated (under 1 min)

Run from the repo root (`context-engineering-part-2/`), on a clean working tree:

```bash
bash docs/verify.sh
```

| # | Check | Pass condition |
|---|---|---|
| A1 | Toolchain present | `java` ≥ 17, `mvn`, `jshell`, `jdeps`, `git` all resolve |
| A2 | Baseline build and tests | `mvn clean test` → `BUILD SUCCESS`, `Tests run: 5, Failures: 0` |
| A3 | `context-map.sh SEPA` correctness | Finds both `config/fee-schedule.yaml` and `docs/adr/ADR-0007-fee-schedule.md`, and reports their disagreement |
| A4 | `authority.sh` correctness | Reports 3 grep hits / 0 bytecode references on `LegacyPaymentUtils`, verdict `FALSE POSITIVE` |
| A5 | `verify-change.sh` correctness | Flags `fixtures/sepa-implementation.diff` as `FAIL` on "authoritative configuration respected," and clears to `PASS` once the amount-vs-computed-fee comparison is corrected |

A5 is the hard one this lab needs that a simpler lab wouldn't: it's not enough for the
verifier to run, it has to actually distinguish the buggy implementation from the fixed
one. The script mutates the working tree temporarily (applies the fixture, patches the
fix in place, reverts via `git checkout`) and refuses to run at all if tracked files are
already dirty — check its exit code, don't just eyeball the output.

A3 and A4 are the ones that silently rot. If someone edits `PaymentService.java` or
`config/fee-schedule.yaml`, the numbers in the participant guide go stale and Stage 1
stops matching the runbook.

---

## Part B — Manual, in VS Code (~25 min)

### B1 — This lab opens as its own workspace root, and its agents/skills are discoverable **[STRUCTURAL]**

Every stage from 4 onward depends on this.

1. Open `context-engineering-part-2/` itself as a VS Code folder — not a parent
   directory.
2. Open the chat mode dropdown. Confirm **SEPA Investigator**, **SEPA Implementer**, and
   **SEPA Reviewer** all appear.
3. In a chat, type `#` and confirm the four skills (`context-map`, `context-run`,
   `context-package`, `verify-change`) are either auto-invoked when relevant or listed.

**Pass:** all three agents appear in the dropdown, skills are discoverable.
**Fail:** confirm the workspace root is correct first — this is the single most likely
failure mode and has nothing to do with the lab content. If agents still don't appear
with the correct root, note the Copilot build version and treat Stage 4/5 as
instructor-demonstrated rather than hands-on for this delivery.

---

### B2 — The investigator cannot edit, and stops on the seeded conflict **[STRUCTURAL]**

Stage 4 depends on this being real, not just described in the agent file.

1. Select **SEPA Investigator**. Ask it to investigate MFIN-2088.
2. Confirm it runs `context-map.sh` / `context-for.sh` rather than opening
   `PaymentService.java` in full.
3. Ask it to "just make the edit yourself." Confirm it cannot — no `edit` tool offered,
   and it says so rather than attempting a workaround.
4. Confirm it emits the `CONTEXT CONFLICT` block once it reaches the SEPA rate question,
   and does **not** write `.workflow/HANDOFF.md` before that's resolved.

**Pass:** all four behaviors observed.
**Fail:** if the capability restriction doesn't hold (the agent edits anyway), treat this
as a build-specific gap — say so honestly in delivery rather than presenting the missing
tool as a guarantee it currently isn't. If the conflict isn't surfaced, check that
`docs/adr/ADR-0007-fee-schedule.md`'s Status still reads `Proposed` (not already marked
Superseded from a prior dry run) and re-test.

---

### B3 — Fresh-context review actually requires a new chat **[STRUCTURAL]**

Stage 5.1's entire lesson depends on this distinction being real in the product, not
just asserted in the guide.

1. In the chat that just discussed the SEPA implementation, switch mode to **SEPA
   Reviewer** without opening a new chat. Ask it to review the change.
2. Separately, open a genuinely new chat, select **SEPA Reviewer**, and give it only the
   curated package (diff + ticket + config).

**Pass:** the mode-switch-only review shows some awareness of the prior conversation
(confirming the guide's warning is necessary); the new-chat review does not.
**Partial:** you can't cleanly observe a difference on this build. Say so in delivery —
teach the isolation mechanism (open a new chat) as the reliable practice regardless of
whether you can demonstrate the failure mode live.

---

### B4 — The bounded loop detects thrashing and clears on the real fix

1. `git apply fixtures/sepa-implementation.diff`
2. `./scripts/loop.sh reset`
3. `VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check` — expect exit 1.
4. Run the identical command again with no code change — expect exit 4 (thrashing).
5. Apply the fix (compare the computed fee, not the raw amount). Run again — expect
   exit 0.
6. `git checkout -- src/main/java/com/meridian/payments/PaymentService.java` to restore
   baseline.

**Pass:** exit codes 1 → 4 → 0 observed in that order, matching the guide.
**Fail:** if `jshell` isn't on `PATH` in the delivery environment, `verify-change.sh`'s
fourth check will report "could not evaluate" instead of a clean pass/fail — install a
JDK 17+ that includes `jshell` (it's bundled, not a separate package) before delivery.

---

### B5 — Deltas are big enough to teach from

Run the expensive and cheap paths for Stage 2 and record actual numbers — do not assume
last delivery's numbers still hold if `PaymentService.java` or the test suite changed.

**Pass:** the digest is meaningfully smaller than the raw output, and a participant would
notice without being told.

Reference figures measured while building this lab, for orientation only:

| | Expensive | Compressed |
|---|---|---|
| Stage 2 — `mvn test` output | 45 lines (this small, cached-dependency repo) | 6-line digest |
| Stage 2 — repo search for "SEPA" | 11 raw hits | 3 shown, deduped, with a rate cross-check |
| Stage 1 — `PaymentService.java` outline | 284-line file | 17-line outline |

A real project's raw `mvn test` runs far longer than 45 lines — this repo's small size
and cached dependencies keep the absolute number low. The compression *ratio*, not the
absolute count, is the teachable delta.

---

## Results

| Check | Result | Notes / fallback engaged |
|---|---|---|
| A1 Toolchain | | |
| A2 Baseline build | | |
| A3 `context-map.sh` | | |
| A4 `authority.sh` | | |
| A5 `verify-change.sh` FAIL→PASS | | |
| B1 Workspace root / discoverability **[S]** | | |
| B2 Investigator capability + conflict gate **[S]** | | |
| B3 Fresh-chat isolation **[S]** | | |
| B4 Bounded loop exit codes | | |
| B5 Deltas teachable | | |

**Verified by:** ______________________  **Date:** ____________
**Copilot build / VS Code version:** ______________________

---

## Standing risks

- **Line numbers and the fixture diff are hardcoded to the current
  `PaymentService.java`.** Any edit to that file invalidates `fixtures/sepa-implementation.diff`
  and Stage 1's line-number references. A5 and A3 catch most of this; a full re-run of
  Part A after any source edit is still required.
- **`config/fee-schedule.yaml` and `docs/adr/ADR-0007-fee-schedule.md`'s Status field**
  are stateful across dry runs — if a prior run marked the ADR Superseded, reset it to
  `Proposed` before delivery, or Stage 4.2's conflict won't surface.
- **`jshell` availability** is the single most likely environment-specific failure. It
  ships with the JDK but some minimal JRE-only installs omit it — confirm on the actual
  delivery machine, not just the build machine.
- **Model names** are deliberately absent from participant materials. Keep it that way.
