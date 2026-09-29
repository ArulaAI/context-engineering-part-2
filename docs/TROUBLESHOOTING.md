# Context Lifecycle Lab — Troubleshooting

Fallbacks for the mechanisms most likely to behave differently across Copilot builds and
environments. Every fallback below still teaches the stage's lesson — none of them are
"skip this stage."

---

## Stages 3-4 — agents / isolation

### `Context Experiment` reports only one result, or refuses to run

**Cause:** it was given one context instead of two, or the build does not honour the
`agents:` property so its dispatch to `context-probe` never fired.

**Fix:** confirm your message names both **Context A** and **Context B**. If it does and
you still get one result, check whether `context-probe` appears in the mode dropdown. If
it does not, run the comparison by hand in two separate chats, which Stage 6.3 documents
in full as the optional model-side comparison. The isolation is then yours to perform rather than
the harness's, and the comparison is the same.

### Both probes return the same answer

**Cause:** none. Agreement is a legitimate outcome.

**Fix:** nothing. Stage 6.3's graded question is not whether the answers differ, it is
whether the crowded context gave you any way to *audit* its answer. Two matching answers
still leave that question open, which is the point. Do not re-run hoping for a
divergence.

### The agents don't appear in the mode dropdown

**Cause:** `context-engineering-part-2/` was opened as a subfolder of another workspace, not
as its own root. Copilot's `.github/agents/` discovery resolves per opened workspace
root. All six (`rtp-investigator`, `rtp-implementer`, `rtp-reviewer`,
`evidence-checker`, `context-probe`, `context-experiment`) come from the same directory,
so they appear or fail together.

**Fix:** Close the current window. `File > Open Folder...` and select
`context-engineering-part-2/` itself, not its parent.

### `rtp-investigator` makes the edit anyway when asked to

**Cause:** either a Copilot build where custom-agent tool restrictions aren't enforced,
or the agent file wasn't picked up and a general-purpose mode answered instead.

**Fix:** Confirm which agent actually responded (the mode indicator in the chat header).
If it really was `rtp-investigator` and it still edited, this is a build-specific gap —
say so in delivery. Manual fallback: run investigation and implementation in two
separate chat windows, and treat "don't paste implementation instructions into the
investigation window" as the enforced boundary instead of a missing tool.

### `evidence-checker` is never dispatched — the investigator answers itself

**Cause:** either the build does not honour the `agents:` frontmatter property, or the
investigator judged it could answer without help.

**Fix:** ask it explicitly — *"dispatch evidence-checker for this claim."* If it still
answers inline, confirm `evidence-checker` appears in the mode dropdown at all. If it
does not, the `agents:` property is not being honoured on this build: run
`evidence-checker` yourself from the dropdown with the same question, paste its verdict
back, and treat the isolation lesson as demonstrated by hand rather than automatically.
The point — the caller gets the answer without the evidence-gathering — survives the
manual version.

### The agent complies with the wrong rate in Stage 4.4

**Cause:** none. This is one of the two expected outcomes.

**Fix:** nothing to fix — record it and use the left-hand column of 4.4's table. An
agent that defers to the person in front of it is the default behaviour the stage
exists to expose. If it pushes back instead, use the right-hand column. The exercise is
built so both results teach; do not re-run it hoping for a particular one.

### The `CONTEXT CONFLICT` block never appears

**Cause:** the conflict is between two committed rates — `config/fee-schedule.yaml` (0.35%,
USD 2.00 minimum) and `docs/adr/ADR-0007-fee-schedule.md` (0.30% flat). If a prior run edited
either file, there is nothing left to conflict.

**Fix:** confirm both rates are still as shipped, and restore them if not:
```bash
git checkout -- config/fee-schedule.yaml docs/adr/ADR-0007-fee-schedule.md
grep -n "rtp_percent" config/fee-schedule.yaml
grep -n "RTP rate" docs/adr/ADR-0007-fee-schedule.md
```
`./scripts/lab-start.sh --reset` performs that restore for you as part of starting a clean run.

If both rates are correct and the agent still resolves the conflict silently, the terminal half
of the stage stands on its own: `./scripts/ctx.sh handoff calculateFee-rtp --scope
PaymentService.calculateFee --next "implement"` refuses with exit `4` while the pricing question
is open, whatever any agent chose to say about it.

### Does the handoff gate depend on an agent behaving?

**Cause:** a misreading of the design — it does not.

**Fix:** nothing to fix. The gate is `ctx.sh`: a handoff cannot be generated while a blocking
unknown is open, and `ctx.sh decide` will not record a decision whose `--authority` file does
not exist. No agent cooperation is involved, on any build.

---

## Stage 5 — fresh review / hooks

### Switching modes in the same chat still "feels fresh"

**Cause:** you can't always observe the model behaving differently on a mode switch vs.
a new chat from the outside — the difference is in the request payload, not necessarily
in an obviously different-sounding answer.

**Fix:** Teach the practice regardless of whether you can demonstrate the failure mode:
always open a new chat for a review that's supposed to be independent. Pair it with
`./scripts/verify-change.sh`, which doesn't care what chat it's run from — that's your
demonstrable, deterministic half of Stage 5 even if the "fresh chat" half is hard to show
live.

