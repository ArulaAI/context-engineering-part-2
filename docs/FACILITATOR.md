# Context Lifecycle Lab — Facilitator Guide

**Runtime:** 90 minutes, hands-on throughout. No opening lecture.
**Prerequisite:** Part 1, or fluency with `#file:`, session clearing, and the Ask/Agent
mode ladder.
**Seats assumed:** GitHub Copilot Chat in VS Code, this folder opened as its own
workspace root.

Run the pre-flight in the week before delivery. One of the checks decides which version
of Stage 4/5 you are running.

---

## The one thing to hold on to

Part 1 was "control what you put in the window, in one conversation." This lab is about
a task that outgrows one conversation — where the discoveries, the decisions, and the
verification all have to survive past the chat that produced them.

If you land one idea, land this: **most teams have exactly one artifact from an AI-assisted
task — the chat log — and it is the worst possible artifact.** It is unstructured, it is
not reusable by the next person or the next session, and it re-sends its entire cost on
every turn for as long as it stays open. Everything in this lab is a way of pulling the
things worth keeping out of the chat and putting them somewhere better: a routing table,
a digest, a register, a handoff file, a deterministic check.

> **Line to use:** "If your only record of what happened is the scrollback, you don't have
> an engineering artifact. You have a transcript."

---

## Pre-flight — run these, they change the lab

```bash
mvn -B clean test        # BUILD SUCCESS, Tests run: 5
bash docs/verify.sh      # 15/15 automated checks pass
```

Then, **in a live Copilot session**, settle these two. Both have written fallbacks, but
you need to know which version you're teaching *before* you walk in:

| Check | If yes | If no |
|---|---|---|
| Does the investigator's missing `edit` tool actually block edits? | Stage 4 runs at rung 5 (a missing capability) | Stage 4 still teaches the *intent*, but say plainly that this build doesn't enforce it |
| Does a genuinely new chat clear prior context (vs. just switching modes)? | Stage 5.1 lands as designed | Teach the practice ("always open a new chat for review") regardless — you can't demonstrate the failure mode, but the discipline is the same |

**Everything in this lab works without hooks.** `.github/hooks/` upgrades a script-level
bound into a tool-level block; `scripts/loop.sh` and `scripts/verify-change.sh` enforce
the same rule with no hook support at all. That was an architectural decision, not luck.

---

## Timing

| Block | Planned | Hard floor | What to cut first |
|---|---|---|---|
| 0 — Outgrow the Window | 8 | 5 | Cut 0.2's full recording; just name the failure |
| 1 — Discover Before You Retrieve | 12–14 | 9 | Cut 1.3, keep 1.1 and 1.2 |
| 2 — Compress Before Context 🌟 | 15 | 12 | Cut 2.4 (agent writes its own script) |
| 3 — Promote & Package | 15 | 10 | Cut the unrelated-work-unit demo in 3.2 |
| 4 — Isolate & Handoff 🌟 | 18 | 18 | **Never cut** |
| 5 — Challenge & Bound | 15 | 12 | Cut the fresh-reviewer half before the deterministic-check half — the script still lands the lesson alone |
| 6 — Rehydrate & Prove | 8–10 | 6 | Cut 6.3's comparison table; verbal summary is fine |

**If you are 10 minutes down entering Stage 4**, take it from Stage 6, not Stage 4 or 5.
Stage 4 is the one nobody can reconstruct alone from the guide, and Stage 5 is where the
seeded bug actually gets found.

---

## Per-stage notes

### Stage 0 (8 min)

The point is that a search for "SEPA" returns nothing, and the rate conflict is easy to
miss unless you go looking in both `config/` and `docs/adr/`. Don't rescue the room from
this — let a plausible-but-wrong plan get proposed if that's where the conversation goes.

> **Line to use:** "There's enough information in this repo to do this correctly right
> now. It just isn't sorted by what to trust yet."

### Stage 1 (12–14 min)

Run 1.1 and 1.2 back to back with no commentary between them.

