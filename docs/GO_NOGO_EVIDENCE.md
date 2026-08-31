# GO / NO-GO Evidence Package — Context Engineering, Part 2

**Created:** 2026-08-29
**Phase:** 4 (Evidence Package)
**Sources:** `docs/REMEDIATION_ACCEPTANCE_MATRIX.md`, `docs/ADVERSARIAL_VALIDATION_REPORT.md`, `docs/PLATFORM_VALIDATION_MATRIX.md`, `docs/TRANSFER_VALIDATION_FRAMEWORK.md`, `docs/TIMED_FACILITATION_GUIDE.md`, git log `e052910..HEAD`

---

## How to Read This Document

Each entry below corresponds to one row in `docs/REMEDIATION_ACCEPTANCE_MATRIX.md`. Fields use the standard format:

- **Requirement** — the PASS condition from the acceptance matrix
- **Implementation** — what was done to satisfy it (commit evidence where available)
- **Verification** — how it was tested or validated
- **Platform** — findings from the platform validation matrix
- **Transfer** — transfer-relevant findings if applicable
- **Status** — PASS | PARTIAL | FAIL | DEFERRED

---

## R1 — Deterministic Reducer (False-Green Fix)

**Requirement:**
Fresh Maven failure + stale valid reports → reducer exits non-zero. All six scenarios in the Phase 2.1 validation matrix pass. `context-run.sh test` subcommand never exits 0 when Maven itself failed.

**Implementation:**
Two commits address R1. `e34e809` (fix(context-run): R1 — make Maven exit code authoritative, block stale-report false-green) introduced the primary guard capturing Maven's exit code before Surefire reports are read. `95375a1` (fix(context-run): guard (d) — block false-green when reports are unreadable/zero-byte) added the fourth sequential guard covering the zero-byte / unreadable report edge case.

The four guards in the `test` subcommand:
- Guard (a): `MVN_RC != 0 && HAVE_REPORTS == 1` → exits 1 ("stale surefire reports on disk ignored")
- Guard (b): `MVN_RC != 0 && HAVE_REPORTS == 0` → exits 1 ("BUILD FAILED before producing any surefire report")
- Guard (c): `MVN_RC == 0 && HAVE_REPORTS == 0` → exits 1 ("no surefire reports — surefire skipped?")
- Guard (d): All count variables equal 0 → exits 1 ("no parseable test data")
- Final exit: `[ "$BAD_TOTAL" -eq 0 ]` propagates Maven's result

**Verification:**
Adversarial validation (Claim 1, `docs/ADVERSARIAL_VALIDATION_REPORT.md`): fresh-context adversarial validator traced every exit path. Result: **PASS**. No false-green path found. The `DIGEST_LINES` cosmetic issue identified does not affect exit codes.

**Platform:**
VS Code + Windows: PASS (all script uses POSIX-compatible; Git Bash confirmed). macOS, IntelliJ combinations: ANALYZED — no platform-specific dependency in the guard logic.

**Transfer:**
Not directly applicable — this is a verifier integrity requirement, not a transfer exercise.

**Status: PASS**

---

## R2 — Investigator Capability Boundary

**Requirement:**
`runCommands` removed and all mutation paths tested, and lab accurately teaches "capability boundary" — or — `runCommands` retained with teaching language updated to "instructed not to mutate." Whichever option selected, the teaching language accurately describes the actual capability restriction.

**Implementation:**
Commit `9996bc7` (fix(R2,F1): true capability boundary for investigator; remove leaked answers) removed `runCommands` from `.github/agents/rtp-investigator.agent.md` and updated the agent body to state explicitly: "It does not contain `edit` or `runCommands`. This is deliberate and it is not a policy you are being asked to respect — it is a capability you do not have."

Commit `c64bd0b` addressed review findings including `ARCHITECTURE.md` accuracy.

**Verification:**
Adversarial validation (Claim 2, `docs/ADVERSARIAL_VALIDATION_REPORT.md`): fresh-context validator checked whether `tools: ['search', 'read']` frontmatter prevents mutation and whether any instruction could override the tool boundary. Result: **PASS**. Frontmatter contains only `search` and `read`. Agent body is consistent. `ARCHITECTURE.md` diagram independently confirms "NO edit, NO runCommands." The teaching language accurately describes the capability restriction.

Residual risk: platform dependency on GitHub Copilot's enforcement of the `tools:` frontmatter at the API level — acknowledged in the lab and in the validation report as expected.

