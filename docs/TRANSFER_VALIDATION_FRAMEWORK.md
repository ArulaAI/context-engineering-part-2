# Transfer Validation Framework

**Created:** 2026-08-29  
**Phase:** 3.3  
**Matrix rows:** R4, F4 (re-test)  
**Depends on:** `docs/REMEDIATION_ACCEPTANCE_MATRIX.md`, `LAB_ACTION_GUIDE.md` Debrief

---

## 1. Purpose

This framework is used when **a fresh engineer — someone who did not build or beta-test this lab — attempts a context engineering task in an environment that has none of the lab's scaffolding**.

"Fresh" means two things simultaneously:

1. **Fresh engineer.** The person has completed the lab once but is now working alone, without a facilitator, without lab notes open, and without access to the RTP worked example.
2. **Fresh context.** The target environment is either a different repository entirely, or this repository with all Meridian-specific scaffolding removed (scripts, skills, agents, `.context/`, handoff artifacts).

The validator's job is to determine whether the participant can **construct the mechanism** — not recall a command string — and **explain why that mechanism is the correct choice** for the new situation. A participant who produces a working script but cannot explain the reasoning behind the artifact-choice (disposable script vs. reusable utility vs. skill vs. agent vs. CI check) has not demonstrated transferable skill; they have demonstrated recall.

This framework is the Phase 3.3 operationalization of the R4 PASS condition:

> *Fresh participant can reproduce the full context lifecycle pattern (discover → compress → package → handoff → verify → rehydrate) in an unfamiliar, unscaffolded repository.*

---

## 2. Validation Protocol

### 2.1 What the Validator Provides

The validator gives the participant:

- A **natural-language engineering problem** (see Section 4 for sample problems).
- A **repository** containing realistic source code, configuration files, tests, and documentation. The repository must have no prebuilt context-mapping scripts, no `context-for.sh` or equivalent, no `.context/` directory, no pre-authored context registers, no handoff templates, and no skill or agent definitions tailored to the problem.
- **Minimal framing:** "Work through this problem the way you would on a Monday-morning ticket."
- A working build (the repo compiles and tests pass at baseline).

### 2.2 What the Validator Does NOT Provide

The following items are explicitly withheld:

| Withheld item | Why it is withheld |
|---|---|
| Meridian scripts (`context-map.sh`, `authority.sh`, `context-run.sh`, `context-for.sh`, `verify-change.sh`, `loop.sh`) | Testing whether the participant can construct the mechanism from first principles, not recall a command |
| `.github/skills/` or `.github/agents/` from the lab | Testing whether the participant can define capability boundaries, not just use pre-built ones |
| `.context/` directory or any pre-authored `context-register.yaml` | Testing whether the participant can decide what to promote and why |
| Handoff templates (`.workflow/HANDOFF.md`) | Testing whether the participant can package context for handoff without a pre-filled template |
| Worked answers or annotated solutions from the RTP exercise | Preventing pattern-matching to the specific worked example |
| Exact file names the participant "should" read | Testing whether discover precedes retrieve |
| The lab's Ten Patterns table (during the session) | Testing recall and application, not table lookup |

### 2.3 What the Participant Must Independently Determine

The participant is considered to be demonstrating transfer when they independently determine:

1. **Context boundaries.** Which files are authoritative for which claims; which sources can be trusted without verification; which claims require triangulation across sources.
2. **Source of truth.** For any contested value (rate, config key, schema), which source is live and which is stale — and the reasoning method used to resolve the contest (not just the correct answer).
3. **Deterministic vs. probabilistic responsibilities.** Which acceptance criteria are stable enough to encode as a verifier (a deterministic bound) and which require judgment in each instance. The participant must explain the threshold, not merely produce a check.
4. **Escalation points.** Where in the workflow a human decision is required — specifically, which conflicts cannot be resolved by reading the repository more carefully, and what the correct escalation artifact is.
5. **Reusable context artifacts.** Which discoveries from this task should survive beyond the session (and in what format), versus which are single-use context and should not be promoted.

---

## 3. Evaluation Rubric

For each pattern, "demonstrate" means the participant produced an observable artifact or decision (not a verbal claim) AND explained the reasoning behind it when asked.

