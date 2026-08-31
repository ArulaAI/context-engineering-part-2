# Timed Facilitation Guide — Context Engineering, Part 2

**Purpose:** Timed dry-run framework for validating session duration before official delivery.  
**Created:** 2026-08-29  
**Addresses:** R8 in `docs/REMEDIATION_ACCEPTANCE_MATRIX.md`

---

## 1. Purpose

This guide governs the **timed dry run** that must happen before any official delivery of this lab. The dry run must be conducted by someone who did **not** build the lab — a facilitator or colleague who can experience participant confusion, model wait times, and recovery moments without insider knowledge compressing the timeline.

The core requirement from R8:

> A timed dry run by someone who did not build the lab confirms the published duration. Facilitator, participant, Copilot-wait, discussion, and recovery times are tracked separately. Official delivery format chosen and published.

This document provides the tools to run that dry run, interpret its results, and choose a delivery format the published materials will honestly reflect.

---

## 2. Why a Timed Dry Run by an Outsider

Working estimates in `LAB_ACTION_GUIDE.md` are exactly that — estimates made by the builder who knows the answers, has the scripts cached, and can skip uncertainty delays. Real participants:

- Pause to read output they have not seen before
- Ask questions that the builder's mental model already answered
- Wait for Copilot responses (model latency varies from seconds to over a minute per call)
- Hit setup problems the builder has already internalized around

None of these appear in a builder-conducted walkthrough. A dry run by someone who has not built the lab captures them; a builder self-timing does not.

**The published duration must reflect what a real cohort experiences, not what the builder experiences.**

---

## 3. Time Tracking Categories

Track each of the following **separately** for every stage. Do not collapse them into a single "total" during recording — the breakdown is what makes the data useful for format decisions and future facilitation improvements.

| Category | Symbol | What to Capture |
|---|---|---|
| **Facilitator instruction time** | F | Time the facilitator is talking: setup, orientation, transition narration, explaining a concept, answering a question before the participant continues |
| **Participant hands-on time** | H | Time the participant is actively working: reading instructions, running scripts, writing in their stage readings, typing prompts |
| **Copilot waiting time** | W | Clock time spent waiting for Copilot or GitHub Models to respond — from prompt submission to response completion. Log each wait individually if they cluster |
| **Discussion time** | D | Group or pair discussion, debrief, verbal reflection. Distinct from facilitator instruction — this is back-and-forth, not one-directional |
| **Recovery / troubleshooting time** | R | Time spent on setup issues, script failures, terminal misconfiguration, unexpected errors. This is the category most likely to inflate actual delivery time beyond estimates |

**Why track recovery separately:** Recovery time is real delivery time, but it is also highly environment-dependent. A cohort on corporate-locked Windows machines with restrictive shell policies may add 20+ minutes of R-time that a clean-VM cohort never sees. Tracking it separately lets the facilitator adjust format choice based on likely environment, not just total elapsed time.

---

## 4. Timing Template

Complete one row per stage during the dry run. Times are in **minutes**. Use decimals for partial minutes (e.g., 1.5 for 90 seconds).

Log Copilot wait events individually in the Notes column (e.g., "3 waits: 0.5, 1.2, 2.0 min") before summing for the W column. Recovery events should be described briefly (e.g., "Git Bash not set as default terminal — 4 min to fix").

| Stage | Facilitator (F) | Hands-on (H) | Copilot Wait (W) | Discussion (D) | Recovery (R) | Total | Notes |
|---|---|---|---|---|---|---|---|
| 0 — Outgrow the Window | | | | | | | |
| 1 — Discover | | | | | | | |
| 2 — Compress | | | | | | | |
| 3 — Promote & Package | | | | | | | |
| 4 — Isolate & Handoff | | | | | | | |
| 5 — Challenge & Bound | | | | | | | |
| 6 — Rehydrate & Prove | | | | | | | |
| 7 — Apply Without Harness | | | | | | | |
| 7B — Your Own Repo | | | | | | | |
| **TOTAL** | | | | | | | |

### Timing Template — Copilot Wait Log

Use this section to log individual Copilot wait events before aggregating into the W column above. Large variance here (e.g., 0.2 min vs. 3.5 min for similar prompts) is worth noting for Copilot-heavy stages.

| Stage | Wait # | Duration (min) | Context (what was submitted) |
|---|---|---|---|
| | 1 | | |
| | 2 | | |
| | 3 | | |
| *(add rows as needed)* | | | |

---

## 5. Stage Time Budget — Estimates from LAB_ACTION_GUIDE.md