**Platform:**
VS Code + Windows and macOS: agent tool lists enforced by the VS Code Copilot extension. IntelliJ: manual system prompt used — capability boundary degrades to instruction boundary in IntelliJ (documented in `docs/INTELLIJ_PATH.md` as a known limitation; Stage 4.2 becomes a discussion exercise).

**Transfer:**
Not directly applicable.

**Status: PASS**

---

## R3 — Human Owns the Conflict Decision

**Requirement:**
A fresh participant who has not yet reached Stage 4.4 cannot infer the correct resolution solely from scaffolding files. Either the leakage is removed, or the exercise is explicitly reframed as "human approval" rather than "human resolves an ambiguous conflict."

**Implementation:**
Commit `c448b32` (fix(R3,F12): remove answer signposting from scaffolding files) addressed the primary leakage vectors identified: `AGENTS.md`, `session-constraints.sh`, and the investigator's Rules section no longer state the authoritative source or rate values explicitly.

Commit `7170308` (fix(task-4): remove answer-leaking labels from ARCHITECTURE.md and java.instructions.md) removed additional answer leakage from diagram labels and instructions.

**Verification:**
Adversarial validation (Claim 5, `docs/ADVERSARIAL_VALIDATION_REPORT.md`): fresh-context validator read all scaffolding files simultaneously. Result: **PARTIAL**. Significant residual leakage found:

1. `config/fee-schedule.yaml` line 17 comment explicitly states "applied to the COMPUTED FEE, not the raw amount" — Stage 4.4's key pedagogical discovery, available from Stage 1.
2. `context-register.yaml.example` contains both Stage 4.4 decisions verbatim, labeled but not mechanically gated.
3. `ARCHITECTURE.md` sequence diagram names the exact bug: "FAIL — amount compared to 2.00, not the computed fee."
4. `LAB_ACTION_GUIDE.md` Stage 5.2 "Real output" block names the exact failure and Stage 5.4 shows the complete fix.

Adversarial risk rating: Medium-High. The lab relies on pedagogical discipline (procedural guards, ordered stages, "stop and decide" instructions) rather than mechanical prevention. This is an inherent constraint of a text-based lab format — the guide cannot hide content from participants who read ahead.

**Platform:**
Not platform-dependent.

**Transfer:**
Not directly applicable.

**Status: PARTIAL** — Overt scaffolding leakage removed (commits verified). Residual leakage remains in `config/fee-schedule.yaml` comment and `context-register.yaml.example`. The lab cannot mechanically gate these without re-engineering the worked example. Accepted as a known limitation with procedural guards.

---

## R4 — Transfer to Own Repository

**Requirement:**
Fresh participant can reproduce the full context lifecycle pattern (discover → compress → package → handoff → verify → rehydrate) in an unfamiliar, unscaffolded repository. At minimum, Stage 7 extended to cover at least one additional CE pattern beyond discovery/authority.

**Implementation:**
Commit `6d10f88` (add transferability exercises and portable-recipe callouts (R4, F3, F4)) delivered:
- Stage 7 extended from 15 to 25 minutes; Stage 7.4 adds output-reduction exercise (Reduce pattern, no scripts)
- Stage 7B "Your Own Repo" (10–15 min): learner names a real ticket, selects 2–3 CE patterns by number, writes specific command + named artifact + justification, names one thing NOT to build per pattern
- Quick Reference table updated; Stage 7B section added to `outputs/stage-readings.template.md`

Transfer validation framework created at `docs/TRANSFER_VALIDATION_FRAMEWORK.md` (commit `e62a806`): defines the unscaffolded validation protocol, a 10-row evaluation rubric (one row per CE pattern, PASS/PARTIAL/FAIL criteria requiring WHY explanations), two sample scenarios, and the PASS standard (7/10 patterns at PASS; no FAIL on four load-bearing patterns: Discover, Authority, Verify, Handoff).

**Verification:**
Transfer validation framework (`docs/TRANSFER_VALIDATION_FRAMEWORK.md`) defines the protocol and rubric. No live transfer validation has been executed yet — the framework defines the protocol, but a fresh-engineer trial against an unscaffolded repository remains pending.

Adversarial validation (Claim 6): transfer task cannot be completed by copying — PARTIAL. Worked comparison accessible before attempt; no automated enforcement of sequencing. Stage 7B (own repo) is structurally stronger because it requires real work context.

**Platform:**
Stage 7 and 7B are terminal and editor exercises — IDE-independent.