| # | Pattern | What the participant should demonstrate | PASS | PARTIAL | FAIL |
|---|---|---|---|---|---|
| 1 | **Discover** | Lists candidate sources of truth *before* reading any file in depth. Produces a routing table (even a mental or written one) classifying files by category (config, ADR, source, test). | Names at least two distinct source categories; explains why order of discovery matters before retrieval; does not open the highest-friction file first. | Builds a partial routing table but cannot explain why category classification precedes reading. Discovers but does not sequence. | Jumps directly to reading source files or asking the AI to search broadly; produces no routing structure before loading content. |
| 2 | **Authority** | For a contested value, names the evidence source that can *settle* the claim and distinguishes it from sources that can only *reference* it. Applies the test: "Can this source be wrong without any other file changing?" | Applies authority test to at least one contested claim; explains the asymmetry between committed config and draft ADR (or equivalent in the validation scenario). Correctly identifies which source is authoritative when two disagree. | Identifies that sources disagree but chooses the authoritative one without articulating the reasoning method. Arrives at the right answer by instinct, not by applying a repeatable test. | Treats all sources as equally credible; resolves the contest by whichever source was read first or whichever the model cited; cannot explain why one source outranks another. |
| 3 | **Reduce** | Identifies at least one tool output (test output, build log, dependency scan) that should be compressed before reaching the model. Writes a reducer spec or reducer command that extracts only the decision-relevant fields. | Specifies what the reducer must preserve and what it discards, and gives the reason for each discard decision. Does not need a working script — a correct spec suffices. | Identifies that output is noisy but reduces it by truncating or summarizing rather than extracting decision-relevant fields by name. Cannot name which fields are load-bearing for the decision. | Pastes entire tool output into context without reduction; or reduces by eyeballing without a repeatable rule. |
| 4 | **Promote** | Decides which discoveries from the session should be recorded for future sessions, authors a compact artifact (register, notes, or equivalent), and includes provenance (where each fact came from and when). | Produces an artifact with source references for each promoted fact; explains the promote-vs-discard decision for at least one fact that was NOT promoted. The artifact is readable by someone who was not in the session. | Promotes facts but omits provenance, or promotes everything without a discard decision. | Promotes nothing (treats all context as single-use); or promotes a full file dump with no compression. |
| 5 | **Package** | For the *next* action (implementation, review, or handoff), assembles the minimum sufficient context: promoted facts + relevant source fragments + a stated objective. Does not include files that are irrelevant to the next actor's decision. | Names what was excluded from the package and why. The package contains no content the next actor cannot act on. | Packages too broadly (includes everything discovered) or too narrowly (omits a fact the next actor needs to make a decision). | Hands off "here is the whole repo" or "here is my chat history" without a curated package. |
| 6 | **Isolate** | Decides whether the implementation role needs a capability boundary or only a prompt boundary. If a boundary is needed, specifies *which* capabilities the implementing actor must not have access to — and explains why the capability restriction is load-bearing. | Can state the difference between "the model is instructed not to do X" and "the model cannot do X." Explains which of those two is required in this scenario and why. Does not need to implement the boundary — a correct decision with correct reasoning suffices. | Recommends isolation but cannot explain the difference between capability and prompt boundaries, or recommends isolation when a prompt boundary would be sufficient. | Treats all isolation as the same; or conflates "I told it not to" with "it cannot." |
| 7 | **Handoff** | Produces a handoff artifact that transfers the *decisions* made in the session, not the conversation history. The artifact contains: objective, key findings with sources, decisions made and the reasoning, open questions, and what the next actor should NOT re-examine. | A fresh reader of the artifact alone can take the next action without reopening the session. The "do not re-examine" section is present and non-empty. | Handoff artifact transfers facts but not decisions; a fresh reader would need to re-examine at least one source to decide whether to proceed. | Handoff is the chat transcript or a summary of what was read, not a record of what was decided and why. |
| 8 | **Verify** | Identifies at least one acceptance criterion that is stable enough to become a deterministic check (not a model-mediated review). Writes the check or specifies it precisely enough that it could be implemented without further clarification. | Explains *why* this criterion is appropriate for deterministic enforcement — what property of the criterion makes it stable across future changes. Explains the fail-closed requirement. | Identifies criteria that could be encoded as checks but cannot explain the stability threshold (why this criterion vs. others). Produces a check without explaining the design choice. | Relies entirely on model-mediated review; produces no deterministic bound; or produces a check that passes trivially (e.g., file exists). |
| 9 | **Review** | For the review step, decides whether the reviewer should inherit the producer's reasoning or receive only curated evidence. Explains which situation calls for an isolated fresh-context reviewer vs. an in-session reviewer. | Correctly identifies whether the review is a correctness check (fresh context required) or a judgment call that benefits from session context. Does not hand the reviewer the producer's full reasoning when a correctness check is what is needed. | Uses a fresh-context reviewer but loads it with the producer's reasoning anyway, defeating the isolation. Or uses an in-session reviewer when correctness isolation is the requirement. | Skips the review step; or conflates "review by a different person" with "review in a fresh AI context." |
| 10 | **Rehydrate** | Without re-running the session, reconstructs the engineering state from durable artifacts alone (promoted register + handoff + relevant source fragments). Confirms whether the reconstruction is complete enough to resume the task. | Names at least one thing that would be lost if the artifacts were missing, and explains how the artifact design prevents that loss. | Can rehydrate from artifacts but cannot name what would be missing if the artifacts were less complete. | Cannot rehydrate; requires re-reading the full repository or re-running the discovery process from scratch. |

