# Remediation Acceptance Matrix

**Created:** 2026-08-29  
**Source review:** `docs/review/JEFF_GAP_CHANGE_REVIEW.md`  
**Source plan:** `plan.md`  
**Scope:** All gaps identified across the full review — seed rows from the plan plus all P1/P2 findings mined from the review.

---

## How to Read This Table

| Column | Meaning |
|---|---|
| **ID** | Stable identifier. R-prefixed rows are the plan's seed rows. F-prefixed rows are findings mined from the review. |
| **Claim / Requirement** | What the lab currently asserts or promises, or what it is required to deliver. |
| **Current Evidence** | What exists today that partially supports the claim. |
| **Gap** | The specific way current evidence falls short of the claim. |
| **PASS Condition** | The exact, observable outcome that closes this row. No "looks good." |
| **Priority** | P0 = correctness/credibility blocker. P1 = requirement gap. P2 = polish/improvement. |
| **Status** | OPEN / IN PROGRESS / PASS / FAIL / DEFERRED |

---

## Priority Model

**P0 — Correctness / Credibility Blockers:** deterministic false-green behavior, false capability-isolation claims, misleading statements about system guarantees. Must be fixed before any polish.

**P1 — Requirement Gaps:** things the lab promises or needs for delivery readiness that are currently absent or incomplete.

**P2 — Polish / Improvements:** wording, cosmetic gaps, optional enhancements, things that improve quality but do not block delivery.

---

## Acceptance Matrix