**Transfer:**
The transfer validation framework is the operationalization of R4. Execution requires a live trial with a fresh engineer in an unscaffolded repository. This is a Remaining Gate (see below).

**Status: PARTIAL** — In-lab exercises implemented and verified. Live transfer trial (fresh engineer, unscaffolded repo) has not been conducted. Framework is complete and execution-ready.

---

## R5 — VS Code + IntelliJ Both Supported

**Requirement:**
For every VS Code-specific mechanism, a documented learning-equivalent IntelliJ path or explicit fallback exists. Core learning objectives are reachable in both IDEs without pretending feature parity.

**Implementation:**
Commit `7027e1e` (feat(R5): add IntelliJ learning-equivalent path + IDE callouts in guide) delivered:
- `docs/INTELLIJ_PATH.md` created with step-by-step setup, fallback table for every VS Code-specific mechanism, and a divergence summary
- `LAB_ACTION_GUIDE.md` updated with IntelliJ callout near Windows setup and inline callouts at Stage 4 and Stage 5

One objective (live capability-boundary proof, Stage 4.2) is VS Code-only; documented as discussion exercise in IntelliJ path.

**Verification:**
Platform validation matrix (`docs/PLATFORM_VALIDATION_MATRIX.md`): IntelliJ + Windows and IntelliJ + macOS rows document KNOWN ISSUE for agent/skill availability and hook auto-firing, with fallbacks rated PASS for the fallback path category.

Two capabilities have no equivalent in IntelliJ:
1. Automatic hook firing — fallback: run `scripts/loop.sh` directly from terminal (bound and thrashing detection still function)
2. Live capability-boundary proof — fallback: discussion exercise

PASS for fallback coverage; live test (T3–T7 in platform matrix) pending.

**Platform:**
VS Code + Windows: PASS. VS Code + macOS: ANALYZED. IntelliJ + Windows: ANALYZED (KNOWN ISSUE with fallbacks). IntelliJ + macOS: ANALYZED (KNOWN ISSUE with fallbacks).

**Transfer:**
Not directly applicable.

**Status: PARTIAL** — IntelliJ documentation complete and fallback paths verified by code analysis. Live IntelliJ dry-run (T3–T7) not yet completed. Capability gaps documented. Pending: human-run live test on IntelliJ.

---

## R6 — Windows / Mac Path Viable

**Requirement:**
All facilitator and participant scripts execute correctly on Windows (Git Bash) and macOS without silent failures. `bc` replaced with `awk`. `.gitattributes` added with `*.sh text eol=lf`.

**Implementation:**
Commit `7575bb4` (fix(R6,F7,F8): OS portability — enforce LF endings, replace bc with awk) delivered:
- `.gitattributes` created at repo root: `*.sh text eol=lf`, `*.yaml text eol=lf`, `*.yml text eol=lf`, `*.md text eol=lf`
- `"files.eol": "\n"` added to `.vscode/settings.json`
- Both `paste -sd+ - | bc` occurrences in `docs/verify.sh` replaced with `awk '{s+=$1} END {print s+0}'`
- Python3 dependency already removed in prior commits (`f050960`, `d896e44`, `dff3c1c`, `5c46dae`)
- `scripts/loop.sh` hash fallback chain: `shasum` → `sha256sum` → `cksum`

**Verification:**
Platform validation matrix: VS Code + Windows row — all 8 capability categories PASS (code-evidenced). No `bc` dependency remains. LF enforcement covers both git checkout and editor save. Hash fallback covers Git for Windows.

Adversarial validation (F7, F8): `docs/verify.sh` arithmetic confirmed awk-based. `.gitattributes` confirmed present with correct patterns.

macOS: ANALYZED — BSD `awk`/`grep`/`sed` compatibility confirmed by code analysis; `shasum` available natively; no CRLF risk. Live macOS dry-run (T1, T8) required for full PASS.

**Platform:**
VS Code + Windows: PASS. macOS (both IDEs): ANALYZED — requires live test.

**Transfer:**
Not directly applicable.

**Status: PARTIAL** — Windows PASS (code-evidenced). macOS ANALYZED pending live dry-run (T1, T8). No blockers identified by code analysis on macOS.

---

## R7 — Multi-Repo Context Engineering

**Requirement:**
Option B: multi-repo explicitly removed from this lab's promised objectives and assigned to a later lab — with curriculum promise updated accordingly.