---

## 4. Sample Validation Scenarios

The following scenarios are suitable for transfer validation. Neither involves RTP, Meridian Financial, or any problem this lab used as a worked example.

### Scenario A — "Add rate limiting to the account lookup endpoint"

**Repository type:** A REST API service with multiple endpoints, a config directory, a middleware layer, existing rate-limiting logic on at least one other endpoint, and integration tests.

**Problem statement given to participant:**

> The account lookup endpoint (`GET /accounts/{id}`) has no rate limiting. Product wants 100 requests/minute per client token, with a 429 response on violation. Implement this. The rate limit value must come from config, not from a hardcoded constant.

**Why this tests transfer:**

- **Discover (Pattern 1):** Rate-limiting logic may live in middleware, in a framework config file, in a database config table, or in a dedicated rate-limiter class. The participant must build a routing table before reading anything.
- **Authority (Pattern 2):** If an existing rate limit is configured in two places (e.g., an environment variable AND a YAML config file), the participant must determine which one is live.
- **Reduce (Pattern 3):** Integration test output for rate-limiting tests is verbose (individual request timings, retry logs). The participant must specify what the verifier needs to see, not the full output.
- **Isolate (Pattern 6):** The participant must decide whether the implementation role needs to be prevented from touching the auth layer, or whether a prompt boundary is sufficient.
- **Verify (Pattern 8):** The "429 on the 101st request" criterion is deterministic and stable; the participant should encode it as a check. The "appropriate error message" criterion is not — the participant should explain why.
- **Escalation (Pattern 2 / Handoff, Pattern 7):** If the existing rate limiter on another endpoint uses a different mechanism than what the new endpoint would use, the participant must surface the conflict and explain what the escalation artifact looks like, rather than silently picking one approach.

**Signals that indicate PASS vs. FAIL:**

- PASS: Participant reads config files before source files; can explain why the config is more authoritative than a comment in source; produces a verifier spec that includes the boundary condition (request 100 passes, request 101 returns 429); explains the escalation decision if a conflict exists.
- FAIL: Participant asks the AI to "add rate limiting" in one prompt, accepts the first implementation, and cannot explain which config value is live or why the verifier was designed the way it was.

---

### Scenario B — "Migrate from deprecated XML config to YAML"

**Repository type:** A service with a mix of XML and YAML configuration files, some of which are loaded at runtime and some of which are build-time only. At least one XML file has a YAML equivalent that is partially out of sync.

**Problem statement given to participant:**

> Engineering is retiring the XML configuration system. Migrate `service-config.xml` to `service-config.yaml`. The service must behave identically after the migration. Do not change behavior; only change the config format.

**Why this tests transfer:**