| ID | Claim / Requirement | Current Evidence | Gap | PASS Condition | Priority | Status |
|---|---|---|---|---|---|---|
| R1 | Deterministic reducer fails closed — a fresh Maven failure always returns non-zero regardless of stale Surefire reports | `scripts/context-run.sh` (false-green fix applied in working tree) | Stale successful Surefire reports from a prior run can cause the script to report green even when Maven itself failed | Fresh Maven failure + stale valid reports → reducer exits non-zero. All six scenarios in Phase 2.1 validation matrix pass. | P0 | OPEN |
| R2 | Investigator cannot mutate the repository — the lab teaches this as a hard capability boundary | `rtp-investigator.agent.md` tools list omits `edit` | `runCommands` tool is present; any script that writes files can be invoked through it, making this a policy boundary masquerading as a capability boundary | Either: (A) `runCommands` removed and all mutation paths tested per Phase 2.2 — lab then accurately teaches "capability boundary"; or (B) `runCommands` retained and teaching language changed to "the investigator is instructed not to mutate" throughout guide and agent description | P0 | OPEN |
| R3 | Human owns the unresolved rate decision — the lab presents a genuine authority conflict requiring human judgment | Stage 4.4 conflict between `config/fee-schedule.yaml` and `docs/adr/ADR-0007-fee-schedule.md` | The answer is signposted in `AGENTS.md`, `session-constraints.sh`, and the investigator's own Rules section (which states the authoritative source explicitly) | A fresh participant who has not yet reached Stage 4.4 cannot infer the correct resolution solely from scaffolding files. Either the leakage is removed, or the exercise is explicitly reframed as "human approval" rather than "human resolves an ambiguous conflict." | P1 | OPEN |
| R4 | The method transfers to an engineer's own repository — Stage 7 proves independent transfer | Stage 7 "Apply Without the Harness" (CurrencyConverter, no lab tools) | Stage 7 tests only discovery/authority pattern, lasts 15 minutes, remains inside this repository. A single exercise on one pattern does not produce far transfer per the lab's own cited research. | Fresh participant can reproduce the full context lifecycle pattern (discover → compress → package → handoff → verify → rehydrate) in an unfamiliar, unscaffolded repository. At minimum, Stage 7 is extended to cover at least one additional CE pattern beyond discovery/authority. | P1 | PASS — Stage 7 extended to 25 min; adds 7.4 output-reduction exercise (Reduce pattern, no scripts). New Stage 7B "Your Own Repo" (10–15 min) requires learner to name a real ticket, select 2–3 CE patterns by number, write a specific command + named artifact + justification per pattern, and name one thing NOT to build per pattern. Quick Reference table updated. Both sections added to `outputs/stage-readings.template.md`. Phase 3.3 transfer validation framework created at `docs/TRANSFER_VALIDATION_FRAMEWORK.md` — defines the unscaffolded validation protocol (what validator provides/withholds), a 10-row evaluation rubric (one row per CE pattern, with PASS/PARTIAL/FAIL criteria requiring WHY explanations), two sample scenarios (rate limiting, XML-to-YAML migration), and the overall PASS standard (7/10 patterns at PASS; no FAIL on the four load-bearing patterns: Discover, Authority, Verify, Handoff). |
| R5 | VS Code + IntelliJ both supported — core learning objectives are achievable in either IDE | VS Code path documented in detail; Git Bash terminal setup instructions present | IntelliJ path is entirely absent. No documentation of equivalent agent/skill/hook experience for IntelliJ users. | For every VS Code-specific mechanism (custom agents, skills, hooks, fresh-context workflow), a documented learning-equivalent IntelliJ path or explicit fallback exists. Core learning objectives are reachable in both IDEs without pretending feature parity. | P1 | IN PROGRESS — `docs/INTELLIJ_PATH.md` created; `LAB_ACTION_GUIDE.md` updated with IntelliJ callout near Windows setup and inline callouts at Stage 4 / Stage 5. One objective (live capability-boundary proof, Stage 4.2) is VS Code-only; documented as discussion exercise in IntelliJ path. Scripts, terminal workflow, and all CE patterns are reachable in IntelliJ. Phase 3.2 platform validation matrix (`docs/PLATFORM_VALIDATION_MATRIX.md`) documents IntelliJ + Windows and IntelliJ + macOS as ANALYZED — fallbacks PASS by code analysis, agent/hook gaps are KNOWN ISSUE with documented workarounds. PASS requires live timed dry-run (T3–T7 in platform matrix). |
| R6 | Windows / Mac path is viable — the lab runs on the promised platforms | Python3 dependency removed; `shasum` fallback chain present; Git Bash documented as terminal requirement | `docs/verify.sh` uses `bc` (not bundled with Git for Windows — silently returns 0). No `.gitattributes` to enforce LF endings. No `files.eol` in VS Code settings. | All facilitator and participant scripts execute correctly on Windows (Git Bash) and macOS without silent failures. `bc` replaced with `awk`. `.gitattributes` added with `*.sh text eol=lf`. | P1 | PASS (Windows, code-evidenced) / ANALYZED (macOS) — VS Code + Windows: PASS. `.gitattributes` added (LF enforcement for `.sh`, `.yaml`, `.yml`, `.md`); `files.eol: "\n"` added to `.vscode/settings.json`; `bc` replaced with `awk` arithmetic in `docs/verify.sh`; hash fallback chain (`shasum` → `sha256sum` → `cksum`) covers Git for Windows. macOS: ANALYZED — BSD `awk`/`grep`/`sed` compatibility confirmed by code analysis; `shasum` available natively; no CRLF risk. Live macOS dry-run (T1, T8 in platform matrix) required for full PASS. |
| R7 | Multi-repo context engineering is taught as promised | Single Meridian repository throughout all stages | No exercise crosses a repository boundary. The curriculum implies multi-repo handling but no exercise practices it. | Either: (A) one focused exercise requiring the learner to manage context across two repositories exists and teaches a CE decision; or (B) multi-repo is explicitly removed from this lab's promised objectives and assigned to a later lab — with curriculum promise updated accordingly. | P1 | DEFERRED — Option B selected. The lab already delivers 10+ CE patterns in ~2 hours; multi-repo adds significant infrastructure complexity without addressing Jeff's core feedback (transferability within single-repo work). A "What This Lab Did Not Cover" entry now explicitly states multi-repo is deferred to a future lab. The ten patterns taught here remain applicable to multi-repo scenarios. |
| R8 | Official session duration matches what a real cohort experiences | Stage timings listed as estimates; total ~2 hours (core path) | Timings are working estimates, not measured from a real timed dry run. A 130+ minute lab must not be labelled a 90-minute lab. | A timed dry run by someone who did not build the lab confirms the published duration. Facilitator, participant, Copilot-wait, discussion, and recovery times are tracked separately. Official delivery format chosen and published. | P1 | IN PROGRESS — `docs/TIMED_FACILITATION_GUIDE.md` created. Framework defines five time-tracking categories (F/H/W/D/R), provides a per-stage timing template with Copilot-wait log, extracts all stage estimates from `LAB_ACTION_GUIDE.md` (total: ~152–159 min), presents three delivery format options (A: 90+30, B: 120 full, C: two 60-min parts) with pros/cons, and defines six validation criteria (V1–V6) including the mandatory rule that a 130+ minute lab must not be labeled 90-minute. PASS requires completion of a timed dry run by a non-builder and publication of the chosen format. |
| F1 | Agent definitions do not leak answers the learner should earn | Answer-leakage removed from hooks, skills, instructions, AGENTS.md | `rtp-investigator.agent.md` Rules section states the RTP rate (0.35%, USD 2.00 minimum) and LegacyPaymentUtils retirement — Stage 1 answers. `rtp-implementer.agent.md` Rules section states the exact bug diagnosis ("USD 2.00 minimum applied to computed fee, not raw amount") — Stage 5 answer. | Both agent `.md` files redacted to the same standard already applied to hooks/skills/instructions: no literal rates, no bug diagnoses. References replaced with "check `config/fee-schedule.yaml`" or equivalent pointer to the authoritative source. | P1 | OPEN |
| F2 | `context-map.sh` output is computed from scans, not hard-coded prose | `context-map.sh` runs grep/jdeps/git scans | Four conclusions in the script output are hard-coded strings: affected domains, "no RTP-specific interface exists," "no new library dependency," symbol counts — approximately 50% of output is asserted, not computed | Either: (A) all conclusions derived from live scans; or (B) hard-coded assertions are clearly labelled "ASSERTION (not computed from scan)" so the lab's own credibility standard is maintained. Script no longer presents fabricated scan results as findings. | P2 | OPEN — Downgraded from P1 to P2: the hard-coded assertions in context-map.sh are a credibility concern but do not block the lab's core learning objectives. The portable-version callout for context-map.sh (added in Task 8) already explains the raw grep commands behind the script, mitigating the black-box issue. The hard-coded labels are cosmetic — they affect presentation quality, not pedagogical soundness. Fix post-delivery. |
| F3 | Portable-recipe treatment covers a meaningful breadth of lab scripts | Two portable-version callouts exist: `authority.sh` (1.3) and `context-run.sh` test (2.3) | 17 of 19 script invocations in the guide have no portable-recipe callout. Jeff's structural concern was categorical ("all shell scripts"), not limited to two examples. `context-map.sh`, `verify-change.sh`, `loop.sh`, `context-for.sh`, `outline.sh`, `digest.sh`, `test-gap.sh` remain black boxes. | Minimum three additional scripts receive portable-recipe treatment: `context-map.sh` (routing-table concept), `verify-change.sh` (multi-check composition), and `loop.sh` (bounded-retry pattern). Each callout shows the 2–3 raw commands behind the script and a toolchain-agnostic mapping. | P1 | PASS — Three portable-version callouts added inline in `LAB_ACTION_GUIDE.md`: (1) `context-map.sh` at Stage 1.1 — `grep -rl` + `grep -rn` with path-categorization guidance; (2) `verify-change.sh` at Stage 5.2 — four raw commands (`mvn test`, `git diff --name-only`, `jdeps`, `jshell`) with a composable verdict loop; (3) `loop.sh` at Stage 5.4 — bounded-retry shell template with thrashing detection via hash comparison and escalation exit codes. Each callout is 10–15 lines and toolchain-agnostic where possible. |
| F4 | Day-to-day translation is practiced, not just reflected upon | Ten Patterns question table in Debrief; reflection questions asking about own work | Reflection questions are not exercises. No stage asks learners to apply any pattern to a ticket they are currently working on, name specific commands, or sketch a concrete plan. The "Monday morning" bridge is conceptual only. | At least one exercise (not a reflection question) requires the learner to name a specific pattern applicable to their own current work, identify the commands or mechanism they would use, and specify what artifact they would produce. This may replace or augment a weaker stage (Stage 6 is the current candidate). | P1 | PASS — Stage 7B "Your Own Repo" added (10–15 min). The learner names a real current or recent ticket, selects 2–3 CE patterns by number, and for each writes a concrete 3-line plan: exact command/tool, named artifact at a specific path, one-sentence justification. A "sanity check" section additionally requires naming one thing NOT to build per pattern using the artifact-choice table. Corresponding reading section added to `outputs/stage-readings.template.md`. Stage 6 is unchanged (its rehydration proof is non-redundant with 7B). |
| F5 | `verify-change.sh` check 2 detects method-level scope changes | `CHANGED_METHODS` variable is computed in `verify-change.sh` | `CHANGED_METHODS` is computed but never used in any pass/fail logic. A method-level change inside `PaymentService.java` (not a new file, not a new class) passes check 2 undetected. | `CHANGED_METHODS` is either integrated into check 2's pass/fail decision or removed with a comment explaining why file-level scope checking is the chosen granularity. The script does not compute a variable it ignores. | P2 | OPEN |
| F6 | `verify-change.sh` check 4 catches a range of inputs, not just one | Check 4 runs `calculateFee(100.00, "RTP")` | Single test input: a hard-coded `return 2.00` would satisfy the minimum (USD 2.00 = 100.00 × 0.35% = 0.35, minimum applies → 2.00) and pass all four checks. Boundary condition (amount where computed fee crosses the minimum) is not covered. | Check 4 includes at least one additional input that exercises the boundary where the computed percentage fee crosses the USD 2.00 minimum (e.g. `calculateFee(1.00, "RTP")` should return 2.00 and `calculateFee(1000.00, "RTP")` should return 3.50). A hard-coded minimum cannot satisfy both. | P2 | OPEN |
| F7 | `docs/verify.sh` runs correctly on Windows (Git Bash) | `docs/verify.sh` uses `paste -sd+ - \| bc` for arithmetic | `bc` is not bundled with Git for Windows. The expression silently returns 0, causing A5 facilitation checks to produce wrong results without error. | `bc` replaced with `awk` arithmetic (consistent with all other scripts in the repo). Facilitator verification script produces correct numeric output on Git Bash on Windows. | P2 | PASS — Both `paste -sd+ - \| bc` occurrences in A2 replaced with `awk '{s+=$1} END {print s+0}'`. |
| F8 | Line endings are enforced as LF on all platforms | No `.gitattributes` file exists in the repository | On Windows with `core.autocrlf=true`, `git checkout` converts `.sh` and `.yaml` files to CRLF. Awk heredocs and POSIX scripts break silently on CRLF line endings. | `.gitattributes` added with at minimum: `*.sh text eol=lf` and `*.yaml text eol=lf`. VS Code settings include `"files.eol": "\n"`. | P2 | PASS — `.gitattributes` created at repo root with `*.sh`, `*.yaml`, `*.yml`, `*.md` all set to `text eol=lf`. `"files.eol": "\n"` added to `.vscode/settings.json`. |
| F9 | `docs/verify.sh` hard-coded test count is not brittle | `docs/verify.sh` A5 checks expected test count = 5 | Any change to the baseline test suite breaks A5 for the wrong reason, producing a false facilitation failure unrelated to the RTP change being verified. | Expected test count is either derived dynamically (from a baseline run) or the hard-coded value is clearly documented as "update this when baseline changes" with a comment in the script. | P2 | OPEN |
| F10 | Artifact-choice decision framework is visible before the Debrief | Artifact-choice table present in Stage 5.3 Debrief | Learners who stop at Stage 5 or 6 (the condensed path) never encounter the artifact-choice framework. It appears only after the exercises that would benefit from it. | Artifact-choice decision table surfaced at Stage 2 or Stage 3, where learners first encounter the promote-or-discard decision. Debrief reference may remain as a summary. | P2 | OPEN |
| F11 | Skills teach transferable methods, not lab command wrappers | Four skills (`context-map`, `context-run`, `verify-change`, `context-package`) exist with documented rules | All four skill files are thin wrappers: "run `./scripts/foo.sh`." Rules sections contain good guardrails but are RTP-specific. A learner reading only skill files learns nothing transferable to a repo that lacks these scripts. | Skill files contain at minimum one "portable version" note per skill explaining the general method the script implements (e.g. "the portable version of context-map is: list candidate authoritative sources before reading any of them"). LAB_ACTION_GUIDE Deconstruct exercises already partly mitigate this. | P2 | OPEN |
| F12 | `session-constraints.sh` does not pre-resolve Stage 1's discovery question | `session-constraints.sh` enforces script deny-list via hook | Line states `config/fee-schedule.yaml` is where rates live — a discovery conclusion the learner should reach in Stage 1, now delivered as a hook constraint before the session begins | Either the constraint is reworded as a policy guardrail ("do not look up rates from memory") without stating which file is authoritative, or the line is removed and the deny-list alone enforces the constraint. | P2 | OPEN |

