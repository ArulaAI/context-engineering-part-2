# Adversarial Validation Report
**Reviewer:** Fresh-context adversarial validator (no prior implementation session)
**Date:** 2026-08-29
**Scope:** Post-remediation claims for Context Engineering Part 2 lab

---

## Claim 1: Can the reducer still false-green?
### Attack Vector
Read `scripts/context-run.sh` and trace every exit path in the `test` subcommand. Attempted to find scenarios where Maven fails but the script exits 0, where stale reports produce a green, or where 0 tests produce a green.

### Result: PASS

### Evidence
Four sequential guards (a–d) in the `test` subcommand cover all failure modes:

- **(a)** `MVN_RC != 0 && HAVE_REPORTS == 1` → exits 1 with "stale surefire reports on disk ignored." Covers the stale-report false-green directly.
- **(b)** `MVN_RC != 0 && HAVE_REPORTS == 0` → exits 1 with "BUILD FAILED before producing any surefire report." Covers compile errors and Maven failures before Surefire ran.
- **(c)** `MVN_RC == 0 && HAVE_REPORTS == 0` → exits 1 with "no surefire reports (surefire skipped?)." Covers Surefire-skipped false green.
- **(d)** All three counts (`PASS_TOTAL`, `FAIL_TOTAL`, `ERR_TOTAL`) equal 0 → exits 1 with "no parseable test data." Covers binary-garbage or permission-denied report files.
- Final exit: `[ "$BAD_TOTAL" -eq 0 ]` — propagates Maven's result. The script only exits 0 if guards (a–d) all passed AND `BAD_TOTAL` is actually zero.

The only edge case that could theoretically be exploited: if `ls target/surefire-reports/*.txt` matches but all matched files are empty (zero-byte), guard (d) catches it. However, if a file has exactly one line containing non-numeric text, `awk`'s `{s+=$2}` pattern would silently produce 0 for all three counts, triggering guard (d)'s protection. This path is covered.

**No false-green path found.**

### Residual Risk
Minimal. The `wc -l < "$RAW"` line uses a subshell and `tr -d ' '` to strip whitespace — POSIX-safe. One cosmetic issue: the `DIGEST_LINES` counter after the failure block uses `wc -l` on `"$FAILURE_BLOCK"`, which could undercount if the block has trailing newlines, but this only affects the NOISE REMOVED display line, not the exit code.

---

## Claim 2: Can the "read-only" investigator mutate files?
### Attack Vector
Read `.github/agents/rtp-investigator.agent.md` frontmatter and body. Checked whether `tools: ['search', 'read']` actually prevents file mutation, and whether any instruction could override the tool boundary.

### Result: PASS

### Evidence
The frontmatter explicitly and exclusively lists `tools: ['search', 'read']`. Neither `edit` nor `runCommands` appears. The agent body explicitly states: "It does not contain `edit` or `runCommands`. This is deliberate and it is not a policy you are being asked to respect — **it is a capability you do not have.**"

`ARCHITECTURE.md` independently confirms: "rtp-investigator: search, read / NO edit, NO runCommands." The diagram shows the investigator cannot invoke `loop.sh`, cannot edit `src/`, and cannot run scripts.

The file further notes: "An instruction not to edit or run commands can be forgotten or overridden mid-task. A missing tool cannot." This is correct — Copilot's agent framework enforces tool lists at the API level, not the prompt level.

Crucially, the investigator's Step 5 says: "You cannot create a file — output it as a chat response for the human to save." This is consistent with missing `edit` and `runCommands`. The handoff to `rtp-implementer` is listed as `send: false` — requiring explicit human button press.

**The teaching language accurately describes the actual capability restriction.**

### Residual Risk
Low. The enforcement depends on the Copilot agent framework correctly honoring the `tools:` frontmatter. If a future Copilot version changes how tool lists are enforced, or if the agent is invoked outside VS Code Copilot (e.g., via API), the boundary could degrade to instruction-level. The lab correctly acknowledges this in the teaching language — it's a platform dependency, not a lab design flaw.

---