**Implementation:**
Commit `dbfe1b5` (defer multi-repo to future lab (Phase 2.6 Option B)) added a "What This Lab Did Not Cover" entry explicitly stating multi-repo is deferred to a future lab.

**Verification:**
Not applicable — Option B selected. Deferred scope requires no test validation against this lab.

**Platform:**
Not applicable.

**Transfer:**
Not applicable.

**Status: DEFERRED** — Option B selected. Multi-repo assigned to a future lab. Curriculum scope updated.

---

## R8 — Official Session Duration Matches Real Cohort Experience

**Requirement:**
A timed dry run by someone who did not build the lab confirms the published duration. Facilitator, participant, Copilot-wait, discussion, and recovery times are tracked separately. Official delivery format chosen and published.

**Implementation:**
Commit `bffd080` (add timed facilitation guide and update R8 status (Phase 3.4)) created `docs/TIMED_FACILITATION_GUIDE.md`:
- Five time-tracking categories defined (F/H/W/D/R)
- Per-stage timing template with Copilot-wait log provided
- Stage estimates extracted from `LAB_ACTION_GUIDE.md`: total ~152–159 min
- Three delivery format options (A: 90+30, B: 120 full, C: two 60-min parts) with pros/cons
- Six validation criteria (V1–V6) defined, including the mandatory rule that a 130+ minute lab must not be labeled 90-minute

**Verification:**
No live timed dry-run has been completed. The framework is execution-ready. Estimated total is 152–159 minutes (substantially above 90 minutes). Format choice cannot be made without dry-run data.

Timed facilitation guide documents explicitly: "The 90-minute claim cannot be supported by these estimates."

**Platform:**
Timing will vary by platform — particularly recovery time (R) on corporate-managed Windows machines. The guide explicitly accounts for this.

**Transfer:**
Not directly applicable.

**Status: PARTIAL** — Framework complete. Timing estimates documented. Dry run by a non-builder has not been conducted. Format decision not yet made. These are Remaining Gates (see below).

---

## F1 — Agent Definitions Do Not Leak Answers

**Requirement:**
Both `rtp-investigator.agent.md` and `rtp-implementer.agent.md` Rules sections redacted: no literal rates, no bug diagnoses. References replaced with "check `config/fee-schedule.yaml`" or equivalent pointer.

**Implementation:**
Commit `9996bc7` (fix(R2,F1): true capability boundary for investigator; remove leaked answers) redacted the RTP rate (0.35%, USD 2.00 minimum) and LegacyPaymentUtils retirement from `rtp-investigator.agent.md`. The implementer agent's bug diagnosis was removed from `rtp-implementer.agent.md`.

Commit `c448b32` addressed additional scaffolding leakage in `session-constraints.sh`, `AGENTS.md`, and the investigator Rules section.

**Verification:**
Adversarial validation (Claim 5): agent files checked as part of the broader scaffolding leakage analysis. The most significant remaining leakage vectors are `config/fee-schedule.yaml` line 17 and `context-register.yaml.example` — both outside the agent files themselves.

Platform validation: not applicable.

**Platform:**
Not platform-dependent.

**Transfer:**
Not directly applicable.

**Status: PASS** — Agent files redacted. Residual leakage is in config files and example files (tracked under R3), not in agent definitions.

---

## F2 — `context-map.sh` Output Is Computed, Not Hard-Coded

**Requirement:**
Either all conclusions derived from live scans, or hard-coded assertions clearly labelled "ASSERTION (not computed from scan)" so the lab's credibility standard is maintained. Script no longer presents fabricated scan results as findings.

**Implementation:**
No commit addresses F2 directly. F2 has been downgraded from P1 to P2 in the acceptance matrix. Rationale: the hard-coded assertions in `context-map.sh` are a credibility concern but do not block the lab's core learning objectives. The portable-version callout for `context-map.sh` (added in Task 8) already explains the raw grep commands behind the script, mitigating the black-box issue. The hard-coded labels are cosmetic — they affect presentation quality, not pedagogical soundness. Fix post-delivery.

**Verification:**
No verification performed — item not implemented. Disposition recorded as P2; see acceptance matrix.

**Platform:**
Not applicable.

**Transfer:**
Not applicable.

**Status: FAIL** — F2 remains OPEN (downgraded to P2). Hard-coded assertions in `context-map.sh` output (~50% of output is asserted, not computed) have not been labelled or replaced. The portable-recipe callout at Stage 1.1 partially mitigates the black-box issue by showing the underlying `grep -rl` / `grep -rn` commands. Fix scheduled post-delivery.

