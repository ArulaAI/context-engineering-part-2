# Context Lifecycle Lab — Your Readings

Record your own numbers. They will not match anyone else's, and they are not supposed to.

**Three rules, from Stage 0. Write them here before anything else:**

1. Record **absolute tokens**, never the percentage. An empty window already reads 30–40%.
2. **Pin your model.** Auto routes per task; two arms of a comparison can land on
   different models.
3. Token use varies run to run on identical tasks. If a delta is small, write
   "inconclusive" rather than overstate it.

Where to read them: **Chat Debug View** (`Developer: Show Chat Debug View`) for assembled
context · Agent Debug Logs → Summary as fallback.

---

## Stage 0 — Outgrow the Window

What did you try first, with no scripts?

>

Search results for "SEPA" in `src/main`: ______ hits (expected: 0)

Did you find the rate disagreement between `config/fee-schedule.yaml` and
`docs/adr/ADR-0007-fee-schedule.md` on your own, or only once prompted?

>

One line — did Copilot fail from too little context, or from noisy/conflicting context?

>

---

## Stage 1 — Discover Before You Retrieve

| Tool | Tier | Verdict | Hits |
|---|---|---|---|
| `grep LegacyPaymentUtils` | text | | |
| `./scripts/authority.sh` | bytecode | | |

`outline.sh` on `PaymentService.java` was ______ lines. The file is 284.

For the SEPA rate question, which source did you decide was authoritative, and why is
there no compiler check for it?

>

---

## Stage 2 — Compress Before Context 🌟

| | Absolute lines (or tokens, if you're tracking those) |
|---|---|
| Raw `mvn test` | |
| `context-run.sh test` digest | |
| Raw repo search for "SEPA" | |
| `context-run.sh search SEPA` digest | |

Did the digest miss anything the raw output had that you actually needed?

>

Name one task in your own work where "compute, don't paste" is sitting unused:

>

---

## Stage 3 — Promote & Package

Facts promoted to `.context/context-register.yaml`: ______
Observations you discarded (not promoted): ______

`context-for.sh calculateFee-sepa` packaged ______ fact(s), excluded ______.

Run it again for an unrelated work-unit tag. What dropped out?

>

Why is the goal "minimum sufficient" context rather than strictly "minimum"?

>

---

## Stage 4 — Isolate & Handoff 🌟

What happened when you told the investigator to "just make the edit yourself"?

>

Did the `CONTEXT CONFLICT` block appear before any handoff was written? ☐ yes ☐ no

Who made the actual decision between `config/fee-schedule.yaml` and `docs/adr/ADR-0007`,
and what did they change on disk to record it?

>

Did the implementer receive your investigation conversation, or only the handoff file?

>

---

## Stage 5 — Challenge & Bound

Fresh reviewer's finding (if any) about the SEPA minimum:

>

`verify-change.sh`, before the fix:

```
(paste the ✗ line and the VERDICT here)
```

The loop, run in sequence:

| Attempt | Command | Exit code | What happened |
|---|---|---|---|
| 1 | `VERIFY_CMD=scripts/verify-change.sh ./scripts/loop.sh check` | | |
| 2 (no code change) | same | | |
| 3 (after the fix) | same | | |

How does thrashing (exit 4) differ from budget exhaustion (exit 5)?

>

What exactly changed in the code between the FAIL and the PASS?

>

---

## Stage 6 — Rehydrate & Prove

What was the fresh session given? (list the exact files)

>

Did it correctly identify what was already complete, without your help?

>

One thing that was NOT preserved that you now wish had been promoted in Stage 3:

>

---

## Take-home

Where in your own work do you repeatedly rediscover the same context?

>

What important rule on your team is currently only an instruction, but should be a
deterministic bound?

>

The one thing you expected to be true today that was not:

>