## Claim 3: Can a gate be bypassed?
### Attack Vector
Three sub-attacks:
1. **Attempt budget bypass:** Can `loop.sh`'s counter be reset without human action?
2. **verify-change.sh FAIL bypass:** Can its verdict be ignored?
3. **Hook circumvention:** Can the hooks in `.github/hooks/bin/` be bypassed?

### Result: PARTIAL

### Evidence

**Attack 3a — loop.sh budget bypass:**
`loop.sh reset` explicitly resets the counter and clears state: `write_state 0 "$MAX_ATTEMPTS" READY`. The `MAX_ATTEMPTS` env var defaults to 3 but can be overridden: `MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"`. This means a participant could run `MAX_ATTEMPTS=999 ./scripts/loop.sh reset` to extend the budget. However, the lab frames this as an "economic decision, not a safety one" — the bound is about cost/gain, not correctness. The rtp-implementer agent instructions explicitly state: "The bound is not yours to extend. `MAX_ATTEMPTS` is set by the human running the lab, not by you deciding three wasn't enough." An agent following instructions cannot set its own environment variables before calling loop.sh. **The bypass requires deliberate human action to exploit.**

**Attack 3b — verify-change.sh FAIL bypass:**
`verify-change.sh` exits 1 on failure. The rtp-implementer agent reads exit codes from `loop.sh check`, not from `verify-change.sh` directly. An agent that ignores the exit code and continues editing anyway would bypass the gate — but `loop-bound.sh` (the hook) independently reads `.workflow/state.json` and denies `edit` tool calls once status is `STOP_THRASHING` or `STOP_BUDGET`. This two-rung enforcement means bypassing the script-level gate still hits the hook-level gate.

However, if `.workflow/state.json` does not exist, `loop-bound.sh` calls `allow` immediately (line: `[ -f "$STATE" ] || allow`). If a participant never calls `loop.sh reset` (and thus never creates the state file), the hook provides no protection. **The hook is only active if the loop has been initialized.** This is a real gap for participants who skip the loop entirely and manually edit + run verify-change.sh.

**Attack 3c — Hook circumvention:**
`quiet-build.sh` denies raw `mvn test` calls but only matches terminal/bash/runCommands tools. A participant could read `src/` files directly and run Maven via a path not matching the hook's pattern (e.g., `bash -c "mvn test"` may or may not match `*[Bb]ash*` depending on exact tool name). The hook comment itself notes "VS Code IGNORES the 'matcher' field" and explicitly requires self-filtering on `tool_name`. The allowed list in `quiet-build.sh` (`*scripts/verify.sh*`, `*scripts/verify-change.sh*`, etc.) is comprehensive for typical use.

More critically: a participant who opens a system terminal (outside VS Code integrated terminal) bypasses hooks entirely, since hooks only intercept Copilot's `runCommands` tool.

### Residual Risk
**Medium.** The `loop-bound.sh` hook's `allow` fallback when state file is missing creates a gap: if participants skip loop initialization, the hook does nothing. The hook is described as "the upgrade" and "still works without this hook — that is deliberate" — so the lab intentionally accepts this. The budget-bypass via `MAX_ATTEMPTS` env var requires deliberate human action. External terminal bypass of hooks is inherent to the architecture and acknowledged in the lab design.

---

## Claim 4: Can stale context be accepted as current?
### Attack Vector
Read `.context/context-register.template.yaml` for pre-filled answers. Read `.context/context-register.yaml.example` for answer leakage. Check for any freshness-validation mechanism.

### Result: PASS

### Evidence

**Template analysis:** `.context/context-register.template.yaml` contains zero pre-filled facts. Every section has only instructional comments and placeholder text. The `decisions:` section explicitly reads "Leave this EMPTY until Stage 4.4." The `unknowns:` section actively tells participants that the authoritative-source question "almost certainly still belongs here" as of Stage 3.

**Example analysis:** `.context/context-register.yaml.example` is clearly labeled at line 1: "REFERENCE ONLY — what a COMPLETE register looks like by the END of the lab, after Stage 4.4's human decision has actually happened." It warns: "Do NOT copy this in Stage 3 — Stage 3 uses context-register.template.yaml." Stage 3.1 of `LAB_ACTION_GUIDE.md` separately warns: "Do not open `.context/context-register.yaml.example` until after you've done this" and explains why reading it early "would hand you Stage 4's answer before you've earned it."