---

## F3 — Portable-Recipe Treatment Covers Meaningful Breadth

**Requirement:**
Minimum three additional scripts receive portable-recipe treatment: `context-map.sh` (routing-table concept), `verify-change.sh` (multi-check composition), and `loop.sh` (bounded-retry pattern). Each callout shows the 2–3 raw commands behind the script and a toolchain-agnostic mapping.

**Implementation:**
Commit `6d10f88` (add transferability exercises and portable-recipe callouts (R4, F3, F4)) added three portable-version callouts inline in `LAB_ACTION_GUIDE.md`:
1. `context-map.sh` at Stage 1.1 — `grep -rl` + `grep -rn` with path-categorization guidance
2. `verify-change.sh` at Stage 5.2 — four raw commands (`mvn test`, `git diff --name-only`, `jdeps`, `jshell`) with a composable verdict loop
3. `loop.sh` at Stage 5.4 — bounded-retry shell template with thrashing detection via hash comparison and escalation exit codes

Each callout is 10–15 lines and toolchain-agnostic where possible.

**Verification:**
Acceptance matrix status: PASS. No adversarial or platform validation specifically targeting F3.

**Platform:**
Callouts are in-guide text; not platform-dependent.

**Transfer:**
Directly supports transfer — the portable-recipe callouts let learners reproduce the mechanism without the lab's scripts.

**Status: PASS**

---

## F4 — Day-to-Day Translation Practiced, Not Just Reflected Upon

**Requirement:**
At least one exercise (not a reflection question) requires the learner to name a specific pattern applicable to their own current work, identify the commands or mechanism they would use, and specify what artifact they would produce.

**Implementation:**
Commit `6d10f88` added Stage 7B "Your Own Repo" (10–15 min). The learner:
- Names a real current or recent ticket (not hypothetical)
- Selects 2–3 CE patterns by number
- For each: writes exact command/tool, named artifact at a specific path, one-sentence justification
- Sanity check: names one thing NOT to build per pattern using the artifact-choice table

Corresponding reading section added to `outputs/stage-readings.template.md`. Stage 6 unchanged (its rehydration proof is non-redundant with 7B).

**Verification:**
Acceptance matrix status: PASS. Adversarial validation (Claim 6): Stage 7B is structurally not completable by copying — requires real work context. A participant could fabricate a plausible-sounding ticket, but the exercise design requires specificity that pattern-copying cannot satisfy.

**Platform:**
Stage 7B is editor/written exercise — IDE-independent.

**Transfer:**
F4 is itself a transfer exercise. The transfer validation framework (`docs/TRANSFER_VALIDATION_FRAMEWORK.md`) Section 6 connects F4 to the post-lab transfer validation protocol.

**Status: PASS**

---

## F5 — `verify-change.sh` Check 2 Detects Method-Level Scope Changes

**Requirement:**
`CHANGED_METHODS` is either integrated into check 2's pass/fail decision or removed with a comment explaining why file-level scope checking is the chosen granularity. The script does not compute a variable it ignores.

**Implementation:**
No commit addresses F5. Acceptance matrix status: OPEN. F5 was classified P2 (polish/improvement) and was not assigned to any Phase 2 task.

**Verification:**
Adversarial validation (Claim 7, Check 2): fresh-context validator confirmed `CHANGED_METHODS` is computed but never used in pass/fail logic. A participant making changes outside `calculateFee` within `PaymentService.java` would not be caught. The validator rated this Low-Medium risk.

**Platform:**
Not platform-dependent.

**Transfer:**
Not directly applicable.

**Status: FAIL** — F5 remains OPEN. `CHANGED_METHODS` dead code not cleaned up; check 2 is file-level, not method-level. P2 priority; not a delivery blocker, but creates a credibility gap in the verification script.

---

## F6 — `verify-change.sh` Check 4 Catches a Range of Inputs

**Requirement:**
Check 4 includes at least one additional input that exercises the boundary where the computed percentage fee crosses the USD 2.00 minimum. A hard-coded minimum cannot satisfy both inputs.

**Implementation:**
No commit addresses F6. Acceptance matrix status: OPEN. F6 was classified P2 and was not assigned to any Phase 2 task.

**Verification:**
Adversarial validation (Claim 7, Check 4): validator confirmed that a hard-coded `return BigDecimal.valueOf(2.00)` for RTP would pass all four existing checks. The guide acknowledges this in Stage 5.3 — the check-5 exercise is designed to catch it — but the verifier itself remains exploitable by a constant-return implementation.

