# Context Lifecycle Lab — Troubleshooting

Fallbacks for the mechanisms most likely to behave differently across Copilot builds and
environments. Every fallback below still teaches the stage's lesson — none of them are
"skip this stage."

---

## Stage 4 — agents / isolation

### `Context Experiment` reports only one result, or refuses to run

**Cause:** it was given one context instead of two, or the build does not honour the
`agents:` property so its dispatch to `context-probe` never fired.

**Fix:** confirm your message names both **Context A** and **Context B**. If it does and
you still get one result, check whether `context-probe` appears in the mode dropdown. If
it does not, run the comparison by hand in two separate chats, which Stage 3.3 documents
in full under "The manual version." The isolation is then yours to perform rather than
the harness's, and the comparison is the same.

### Both probes return the same answer

**Cause:** none. Agreement is a legitimate outcome.

**Fix:** nothing. Stage 3.3's graded question is not whether the answers differ, it is
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

**Cause:** `docs/adr/ADR-0007-fee-schedule.md`'s `Status` field was already changed to
`Superseded` in a prior run.

**Fix:**
```bash
git log --oneline -- docs/adr/ADR-0007-fee-schedule.md
git checkout <commit-before-your-edit> -- docs/adr/ADR-0007-fee-schedule.md
```
Or simply re-open the file and change `**Status:** Superseded by config/fee-schedule.yaml`
back to `**Status:** Proposed`, then re-commit.

### `send: false` doesn't pause the handoff

**Cause:** the handoff auto-approval mechanism isn't enforced on this build.

**Fix:** Run the approval as a spoken gate: nobody proceeds to `rtp-implementer` until a
person has read `.workflow/HANDOFF.md` aloud and said "approved." Same lesson, no
dependency on the feature.

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

### `verify-change.sh` reports all four checks green with no RTP code implemented

**Cause:** the working tree has drifted from the shipped baseline (a stray file, an
already-applied fixture, or an already-fixed implementation left over from a prior dry
run).

**Fix:** `git status` and `git log --oneline -5` to see what's actually there.
`git checkout -- src/main/java/com/meridian/payments/PaymentService.java` to restore the
committed baseline if needed.

---

## Stage 5.3 — the bounded loop

### `loop.sh check` always reports CONTINUE, never THRASHING

**Cause:** you changed the code between checks — even a whitespace change alters the
verdict text and its hash.

**Fix:** This is expected, not a bug — Stage 5.3's thrashing exercise specifically calls
for running `check` twice with **no code change** in between. If you want to demonstrate
budget exhaustion (exit 5) instead, you'd need each attempt to fail differently — harder
to stage on demand, so the guide focuses on thrashing, which is reliably reproducible.

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

### `context-for.sh` says "nothing has been promoted yet"

**Cause:** `.context/context-register.yaml` doesn't exist — this is the honest answer
before Stage 3.1.

**Fix:** `cp .context/context-register.template.yaml .context/context-register.yaml` and
fill it in following `.context/README.md`'s required keys.

### `context-for.sh` produces a garbled or empty package on a hand-edited register

**Cause:** none of this lab's scripts use Python — `context-for.sh` parses
`.context/context-register.yaml` with a plain `awk` state machine, deliberately, since
this lab's audience is Java engineers who won't reliably have Python installed. That
parser only understands the exact flat shape in
`.context/context-register.template.yaml`: two levels of nesting, one scalar per line,
and a multi-line block scalar only on `objective`'s `>`. A hand-edited register that
drifts from that shape (wrong indentation under a folded block, a nested list, a value
that spans multiple lines anywhere else) will silently misparse rather than error clearly.

**Fix:** diff your register against `.context/context-register.template.yaml`'s
structure, not just its content, and fix indentation to match exactly.