**Freshness mechanism:** No automated freshness validation exists (no timestamps, no hash checks on register content). The lab relies on process discipline (ordered stages) and the template's structural warnings. This is by design — the lab teaches human judgment about what to promote, not automated staleness detection.

**The template is blank by design and cannot produce stale false-green on its own.**

### Residual Risk
Low. A participant who deliberately copies `context-register.yaml.example` in Stage 3 could inject the Stage 4.4 decisions prematurely. The lab's guards are procedural (warnings, ordered stages), not mechanical. This is an acknowledged design choice — the template and example are correctly differentiated, and the guide is explicit about when each is appropriate.

---

## Claim 5: Can a participant infer the hidden answer from scaffolding?

### Attack Vector
Read ALL listed scaffolding files simultaneously to determine whether a participant reading them all can determine which source wins (config vs ADR) before Stage 4.4, and whether the RTP rate or bug diagnosis is leaked.

### Result: PARTIAL

### Evidence

**Rate leakage analysis across all files:**

- `config/fee-schedule.yaml` line 17: `rtp_minimum_usd: 2.00  # RTP — USD 2.00 minimum, applied to the COMPUTED FEE, not the raw amount` — **This comment explicitly states the correct interpretation of the minimum (computed fee, not raw amount), which is Stage 4.4's first decision.**
- `context-register.yaml.example`: States `decisions: "The USD 2.00 minimum compares against the computed fee, not the raw amount" approved_by: "human, Stage 4.4"` — **Full decision leaked.**
- `context-register.yaml.example`: States `decisions: "config/fee-schedule.yaml supersedes docs/adr/ADR-0007-fee-schedule.md" approved_by: "human, Stage 4.4"` — **Full Stage 4.4 decision leaked.**
- `ARCHITECTURE.md` data-flow diagram shows: `Verify--xImplementer: FAIL — amount compared to 2.00, not the computed fee` — **The exact bug mechanism is named.**
- `LAB_ACTION_GUIDE.md` Stage 5.2 "Real output" block shows the exact `verify-change.sh` failure: `calculateFee(100.00, "RTP") = 0.35 — config/fee-schedule.yaml requires >= 2.00` — **The bug is fully described with the specific test value and expected output.**
- `LAB_ACTION_GUIDE.md` Stage 5.4 shows the exact fix code: `BigDecimal sepaFee = amount.multiply(...)` etc. — **The complete correct implementation is given.**
- `LAB_ACTION_GUIDE.md` Stage 7.3 worked comparison: explicitly names `CurrencyConverter` architectural gap and its tracking ticket MFIN-2041.

**Source-authority answer leakage:**
- `ARCHITECTURE.md` §2 notes: "docs/adr/ADR-0007-...md — rates here differ from config (the seeded conflict)" with no preference stated.
- `AGENTS.md` (Stage 4.4 guidance): "When `config/` and `docs/adr/` disagree about a value, check the ADR's `Status` field... Do not implement from a draft or unconfirmed source — surface the conflict and escalate." No answer given directly, but strongly implies `Proposed` status = not authoritative.
- `session-constraints.sh`: "When you encounter conflicting rate information across config files and ADR documents, surface both sources — do not assume either is authoritative without checking provenance." No answer given.
- `LAB_ACTION_GUIDE.md` Stage 4.4: After gating on "record your decision before reading further," reveals: "The ADR's `Status: Proposed` means it was never formally accepted... The committed configuration in `config/fee-schedule.yaml` reflects the current business decision." **Full resolution is in the guide itself**, though behind a deliberate stop-and-decide instruction.

**For Stage 4.4 specifically:**
A participant who reads all scaffolding files CAN determine which source wins before Stage 4.4:
1. `ADR-0007` shows `**Status:** Proposed` (readable directly)
2. `config/fee-schedule.yaml`'s header says "If a rate here disagrees with anything else in the repo... this file wins"
3. `context-register.yaml.example` states the decision outright

The pedagogical intent is that participants work through these sources in order, making the discovery themselves. The example file is the most significant leakage vector, but it is labeled and gated by the guide's explicit instruction.