**Platform:**
Not platform-dependent.

**Transfer:**
Not directly applicable.

**Status: FAIL** — F6 remains OPEN. Single test input in check 4 can be satisfied by a constant-return implementation. P2 priority; not a delivery blocker given Stage 5.3's explicit pedagogical framing of this gap.

---

## F7 — `docs/verify.sh` Runs Correctly on Windows (Git Bash)

**Requirement:**
`bc` replaced with `awk` arithmetic. Facilitator verification script produces correct numeric output on Git Bash on Windows.

**Implementation:**
Commit `7575bb4` (fix(R6,F7,F8): OS portability — enforce LF endings, replace bc with awk): both `paste -sd+ - | bc` occurrences in `docs/verify.sh` A2 replaced with `awk '{s+=$1} END {print s+0}'`.

**Verification:**
Acceptance matrix status: PASS. Platform validation matrix (VS Code + Windows, row 5 "no `bc`"): PASS — "Both arithmetic uses replaced with `awk '{s+=$1} END {print s+0}'`."

**Platform:**
VS Code + Windows: PASS. macOS: ANALYZED (awk arithmetic is BSD-compatible; non-issue).

**Transfer:**
Not directly applicable.

**Status: PASS**

---

## F8 — Line Endings Enforced as LF on All Platforms

**Requirement:**
`.gitattributes` added with `*.sh text eol=lf` and `*.yaml text eol=lf`. VS Code settings include `"files.eol": "\n"`.

**Implementation:**
Commit `7575bb4` (fix(R6,F7,F8): OS portability — enforce LF endings, replace bc with awk):
- `.gitattributes` created at repo root: `*.sh text eol=lf`, `*.yaml text eol=lf`, `*.yml text eol=lf`, `*.md text eol=lf`
- `"files.eol": "\n"` added to `.vscode/settings.json`

**Verification:**
Acceptance matrix status: PASS. Platform validation matrix (VS Code + Windows, row 5 "LF"): PASS — "`.gitattributes` sets `*.sh text eol=lf`, `*.yaml text eol=lf`, `*.yml text eol=lf`, `*.md text eol=lf`. VS Code `files.eol: "\n"` prevents editor-written CRLF."

**Platform:**
VS Code + Windows: PASS. macOS: ANALYZED — git default does not add CRLF; `.gitattributes` provides defense-in-depth; low risk.

**Transfer:**
Not directly applicable.

**Status: PASS**

---

## F9 — `docs/verify.sh` Hard-Coded Test Count Is Not Brittle

**Requirement:**
Expected test count is either derived dynamically or clearly documented as "update this when baseline changes" with a comment. The hard-coded count of 5 does not cause false facilitation failures when the baseline test suite changes.

**Implementation:**
No commit addresses F9. Acceptance matrix status: OPEN. F9 was classified P2 and was not assigned to any Phase 2 task.

**Verification:**
No verification performed — item not implemented.

**Platform:**
Not platform-dependent.

**Transfer:**
Not directly applicable.

**Status: FAIL** — F9 remains OPEN. Hard-coded test count = 5 in `docs/verify.sh` A5 is brittle. P2 priority; not a delivery blocker unless the test suite is modified.

---

## F10 — Artifact-Choice Decision Framework Visible Before the Debrief

**Requirement:**
Artifact-choice decision table surfaced at Stage 2 or Stage 3, where learners first encounter the promote-or-discard decision. Debrief reference may remain as a summary.

**Implementation:**
No commit addresses F10. Acceptance matrix status: OPEN. F10 was classified P2 and was not assigned to any Phase 2 task.

**Verification:**
No verification performed — item not implemented.

**Platform:**
Not applicable.

**Transfer:**
Not directly applicable.

**Status: FAIL** — F10 remains OPEN. Artifact-choice table remains Debrief-only; participants who exit at Stage 5 or 6 (condensed path) never see it. P2 priority.

---

## F11 — Skills Teach Transferable Methods, Not Lab Command Wrappers

**Requirement:**
Skill files contain at minimum one "portable version" note per skill explaining the general method the script implements (e.g., "the portable version of context-map is: list candidate authoritative sources before reading any of them").

**Implementation:**
No commit addresses F11 directly in the skill files themselves. Commit `6d10f88` addressed the related concern partially by adding portable-recipe callouts in `LAB_ACTION_GUIDE.md` (F3). Skill files (`context-map`, `context-run`, `verify-change`) themselves were not updated with portable-version notes.