**The moment to draw out:** ask who would have believed the `grep` result on
`LegacyPaymentUtils` — 3 hits, including an import. Most hands go up. Then point out a
model asked the same question reads the same 3 lines and agrees with `grep`. This isn't
a human failing, it's an evidence-tier failing.

**Watch for:** someone asking why there's no compiler check for the SEPA rate
disagreement. Good question — say plainly that SEPA doesn't exist in code yet, so the
authority hierarchy bottoms out at "committed config" for this one, not "bytecode."

> **Line to use:** "The compiler settles the LegacyPaymentUtils question for free. It has
> nothing to say about the SEPA rate, because nobody's written that code yet — that's
> what makes Stage 4's human decision real instead of theater."

### Stage 2 (15 min) — headline

**45 lines, not the thousands you might expect** — this repo is small and its Maven
dependencies are cached, so say that up front or someone will (correctly) push back that
your "expensive path" isn't very expensive. The *ratio* (45→6, roughly 7×) is the
teachable number, not the absolute count. A real project's raw `mvn test` output runs to
hundreds or thousands of lines; the technique compounds with codebase size.

2.4 is worth the time if you have it: watch Copilot write a script and report only a
table, with the source files never entering the window.

> **Line to use:** "The cheapest token is the one that never enters the window. Forty-five
> lines became six. On your actual codebase, it's thousands becoming twelve."

### Stage 3 (15 min)

The mechanism to make land: `context-for.sh` **filters**, it does not re-derive. Run it
once for `calculateFee-sepa` and once for an unrelated tag, side by side, and let the
room watch the tagged fact disappear from the second run.

**Watch for:** someone asking why the register is YAML and not JSON, or why it's
hand-parsed instead of using a real YAML library. Answer: the flat-subset constraint is
deliberate — it's what lets `context-for.sh` parse it with nothing but Python's standard
library, matching every other script in this lab's "no new dependencies" rule.

> **Line to use:** "Three facts got promoted. Everything else from the last twenty minutes
> — the raw test output, the false starts — is gone on purpose."

### Stage 4 (18 min) — headline

The whole stage lives in one line of frontmatter: `tools: ['search', 'read', 'runCommands']`
on `sepa-investigator.agent.md` — no `edit`.

**Make them try to break it.** "Just make the edit yourself" — and watch it be unable to.
The distinction between *won't* and *can't* is the most portable idea in the lab.

**The payoff is the human decision in 4.3.** The investigator does not pick a side
between `config/fee-schedule.yaml` and `docs/adr/ADR-0007`. It stops, prints
`CONTEXT CONFLICT`, and waits. Someone in the room has to actually open the ADR and edit
its Status field. Do not let this become a formality — ask the room *why* config should
win before anyone touches the file (answer: it's the committed, machine-checked source;
the ADR is a discussion document that nobody ever finalized).

> **Line to use:** "It's not being polite by asking you. It structurally cannot resolve
> this itself — there's no compiler check for which document a human forgot to update."

**Rough edge:** if a prior dry run already marked `ADR-0007`'s Status `Superseded`, the
conflict won't reproduce. Reset it to `Proposed` before the session (see
`docs/VERIFICATION.md`'s Standing Risks).

### Stage 5 (15 min)

This is where the seeded bug lives. The buggy branch's comment says "EUR 2.00 minimum"
and is telling the truth about *intent* — the bug is which quantity gets compared to
2.00. Do not summarize the bug for the room before they've had a chance to find it via
the fresh reviewer.

**The reframe to land:** a comment that correctly states a rule is not evidence the code
implements it. `verify-change.sh` doesn't read the comment — it calls the compiled method
through `jshell` and checks the number.

**Thrashing is the concrete payoff of 5.3.** Run the identical `loop.sh check` twice with
no code change between them and get exit 4. The hash repeating is the whole mechanism —
three lines of shell, not a judgment call.

> **Line to use:** "The comment was honest. The comparison wasn't. That gap is exactly
> what a fresh reviewer — and a script that runs the code instead of reading it — is
> built to catch."

### Stage 6 (8–10 min)

Keep this one brisk. The point lands or it doesn't in the first two minutes: open a new
chat, hand it three files, and see whether it can reconstruct the task. If it can, the
lifecycle worked. If it can't, something that should have been promoted to the register
wasn't — which is itself a useful failure to discuss.