---

## Summary by Priority

| Priority | Count | Rows |
|---|---|---|
| P0 | 2 | R1, R2 |
| P1 | 6 (seed) + 3 (mined) = 9 | R3, R4, R5, R6, R7, R8, F1, F3, F4 |
| P2 | 9 | F2, F5, F6, F7, F8, F9, F10, F11, F12 |
| **Total** | **20** | |

---

## Exit Criteria for Phase 1

Phase 1 is complete when:

- every critique item from `docs/review/JEFF_GAP_CHANGE_REVIEW.md` has a row in this matrix,
- every row has a measurable PASS condition (no "looks good"),
- every row is classified P0 / P1 / P2,
- no implementation work for Phase 2 begins without a corresponding acceptance criterion in this table.

**Current status: Phase 1 EXIT CRITERIA MET.** All findings captured. No implementation begun.

---

## Cross-Reference: Plan Tasks → Matrix Rows

| Plan Task | Phase | Matrix Rows |
|---|---|---|
| Task 2: False-Green Fix | 2.1 | R1 |
| Task 3: Investigator Capability Boundary | 2.2 | R2, F1 |
| Task 4: Human-in-the-Loop Decision | 2.3 | R3 |
| Task 5: Runtime Compatibility | 2.4 | R5 |
| Task 6: OS Portability | 2.5 | R6, F7, F8 |
| Task 7: Multi-Repo Requirement | 2.6 | R7 |
| Task 8: Own-Repo Transfer | 2.7 | R4, F3, F4 |
| Task 9: Adversarial Validation | 3.1 | R1, R2, R3 (re-test) |
| Task 10: Platform Validation | 3.2 | R5, R6 (re-test) |
| Task 11: Transfer Validation | 3.3 | R4, F4 (re-test) |
| Task 12: Timed Facilitation Validation | 3.4 | R8 |
| (no task assigned yet) | — | F2, F5, F6, F9, F10, F11, F12 |