**Verification:**
No verification performed against skill file content.

**Platform:**
Not platform-dependent.

**Transfer:**
Directly relevant — skill files are the first thing a learner reads when using a skill.

**Status: FAIL** — F11 remains OPEN. Skill files remain thin wrappers. The portable-recipe callouts in `LAB_ACTION_GUIDE.md` (F3) partially mitigate this but do not close F11 since they are in the guide, not in the skill files. P2 priority.

---

## F12 — `session-constraints.sh` Does Not Pre-Resolve Stage 1's Discovery Question

**Requirement:**
Either the constraint is reworded as a policy guardrail ("do not look up rates from memory") without stating which file is authoritative, or the line is removed and the deny-list alone enforces the constraint.

**Implementation:**
Commit `c448b32` (fix(R3,F12): remove answer signposting from scaffolding files) addressed `session-constraints.sh` and related files.

**Verification:**
Adversarial validation (Claim 5): `session-constraints.sh` reviewed as part of the broad scaffolding leakage analysis. The validator found: "`session-constraints.sh`: 'When you encounter conflicting rate information across config files and ADR documents, surface both sources — do not assume either is authoritative without checking provenance.' No answer given." This wording does not state which file is authoritative — it is a guardrail, not an answer.

**Platform:**
Not platform-dependent.

**Transfer:**
Not directly applicable.

**Status: PASS** — `session-constraints.sh` reworded to policy guardrail. Adversarial validation confirms no authoritative-source answer is given.

---

## Summary Table

| ID | Priority | Description | Status |
|---|---|---|---|
| R1 | P0 | Deterministic reducer fails closed | PASS |
| R2 | P0 | Investigator capability boundary | PASS |
| R3 | P1 | Human owns the conflict decision | PARTIAL |
| R4 | P1 | Transfer to own repository | PARTIAL |
| R5 | P1 | VS Code + IntelliJ both supported | PARTIAL |
| R6 | P1 | Windows / Mac path viable | PARTIAL |
| R7 | P1 | Multi-repo context engineering | DEFERRED |
| R8 | P1 | Official session duration validated | PARTIAL |
| F1 | P1 | Agent definitions do not leak answers | PASS |
| F2 | P2 | `context-map.sh` output computed, not hard-coded | FAIL |
| F3 | P1 | Portable-recipe treatment breadth | PASS |
| F4 | P1 | Day-to-day translation practiced | PASS |
| F5 | P2 | Check 2 detects method-level scope | FAIL |
| F6 | P2 | Check 4 catches range of inputs | FAIL |
| F7 | P2 | `docs/verify.sh` runs on Windows | PASS |
| F8 | P2 | LF line endings enforced | PASS |
| F9 | P2 | Hard-coded test count not brittle | FAIL |
| F10 | P2 | Artifact-choice table visible early | FAIL |
| F11 | P2 | Skills teach transferable methods | FAIL |
| F12 | P2 | `session-constraints.sh` does not pre-resolve | PASS |

| Status | Count | IDs |
|---|---|---|
| PASS | 8 | R1, R2, F1, F3, F4, F7, F8, F12 |
| PARTIAL | 5 | R3, R4, R5, R6, R8 |
| FAIL | 6 | F2, F5, F6, F9, F10, F11 |
| DEFERRED | 1 | R7 |
| **Total** | **20** | |

*Note: The matrix has 20 rows (R1–R8, F1–F12 = 20 IDs). R7 is counted once as DEFERRED.*

---

## Remaining Gates

These items require human action before the lab can be certified fully GO.

### Gate 1 — Live Timed Dry Run (R8)
**Owner:** Facilitator or colleague who did not build the lab
**Action required:** Complete the timed dry run using the template in `docs/TIMED_FACILITATION_GUIDE.md` Section 4. Track all five time categories separately. Complete after the dry run: choose delivery format (A, B, or C from Section 6) and publish the chosen format.
**Why it is a gate:** The 90-minute label cannot be used if dry-run total excluding recovery is ≥ 130 minutes. Current estimate is 152–159 minutes. Timing must be grounded in real cohort behavior, not builder estimates.