The following estimates are extracted from the Quick Reference table in `LAB_ACTION_GUIDE.md` and represent the builder's working estimates. They are the baseline the timed dry run must validate or correct.

| Stage | Estimated Duration | Notes from Guide |
|---|---|---|
| 0 — Outgrow the Window | 9 min | Baseline failure; minimal script use |
| 1 — Discover | 18–20 min | Includes `context-map.sh`, `authority.sh`, outline + adapt exercise |
| 2 — Compress | 20 min | `context-run.sh` test + search + BUILD reducer exercise |
| 3 — Promote & Package | 20 min | Register authoring from template; `context-for.sh` |
| 4 — Isolate & Handoff | 20 min | Agent mode; human decision; HANDOFF.md; `git apply` fixture |
| 5 — Challenge & Bound | 21 min | Fresh reviewer; `verify-change.sh`; build check 5; loop thrashing |
| 6 — Rehydrate & Prove | 9 min | Fresh chat only; artifacts from Stages 3–5 |
| 7 — Apply Without Harness | 25 min | Two unaided exercises; no scripts, agents, or skills |
| 7B — Your Own Repo | 10–15 min | Real ticket; 2–3 pattern plans; naming what NOT to build |
| **TOTAL (low estimate)** | **~152 min** | Using 18 min for Stage 1 and 10 min for Stage 7B |
| **TOTAL (high estimate)** | **~159 min** | Using 20 min for Stage 1 and 15 min for Stage 7B |

**Key observation:** The estimated total is approximately **152–159 minutes** — solidly in the 2.5-hour range, not 2 hours. The guide's own statement "approximately 2 hours (core path)" likely refers to Stages 0–6 only (total estimated: ~117–119 min). Stages 7 and 7B add 35–40 minutes beyond that.

**The 90-minute claim cannot be supported by these estimates.** The condensed path (cutting noted sections from Stages 1, 3, and 5) would need to compress approximately 80+ minutes of material, which would require skipping multiple non-negotiable stages. The dry run must confirm this arithmetic against real cohort behavior.

---

## 6. Official Delivery Format Decision

**This section presents options for the human facilitator to decide.** Do not choose a format without a completed timing template from Section 4. The choice must be grounded in dry-run data, not estimates.

### Option A — 90-Minute Core Lab + Optional 30-Minute Extension

**Scope:** Stages 0–6 in 90 minutes; Stages 7 and 7B as an optional advanced extension in an additional 30 minutes.

**What this requires:** Condensed-path cuts in Stages 1, 3, and 5 must reduce the 117–119-minute Stage 0–6 estimate to 90 minutes — a reduction of approximately 27–29 minutes. This means cutting roughly 25% of the core path content.

**Pros:**
- Fits a standard 90-minute workshop slot
- Advanced extension can be assigned as post-workshop homework
- Matches common corporate training slot lengths