- **Discover (Pattern 1):** The participant must determine whether both files are loaded at runtime, only one is, or neither is (build-time only). This requires a routing table before any migration begins.
- **Authority (Pattern 2):** If the YAML file already exists and partially overlaps with the XML file, the participant must determine which values are live and which are stale. The XML file may have been the authoritative source for some settings while the YAML file was the authoritative source for others. Neither file's age alone settles the question.
- **Escalation (Patterns 2 and 7):** If a setting exists in XML but is absent from the YAML file (or vice versa), the participant must surface the conflict with a handoff artifact rather than silently resolving it by picking one value.
- **Verify (Pattern 8):** "Identical behavior" is too vague for a deterministic check. The participant must decompose it into verifiable sub-criteria: which config values are read at startup, which are read per-request, and which are never read at all (dead config). Dead config should be documented, not migrated.
- **Promote (Pattern 4):** The participant should promote a record of which settings were migrated, which were confirmed dead, and which were escalated — not just the final YAML file.
- **Rehydrate (Pattern 10):** If the migration is interrupted and resumed by a different engineer, the promoted artifact must be sufficient to resume without re-examining the original XML file.

**Signals that indicate PASS vs. FAIL:**

- PASS: Participant maps which files are actually loaded before reading them; correctly identifies the asymmetric authority case; produces an escalation artifact for any value that cannot be resolved from the repository alone; designs a verifier that tests config-value consumption (not just file parsing); explains the promote decision.
- FAIL: Participant treats YAML-as-replacement as a find-and-replace of XML syntax; does not check which file is loaded at runtime; accepts the first passing test as proof of identical behavior; cannot explain which setting values are authoritative.

---

## 5. Pass Standard

The participant must explain **WHY** they constructed each mechanism, not merely produce a functioning artifact.

Concretely: after each artifact (routing table, reducer spec, context register entry, handoff document, verifier, escalation decision), the validator asks:

> "Why did you make that choice?"

A PASS answer names the property of the situation that made this mechanism the correct choice — and names at least one alternative mechanism that would have been wrong, and why.

A FAIL answer describes what the mechanism does without explaining why this mechanism was chosen over alternatives. This includes:

- "I used a config file because that's where config goes" (no explanation of authority asymmetry)
- "I wrote a test because the requirements say to test it" (no explanation of deterministic vs. probabilistic)
- "I used a fresh context because it's a review" (no explanation of correctness-isolation vs. judgment-benefit)
- "I promoted it because I thought it was important" (no explanation of the promote-vs-discard criterion)

The WHY criterion is the distinguishing property of this validation standard. It is not sufficient for the participant to produce correct outputs. The lab teaches repeatable methods; a participant who produces correct outputs by intuition or pattern-matching to the RTP example has not demonstrated that the method transferred.

### Minimum threshold for overall PASS

A participant passes transfer validation when:

- At least 7 of the 10 patterns reach PASS level (not PARTIAL or FAIL).
- No pattern in the set {Discover, Authority, Verify, Handoff} is at FAIL level — these four are load-bearing for the correctness of the workflow, and a FAIL on any of them indicates a gap that would manifest as production errors, not style differences.
- At least one escalation decision is correctly identified and a handoff artifact is produced for it (even if brief).

A participant who reaches 7+ PASS but has a FAIL on any of the four load-bearing patterns scores PARTIAL PASS and should be offered a targeted re-exercise on the failing pattern before being considered complete.

---

## 6. Relationship to the Remediation Acceptance Matrix

This framework is the operationalization of the R4 PASS condition and the F4 re-test (from `docs/REMEDIATION_ACCEPTANCE_MATRIX.md`).

| Matrix Row | Connection |
|---|---|
| **R4** | This framework IS the transfer validation that closes R4. The R4 PASS condition states "fresh participant can reproduce the full context lifecycle pattern in an unfamiliar, unscaffolded repository" — Section 2 defines "unscaffolded," Section 3 defines the rubric, Section 5 defines the standard. |
| **F4** | F4 requires at least one exercise where the learner applies patterns to their own work. Stage 7B satisfies F4 in the lab session. This framework extends F4 validation to a post-lab setting — it confirms that 7B taught the skill, not just the exercise. |

See `docs/REMEDIATION_ACCEPTANCE_MATRIX.md` row R4 for current status.