---

## Questions you will get

**"Isn't Stage 4's missing-tool thing just a permission setting?"**
Functionally similar, categorically different. A permission a human can grant is still a
policy. A tool that doesn't exist in the agent's frontmatter is a capability that doesn't
exist — there's no "just this once" path around it for the model to reason its way
through.

**"Why does the reviewer need a whole new chat? Can't it just be told to ignore the
earlier context?"**
Telling a model to ignore what it's already seen is a request, and the whole lab's
running theme is that requests are the weakest rung. A new chat is a structural
guarantee; an instruction to disregard prior context is not.

**"Isn't this a lot of infrastructure for one fee calculation?"**
Yes, deliberately — the point of the lab is the pattern, not the ticket. A one-line fee
fix doesn't need a context register. A task that spans a stale ADR, a conflicting
config, an isolated implementer, and a fresh reviewer does, and that shape recurs far
more than a single-file fix does once a codebase has any history to it.

**"What if our register or handoff format doesn't look like this one?"**
It shouldn't have to. The categories in `context-register.yaml` (verified facts,
decisions, constraints, superseded sources, unknowns) are the transferable part. The
exact YAML shape is this lab's implementation choice, made specifically so
`context-for.sh` can parse it without a third-party dependency.

**"We don't have hooks enabled."**
Then you're on the script rung, which is where this lab is designed to work anyway. You
lose the upgrade from *the agent is told to stop* to *the agent cannot proceed* — worth
asking your admin about, not worth blocking on.

---

## Known rough edges

- **Hook availability and fresh-chat isolation are the two real unknowns.** Settle both
  in pre-flight; both have a written fallback that still lands the lesson.
- **Exit 4 (thrashing) needs a failure the agent (or you) doesn't fix between checks** —
  that's by design in Stage 5.3, not a bug, but say so if someone looks confused that
  "nothing changed."
- **`ADR-0007`'s Status field is stateful across dry runs.** Reset it to `Proposed`
  before each delivery.
- **The 45-line raw `mvn test` figure is specific to this small, dependency-cached
  repo.** Say so — a real project's number will be larger, and the ratio is the lesson.

---

## Numbers: what you may and may not say

**Measured in this repo — safe to state flatly:**
`mvn test` raw = 45 lines vs `context-run.sh test` digest = 6 lines · `authority.sh`:
3 grep hits / 0 bytecode references / verdict FALSE POSITIVE · `outline.sh` on
`PaymentService.java`: 17 lines describing 284 · `context-run.sh search SEPA`: 11 raw
hits → 3 shown · `verify-change.sh`: FAIL on the seeded bug (`calculateFee(100.00,
"SEPA") = 0.35`), PASS after the fix (`= 2.0`) · loop exit sequence on the seeded bug:
1 (CONTINUE) → 4 (thrashing, identical hash) → 0 (DONE) after the real fix.

**Independent research — cite with the source (see `research/` at the parent repo root
for primary sources):**
Automation-bias evidence that agent PRs are reviewed less and merge faster · the
declarative-vs-behavioral probe distinction (models restate constraints far more
reliably than they honor them behaviorally) · clarification-seeking economics
(resolve-rate lift at a real cost increase) · "never verify a model with a model"
findings from independent studies of LLM-judge repair loops.

**Do not state without re-verifying:**
Any specific dollar or percentage figure from the parent repo's `LAB_ACTION_GUIDE_UPDATED.md`
research base unless you've re-read the primary source yourself — that guide's citations
were vetted for its own claims, not this lab's. Any claim that this lab's 45-line
`mvn test` figure generalizes to a "typical" project — it does not; it's an artifact of
this repo's size.

---

## What to say if a stage fails live

Name it, use the fallback in the guide, move on. Every structural stage has one written
down.

This audience is senior. A failed demo handled honestly costs thirty seconds. A demo you
pretend worked costs the room — and in a lab whose closing question is "what should be
enforced outside the model," pretending a check passed when it didn't undercuts the
entire thesis, not just that one moment.
