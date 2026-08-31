# Context Lifecycle Lab — Your Readings

Record your findings as you go. They will not match anyone else's, and they are not
supposed to — the point is what you verified, not what someone else measured.

---

## Stage 0 — The Helpful Trap

What's your current process, today, when context on a task gets noisy or two sources
disagree? (Answer this *before* opening the ticket.)

>

What did you try first, with no scripts?

>

Search results for "RTP" in `src/main`: ______ hits (expected: 0)

Did you find the rate disagreement between `config/fee-schedule.yaml` and
`docs/adr/ADR-0007-fee-schedule.md` on your own, or only once prompted?

>

Did Copilot surface the rate contradiction? Did it pick a rate? Can you verify which
source it used — regardless of whether its answer was right or wrong?

>

One line — is the problem *missing* context or *unsorted* context?

>

---

## Stage 1 — Discover Before You Retrieve

| Tool | Tier | Verdict | Hits |
|---|---|---|---|
| `grep LegacyPaymentUtils` | text | | |
| `./scripts/authority.sh` | bytecode | | |

`outline.sh` on `PaymentService.java` was ______ lines. The file is 284.

For the RTP rate question, which source did you decide was authoritative, and why is
there no compiler check for it?

>

**1.3 — Deconstruct.** Write the general authority recipe in one sentence, without
naming Java or `jdeps`:

>

**1.4 — Adapt.** Claim: "the test suite exercises the RTP boundary condition." Is
`jdeps` the right tool? ☐ yes ☐ no. Which primitive did you actually use instead, and
what was the verdict?

>

---

## Stage 2 — Compress Before Context 🌟

| | Absolute lines (or tokens, if you're tracking those) |
|---|---|
| Raw `mvn test` | |
| `context-run.sh test` digest | |
| Raw repo search for "RTP" | |
| `context-run.sh search RTP` digest | |

Did the digest miss anything the raw output had that you actually needed?

>

**2.3 — Deconstruct.** Which digest fields were the actual decision, and which were
formatting? What would the digest have shown if `mvn` itself had failed to run —
does it distinguish that from "all tests passed"?

>

**2.5 — Deconstruct.** The five properties of `context-run.sh test` as a reducer:

1. DECISION it serves:
2. RAW SOURCE (command + output format):
3. KEEP (which lines of the 45 actually answer the decision):
4. DISCARD (what deliberately stays outside model context, and why):
5. FAIL CLOSED (what guards a–d prevent):

>

What is the difference between Part 1's model output targeting and Part 2's pre-model
evidence reduction?

>

---

## Stage 3 — Promote & Package

Started from: ☐ `context-register.template.yaml` (correct)

Facts promoted to `.context/context-register.yaml`, in your own words: ______
Observations you discarded (not promoted): ______

`decisions:` left empty at the end of Stage 3? ☐ yes (correct) ☐ no (decisions belong
in Stage 4.4, after the human resolves the conflict — not before)

`context-for.sh calculateFee-rtp` packaged ______ fact(s), excluded ______.

Run it again for an unrelated work-unit tag. What dropped out?

>

Why is the goal "minimum sufficient" context rather than strictly "minimum"?

>

---

## Stage 4 — Isolate & Handoff 🌟

What happened when you told the investigator to "just make the edit yourself"?

>

**4.2 — Deconstruct.** What's the actual difference between an instruction boundary and
a capability boundary? Name one role on your own team where a capability boundary would
catch something an instruction currently doesn't:

>

Did the `CONTEXT CONFLICT` block appear before any handoff was written? ☐ yes ☐ no

Who made the actual decision between `config/fee-schedule.yaml` and `docs/adr/ADR-0007`,
and what did they change on disk to record it?

>

**4.4 — Recorded the decision yourself?** Did you add both `decisions:` entries to your
own `.context/context-register.yaml` after the human step, and re-run `context-for.sh`
to confirm they now appear? ☐ yes ☐ no

Did the implementer receive your investigation conversation, or only the handoff file?

>

---

## Stage 5 — Challenge & Bound

Fresh reviewer's finding (if any) about the RTP minimum:

>

`verify-change.sh`, before the fix:

```
(paste the ✗ line and the VERDICT here)
```

**5.3 — Build ("check 5").** The DoD requirement `verify-change.sh` doesn't check, what
you built to check it, and the verdict:

>

Disposable or promote-to-permanent? Your call, and why:

>

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

## Stage 7 — Build Beyond the Harness 🌟

### 7.1 — Recognition check

Is `PaymentService` using `CurrencyConverter`? Which pattern applies, what's the
deterministic evidence, and should you fix this inside MFIN-2088?

>

---

### 7.2 — Build Your Own Context-Optimization Tool (capstone)

### Your noise problem

> Command:
> Category (from menu):

### Your 5-property spec (write BEFORE touching Copilot)

1. **DECISION** this tool serves:

   >

2. **RAW SOURCE** (exact command + output format):

   >

3. **KEEP** (which lines answer the decision):

   >

4. **DISCARD** (what deliberately stays outside model context, and why):

   >

5. **FAIL CLOSED** (what happens if the command fails):

   >

### Build

The script/pipeline you built (paste or describe):

```
(your tool here)
```

### Validate

> Raw output line count:
> Reduced output line count:
> What was kept:
> What was discarded, and why:
> Forced-failure test — what you broke, what the tool returned, exit code:

### Deploy

> Deployment target chosen:
> Why this target:
> Did you run it from the deployment target? ☐ yes ☐ no

### Reflect

> What did you learn by building this that you didn't know after Stage 2?

---

## Take-home

Where in your own work do you repeatedly rediscover the same context?

>

What important rule on your team is currently only an instruction, but should be a
deterministic bound?

>

Go back to your Stage 0 answer — "what's your current process when context is noisy or
conflicting." What would you actually change about that answer today?

>

The one thing you expected to be true today that was not:

>