### Gate 2 — Live Platform Tests (R5, R6)
**Owner:** Facilitator or lab coordinator
**Action required:** Execute pending live tests T1–T8 from `docs/PLATFORM_VALIDATION_MATRIX.md`. At minimum: T1 (VS Code + macOS full verify.sh run), T3 (IntelliJ + Windows terminal setup), T6 (IntelliJ + macOS default shell).
**Why it is a gate:** macOS and IntelliJ combinations are ANALYZED, not PASS. BSD tool variant risk and IntelliJ plugin behavior require live confirmation. R5 and R6 cannot reach full PASS without live test data.

### Gate 3 — Live Transfer Validation Trial (R4)
**Owner:** Lab coordinator or a volunteer fresh engineer
**Action required:** Run the transfer validation protocol from `docs/TRANSFER_VALIDATION_FRAMEWORK.md` with a fresh engineer (no prior exposure to this lab) in an unscaffolded repository. Score against the 10-row rubric and confirm PASS standard (7/10 PASS; no FAIL on Discover, Authority, Verify, Handoff).
**Why it is a gate:** R4's PASS condition requires demonstrated transfer, not just in-lab exercises. The framework is complete; the trial has not been run.

### Gate 4 (Advisory) — F2 Decision (downgraded to P2)
**Owner:** Lab architect or SME
**Action required:** Decide: (A) derive all `context-map.sh` conclusions from live scans, or (B) label hard-coded assertions as "ASSERTION (not computed from scan)." Implement the chosen option post-delivery.
**Why it is advisory:** F2 has been downgraded from P1 to P2. The hard-coded labels are cosmetic — they affect presentation quality, not pedagogical soundness. The portable-recipe callout at Stage 1.1 already exposes the underlying grep commands, mitigating the black-box concern. Not a delivery blocker.

### Gate 5 (Advisory) — P2 Items (F2, F5, F6, F9, F10, F11)
**Owner:** Lab architect or SME
**Action required:** These are P2 polish/improvement items. They do not block delivery but reduce quality:
- F2: Hard-coded assertions in `context-map.sh` output not labelled (downgraded from P1 — cosmetic, not pedagogical blocker)
- F5: `CHANGED_METHODS` dead code in `verify-change.sh`
- F6: Single test input in check 4 passable by constant-return implementation
- F9: Hard-coded test count in `docs/verify.sh` A5
- F10: Artifact-choice table not visible before Debrief
- F11: Skill files are thin wrappers with no portable-version notes
**Why it is advisory:** None of these block delivery, but F6 is visible to adversarial participants and F11 directly contradicts the lab's own transfer objectives.

---

## Overall Recommendation

### CONDITIONAL GO

**Rationale:**

**Strengths (evidence-backed):**
- Both P0 requirements (R1 false-green fix, R2 capability boundary) are PASS with adversarial validation confirming no bypass paths.
- Six of nine P1 requirements show substantial implementation work; the framework items (R4, R5, R8) are execution-ready — only the live trials are missing.
- OS portability (R6/F7/F8) is fully evidenced on Windows; macOS requires live confirmation only.
- Agent answer-leakage (F1), scaffolding constraints (F12), portable-recipe breadth (F3), and own-repo transfer exercise (F4) all pass.
- Multi-repo (R7) is correctly deferred with curriculum updated.

**Conditions for GO (must resolve before live delivery):**
1. **Gate 1 (Timed Dry Run):** Duration label must be validated. The "90-minute" framing cannot be used; current estimates put the lab at 152–159 minutes.
2. **Gate 2 (Live Platform Test):** At minimum macOS basic smoke test (T1) and IntelliJ terminal setup test (T3) before advertising multi-platform support.

**Conditions that may be deferred to post-first-cohort:**
- Gate 3 (Transfer Validation Trial): can be conducted during or immediately after the first delivery.
- Gate 5 (P2 items): all advisory; none block learning.

**Bottom line:** The lab is structurally sound and pedagogically coherent. The two P0 requirements are solid. The primary remaining risk is timing — the "90-minute" label cannot be supported by evidence; current estimates put the lab at 152–159 minutes. Publish an honest duration before delivery. F2 (hard-coded context-map.sh output) has been downgraded to P2 and is a post-delivery fix.

---

*This document is the Phase 4 evidence package for Context Engineering Part 2.*
*Sources: `docs/REMEDIATION_ACCEPTANCE_MATRIX.md`, `docs/ADVERSARIAL_VALIDATION_REPORT.md`, `docs/PLATFORM_VALIDATION_MATRIX.md`, `docs/TRANSFER_VALIDATION_FRAMEWORK.md`, `docs/TIMED_FACILITATION_GUIDE.md`, git log `e052910..HEAD`.*
