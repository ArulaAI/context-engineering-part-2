# Context Engineering, Part 2 — Meridian Payments

A hands-on lab. You take one ticket (MFIN-2088, an approved fee rule) through a full
engineering cycle, and every stage leaves behind state you can prove rather than a
conversation you have to remember.

The work item is real: two committed sources give two different RTP rates, neither claims
authority over the other, and no tool in the repository can settle which one Meridian
approved. Getting from there to a verified, reviewed, committed change is the lab.

## Start here

```bash
mvn clean test
./scripts/lab-start.sh --reset
```

Expected: `Tests run: 5, Failures: 0`, then `Ready.`

Then open **[LAB_ACTION_GUIDE.md](LAB_ACTION_GUIDE.md)** and work through Stages 0–7 in
order. Everything else in this repository is either the scenario or a tool the guide tells
you when to run.

Open this folder as its own editor window, not as a subfolder of another workspace —
Copilot resolves `.github/agents/`, `.github/skills/` and `.github/hooks/` per workspace
root.

## Requirements

JDK 17+ (a full JDK — the lab uses `jdeps`, `javap` and `jshell`), Maven, Git, and a POSIX
shell. On Windows that means Git Bash; `lab-start.sh` refuses to start if any required tool
is missing rather than degrading a later evidence check.

## What lives where

| Path | What it is |
|---|---|
| `LAB_ACTION_GUIDE.md` | The runbook. Stages 0–7, every command, every expected result. |
| `AGENTS.md` | The rules agents work under, and where engineering state lives. |
| `docs/JIRA_TICKETS.md` | MFIN-2088 — the work item. |
| `docs/adr/`, `config/` | The scenario's two conflicting pricing sources. |
| `scripts/` | The lab's tools. Each one answers a question a chat cannot. |
| `.github/agents/` | Six agents, each with a deliberate tool list. Two have `tools: []`. |
| `.github/skills/` | Slash commands that wrap the scripts. |
| `reference/` | The answer key, outside `src/` so it never compiles or leaks early. |
| `docs/INTELLIJ_PATH.md` | Every VS Code mechanism mapped to an IntelliJ equivalent. |
| `docs/TROUBLESHOOTING.md` | Fallbacks, by symptom. |
| `docs/facilitator/` | Facilitator material. Not for participants. |

State the lab creates — `.context/`, `.workflow/`, `docs/approvals/` — is gitignored. It is
each participant's own engineering state, and committing it would hand the next person a
solved lab.

## Re-running it

`./scripts/lab-start.sh --reset` restores `src/`, `config/` and `docs/adr/` from the
starting commit and clears every runtime artifact, so the lab is repeatable in the same
clone. Facilitators can verify the whole terminal path in one command with
`./scripts/dry-run.sh`.