### Residual Risk
**Medium-High for motivated shortcut-takers.** A participant who reads `context-register.yaml.example` or reads `LAB_ACTION_GUIDE.md` Stage 5 before doing Stage 4 will have both Stage 4.4 decisions and the exact bug fix in hand. The lab relies on pedagogical discipline rather than technical prevention. This is an inherent constraint of a text-based lab format — the guide cannot hide content from participants who read ahead. The example file and guide content are labeled as "reference only" and "after you've attempted this," but these are procedural guards.

The bug diagnosis in `ARCHITECTURE.md`'s sequence diagram and in the LAB guide's "real output" section represents the most significant leakage — a participant who reads those sections before Stage 5 knows the exact failure and its fix before encountering them.

---

## Claim 6: Can the transfer task be completed by copying?
### Attack Vector
Read LAB_ACTION_GUIDE.md Stage 7 and Stage 7B in detail. Assess whether the tasks can be completed by pattern-copying, using the worked comparison early, or writing generic answers.

### Result: PARTIAL

### Evidence

**Stage 7.1–7.2 (CurrencyConverter/authority exercise):**
- The worked comparison (Stage 7.3) is hidden behind a `<details>` collapse and explicitly instructs "open only after attempting 7.1–7.2 yourself." It is accessible immediately, making the gate purely procedural.
- Stage 7.2 asks five specific questions requiring the participant to: name which patterns apply and why, state deterministic evidence (grep count, constructor signature), name what was kept out, identify what's human-decision territory, and state what not to build.
- A participant who opens the worked comparison first gets the answer verbatim, including the exact grep commands, the constructor-analysis conclusion, and the MFIN-2041 ticket reference. Generic answers like "I ran authority checks" without specific output would fail the success criteria (which require deterministic evidence), but there is no automated validator for Stage 7 — evaluation is entirely on the honor system or peer review.

**Stage 7.4 (output-reduction exercise):**
- Requires the participant to write a 4-property reducer spec BEFORE running the command or asking Copilot. This is explicitly stated as a constraint.
- No automation validates the sequencing. The guide says "Write the spec before running any command" but cannot enforce this.

**Stage 7B (own-repo exercise):**
- Explicitly requires "a specific, real ticket (not a hypothetical)" and "the three-line plans are concrete enough that someone unfamiliar with your ticket could execute them."
- This is inherently not completable by copying — it requires a real work context. However, a participant could fabricate a plausible-sounding ticket.

**The key structural protection:** Stage 7 forbids running any of the lab's scripts, agents, or skills. There is no automated gate enforcing this — it's self-enforced. A participant who secretly runs `context-map.sh` and then reports its output as their own "manual discovery" would not be caught by any automated check.