### Hooks don't fire, or fire on the wrong tool

**Cause:** `.github/hooks/` support varies by Copilot build, and VS Code does not honor
the `matcher` field in `hooks.json` — every hook fires on every tool call and must
self-filter on `tool_name`.

**Fix:** Nothing in this lab depends on hooks working. `scripts/loop.sh` and
`scripts/verify-change.sh` enforce the same bounds with no hook support at all. If hooks
do fire, you're demonstrating the upgrade from *the agent is told to stop* to *the agent
cannot proceed*; if they don't, you're demonstrating the fallback rung, which is
`.vscode/settings.json`'s `chat.tools.terminal.autoApprove` block.

### `verify-change.sh` reports "could not evaluate calculateFee"

**Cause:** `jshell` isn't on `PATH`. It ships with the JDK (17+) but some minimal
JRE-only installs omit it.

**Fix:** `which jshell`. If missing, install a full JDK 17+ (not a JRE-only distribution)
and confirm `java -version` and `jshell` both resolve before the session.

### `authority.sh` says "jdeps not found on PATH — refusing to guess"

**Cause:** `java` resolves but `jdeps` doesn't — most commonly on Windows, where the
Oracle installer's `javapath` shim (`C:\Program Files\Common Files\Oracle\Java\javapath`)
is placed ahead of the real JDK's `bin\` directory on `PATH`. `javapath` only forwards a
couple of launchers; `jdeps`, `javap`, and other JDK tools are not in it even though a
full JDK is installed on the same machine.

**Fix:** `which jdeps`. If it's not found, locate the real JDK (`C:\Program
Files\Java\jdk-<version>\bin` is the common install path) and prepend it to `PATH` for
your terminal session, then confirm: `jdeps -version`. Before this guard existed,
`authority.sh` silently reported `0 bytecode reference(s)` — a false "no dependency" —
whenever `jdeps` was missing, instead of an error. If you're seeing an old capture of
that behavior anywhere, it predates the fix; the script now refuses to answer rather than
guess.

### `verify-change.sh` reports checks green with no RTP code implemented

**Cause:** the working tree has drifted from the shipped baseline — most often an
implementation left in place by a previous run.

**Fix:** `./scripts/lab-start.sh --reset`, which restores `src/`, `config/` and `docs/adr/`
from the starting commit and clears every runtime artifact. To look before resetting:
`git status` and `./scripts/apply-reference.sh status`.

---

## Stage 5.4 — the bounded loop

### `loop.sh check` reports REDUNDANT RETRY (exit 6) where thrashing (exit 4) was expected

**Cause:** nothing under `src/` changed between the two checks. `loop.sh` classifies that as
redundant rather than thrashing, and does not count it as an attempt, because identical code
cannot produce a different result.

**Fix:** this is the designed behaviour, and Stage 5.4 walks all four exits in order: `1`
(continue), `6` (redundant, no code change), `1` again after a change that fixes nothing, then
`4` (thrashing — the code changed and the verifier failed identically). Exit `5` is budget
exhaustion, which needs each attempt to fail *differently*; the guide does not stage it.

### `loop.sh` state seems stuck / stale

**Cause:** `.workflow/state.json` persists across sessions by design.

**Fix:** `./scripts/loop.sh reset` clears it. It's gitignored and safe to delete by hand
at any time (`rm .workflow/state.json`).

---

## General

### `mvn test` fails before you start anything

**Cause:** wrong JDK, or Maven dependencies not yet cached.

**Fix:** `java -version` — needs 17+. If dependencies aren't cached, run
`mvn -B clean test` once with network access before going offline for the session.

### Scripts report "no such file" or "cannot compile"

**Cause:** running from the wrong directory.

**Fix:** every script does `cd "$(dirname "$0")/.." || exit 3` internally, but you still
need to invoke them as `./scripts/<name>.sh` from the repo root (`context-engineering-part-2/`),
not from inside `scripts/`.

### `ctx.sh` or `context-for.sh` says there is no register

**Cause:** `.context/context-register.yaml` doesn't exist — the honest answer before
Stage 1.4.

**Fix:** `./scripts/ctx.sh init --objective "..." --work-item MFIN-2088`, exactly as Stage 1.4
does. There is no template to copy: `ctx.sh` owns the file's shape, and every entry is written
by a command that enforces its rules.

### The context package is garbled or empty after the register was hand-edited

**Cause:** none of this lab's scripts use Python — the register is parsed with a plain `awk`
state machine, deliberately, since this lab's audience is Java engineers who won't reliably
have Python installed. That parser understands only the shape `ctx.sh` writes: two levels of
nesting, one scalar per line, a folded block scalar only on `objective`. A register edited by
hand can drift from that shape and will misparse rather than error clearly.

**Fix:** don't hand-edit it. Every field has a command: `evidence add`, `evidence capture`,
`promote`, `unknown add`, `constraint add`, `decide`. If it is already damaged, run
`./scripts/lab-start.sh --reset` and redo Stage 1.4 onward; `./scripts/ctx.sh check` confirms
that a register is internally consistent.