**Cons:**
- The three condensed-path cuts in Stages 1, 3, and 5 each remove exercises explicitly labeled as important by the guide (Stage 1.4 adapt exercise; Stage 3's full register authoring; Stage 5.3 artifact-choice judgment)
- Stage 7 (Apply Without the Harness) is described as non-negotiable; placing it in an optional extension means most cohorts never do it
- The guide states "7 and 7B are the exercises that actually tell you whether the rest of the lab transferred" — an optional block of non-negotiable content is a structural contradiction
- R8's PASS condition explicitly states: "A 130+ minute lab must NOT be labeled 90-minute." Dry-run data will confirm whether this applies.

**Recommendation for consideration:** Only viable if dry-run data shows Stages 0–6 fit in 90 minutes without cuts, which current estimates do not support.

---

### Option B — 120-Minute Full Lab (All Stages, Condensed Path Available)

**Scope:** All stages (0–7B) in 120 minutes with condensed-path options exercised.

**What this requires:** Condensed-path cuts must reduce the 152–159-minute high estimate to 120 minutes — a reduction of approximately 32–39 minutes. Condensed-path callouts in Stages 1, 3, and 5 are used as written.

**Pros:**
- Covers all stages including the non-negotiable transfer exercises (7 and 7B)
- 120 minutes is a common half-day workshop slot
- Condensed-path options exist and are documented; they could make this feasible

**Cons:**
- Requires approximately 32–39 minutes of compression from a baseline that is already an optimistic estimate
- Copilot wait times (not currently estimated) may consume the entire compression budget
- Recovery time for a real corporate cohort is not zero; any Windows setup issues immediately break the budget
- Condensed-path cuts reduce the quality of the learning experience in Stages 1, 3, and 5

**Recommendation for consideration:** Feasible only if dry-run data shows Copilot wait times are consistently under 30 seconds per call and recovery time is near zero. The condensed path must be dry-run explicitly, not assumed to save exactly the right amount of time.

---

### Option C — Two-Part Lab (Part A: 60 Min Stages 0–5; Part B: 60 Min Stages 5–7B)

**Scope:** Split into two 60-minute sessions. Part A covers Stages 0–5 (context lifecycle mechanics). Part B covers Stages 5–7B (verification, rehydration, and transfer exercises). Stage 5 is the overlap point — briefly recapped at the start of Part B.

**What this requires:** Part A must fit ~117 minutes of material into 60 minutes, or the split point must shift (e.g., Part A: Stages 0–4; Part B: Stages 5–7B). The split point is a facilitation decision, not a fixed constraint.

**Pros:**
- Two 60-minute sessions are much easier to schedule than one 150-minute session in corporate environments
- Allows participants time between sessions to apply concepts to their own work before Stage 7B
- Recovery time in Part A can be addressed before Part B begins — real cohorts often iron out setup in session 1
- Stage 7B ("Your Own Repo") becomes more actionable if participants have 24–48 hours between sessions to identify a relevant ticket

**Cons:**
- Requires coordination for two separate scheduling events
- Participants who attend Part A but not Part B miss the non-negotiable transfer exercises
- The overlap / recap at Stage 5 must be carefully designed to not repeat content or skip the check-5 exercise

**Recommendation for consideration:** The strongest structural fit for corporate delivery. The between-session gap makes Stage 7B genuinely stronger. Depends on whether the client context allows two-session scheduling.

---

## 7. Decision Inputs for the Human Facilitator

After completing the timed dry run and filling in Section 4's template, answer these questions before choosing a format:

1. **What was the total elapsed time in the dry run?** (Section 4 TOTAL row)
2. **How much of that total was recovery time?** (Section 4 R column total) — this is the most environment-sensitive number and should inform the buffer added for a live cohort.
3. **What was the Copilot wait total?** (Section 4 W column total) — model latency is not in any current estimate and may be 10–30 minutes of non-learnable time.
4. **Did any single stage substantially exceed its estimate?** Stage 4 (human-in-the-loop, agent mode, HANDOFF.md) and Stage 7 (unaided transfer) are the highest-variance stages.
5. **What is the delivery environment?** Corporate-managed Windows machines with restricted shells are the highest-risk context for recovery time. Clean VMs or BYOD MacBooks are the lowest.
6. **Can the audience do two sessions?** If yes, Option C is worth serious consideration regardless of total time.

---

## 8. Validation Criteria

A delivery format is accepted only when all of the following are true:

| # | Criterion | Pass Condition |
|---|---|---|
| V1 | Published duration matches dry run | Stated duration is within ±15% of the timed dry run total (excluding recovery time, which varies by environment) |
| V2 | 130+ min lab not labeled 90-minute | If dry-run total (excluding recovery) is ≥ 130 minutes, the 90-minute label is not used in any marketing or scheduling materials |
| V3 | Recovery time tracked separately | The dry-run timing sheet shows R times recorded independently — not merged into H or F times |
| V4 | Copilot wait time tracked | At least Stage 4 and Stage 5 Copilot wait times are recorded individually per call |
| V5 | Format choice is documented | The facilitator records which option was chosen, why, and which dry-run data point drove the decision |
| V6 | Non-negotiable stages not made optional | Stages 7 and 7B remain in the delivered session, not relegated to optional homework, unless dry-run data shows the core (0–6) is genuinely 90 minutes without cuts |

---

## 9. Updating the Acceptance Matrix (R8)

After completing the dry run and publishing the delivery format, update R8 in `docs/REMEDIATION_ACCEPTANCE_MATRIX.md`:

**R8 PASS condition:** A timed dry run by someone who did not build the lab confirms the published duration. Facilitator, participant, Copilot-wait, discussion, and recovery times are tracked separately. Official delivery format chosen and published.

**R8 status to set after dry run:** Update from `OPEN` to either:

- `PASS` — if all six validation criteria (V1–V6 above) are met
- `IN PROGRESS` — if the dry run is complete but format is not yet published
- `FAIL` — if the dry run reveals the published duration cannot be supported without removing non-negotiable stages

Record the dry-run total and chosen format in the R8 PASS Condition cell of the matrix.

---

*Copyright 2026 Arula.AI (InRhythm Arula Labs). All Rights Reserved. | Internal - Confidential*