### Residual Risk
**Medium.** Stage 7's transfer check relies on:
1. Pedagogical discipline (don't open the worked comparison early)
2. Self-enforcement (don't run the forbidden scripts)
3. Facilitator review of stage readings for specificity

Without facilitator grading, motivated shortcut-takers can complete Stage 7 superficially. The "generic answers" risk is real: a participant could write plausible-sounding but unverified answers to 7.2's five questions without actually doing the detective work. The Stage 7B exercise (own repo) has stronger inherent transfer requirements since it requires real work context.

---

## Claim 7: Grading / verification integrity
### Attack Vector
Read `scripts/verify-change.sh`. Specifically:
- Check 2: Does it detect method-level scope violations?
- Check 4: Can a hard-coded implementation pass?

### Result: PARTIAL (Check 2: FAIL; Check 4: PASS-ish)

### Evidence

**Check 2 — method-level scope:**
The check at lines 50–62 inspects:
```bash
CHANGED_FILES="$(git diff --name-only -- src/main/java 2>/dev/null)"
OTHER_FILES="$(printf '%s\n' "$CHANGED_FILES" | grep -v 'PaymentService.java' | grep -c . || true)"
```
It checks whether files OTHER THAN `PaymentService.java` were changed. It does NOT check whether changes are confined to `calculateFee` within `PaymentService.java`. The PASS message says "diff touches only calculateFee, lines 237-254" (from `outline.sh`), but this is cosmetic — the range is retrieved from `outline.sh` and displayed, but changes outside `calculateFee` within `PaymentService.java` are NOT detected as violations.

Specifically: a participant could add a new method, modify an existing non-fee method, or alter class-level fields within `PaymentService.java`, and Check 2 would still report PASS as long as they didn't touch other Java files.

The `CHANGED_METHODS` variable is computed (`grep -vc 'RTP\|0\.0035\|2\.00'`) but never used in the pass/fail logic. It appears to be dead code within the check.

**Check 4 — hard-coded implementation:**
The check at lines 74–91 calls `calculateFee(new java.math.BigDecimal("100.00"), "RTP")` via jshell and verifies the result is `>= 2.00` (the `rtp_minimum_usd` from `config/fee-schedule.yaml`).

A hard-coded implementation that always returns `BigDecimal.valueOf(2.00)` regardless of input would pass this check. However: (a) Check 1 runs the full existing test suite — if WIRE/ACH/SWIFT tests exist, they don't test RTP; (b) the existing tests only cover the pre-existing payment types. A naive `return BigDecimal.valueOf(2.00)` for RTP with correct routing would pass all four checks because: Check 1 passes (WIRE/ACH/SWIFT unaffected), Check 2 passes (only calculateFee changed), Check 3 passes (no LegacyPaymentUtils), Check 4 passes (100.00 input returns 2.00 which is >= 2.00).

The guide acknowledges this gap in Stage 5.3 ("none of `verify-change.sh`'s four checks verify this [test coverage boundary]") — the check-5 exercise is specifically designed to catch the case where the implementation is "correct for the single tested value but missing boundary coverage." A fully hard-coded `return BigDecimal.valueOf(2.00)` for RTP would only fail if tested with an amount > 571.43 where the percentage fee exceeds the minimum, but no such test exists in the current suite.

### Residual Risk
**Low-Medium for Check 2, Medium for Check 4.**

Check 2's scope enforcement is file-level, not method-level — the displayed "lines X-Y" is informational only. This is a real gap: a participant making changes outside `calculateFee` within `PaymentService.java` won't be caught.

Check 4 is genuinely vulnerable to a constant-return implementation because the test suite has no RTP tests above the minimum threshold. Stage 5.3 explicitly calls this out and asks participants to build "check 5" — the lab acknowledges the gap by design and teaches it as a lesson rather than patching it.

---

## Summary Table

| # | Claim | Result | Critical? |
|---|---|---|---|
| 1 | Reducer cannot false-green | PASS | No residual risk |
| 2 | Investigator is truly read-only | PASS | Platform dependency only |
| 3 | Gates cannot be bypassed | PARTIAL | Hook skippable if loop never initialized; env-var budget extension possible |
| 4 | Stale context cannot be accepted as current | PASS | Procedural guards only, no automation |
| 5 | Answer cannot be inferred from scaffolding | PARTIAL | `context-register.yaml.example` and LAB guide Stage 5 leak both Stage 4.4 decisions and the exact bug fix |
| 6 | Transfer task cannot be completed by copying | PARTIAL | Worked comparison accessible before attempt; no automated enforcement of sequencing |
| 7 | Grading/verification integrity | PARTIAL | Check 2 is file-level not method-level; Check 4 passable by constant-return implementation |

---

## Critical Findings

1. **`config/fee-schedule.yaml` line 17 comment** explicitly states "applied to the COMPUTED FEE, not the raw amount" — this is Stage 4.4's key pedagogical discovery, pre-revealed in the config file that participants read in Stage 1. A participant who reads this line carefully in Stage 1 already knows the answer before Stage 4.4 presents it as a human decision.

2. **`context-register.yaml.example`** contains both Stage 4.4 decisions verbatim, labeled but not mechanically gated. It is the highest-priority leakage vector.

3. **`ARCHITECTURE.md` sequence diagram** names the exact bug: "FAIL — amount compared to 2.00, not the computed fee." Available from Stage 1 if participants read the architecture doc.

4. **Check 2 scope enforcement** in `verify-change.sh` is file-level, not method-level. The displayed line range is cosmetic, not enforced.

---

*Generated by adversarial validator — no prior implementation session context.*
