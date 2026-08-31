What I would still change before final push
1. P0 — Disable automatic model invocation of the custom agents

This is the biggest remaining Stage 0 integrity issue.

You correctly added:

disable-model-invocation: true

to the skills.

But your three agents currently only contain:

user-invocable: true

They do not contain:

disable-model-invocation: true

Current VS Code/Copilot behavior allows custom agents to be invoked as subagents automatically unless that property is set.

That means Stage 0 says:

“Do not invoke custom agents.”

but Copilot itself could potentially delegate to one.

For this lab, I would put this on all three:

user-invocable: true
disable-model-invocation: true

That gives you exactly what you want:

Participant deliberately selects Investigator / Implementer / Reviewer when the stage introduces them.

Nothing appears early because the model decided to use it.

Definitely fix this.

2. P0 — Stage 0 should explicitly exclude the lab scaffolding from its evidence search

Your Stage 0 prompt is much better:

don't use helper scripts, skills or agents.

But it still says:

“Review MFIN-2088 and the repository directly.”

The repository itself contains:

LAB_ACTION_GUIDE.md
.github/
.context/
.workflow/
outputs/

And LAB_ACTION_GUIDE.md contains the later answers.

A workspace search could legitimately find:

the exact seeded bug
the correct fix
the authority explanation
Stage 4 decision
Stage 5 verifier output

That would make Stage 0 artificially brilliant again.

Change the prompt very slightly:

Review MFIN-2088 using the engineering evidence only: src/, config/, docs/JIRA_TICKETS.md, and docs/adr/. For this first pass, do not use LAB_ACTION_GUIDE.md, outputs/, .context/, .workflow/, .github/, repository helper scripts, skills, or custom agents. Tell me where you would implement the RTP change, what fee behavior should apply, and how you would approach the implementation. Do not modify files.

Now Stage 0 has a real evidence boundary.

That is probably the cleanest possible version of The Helpful Trap.

3. P1 — Fix the Investigator's input contract

There is a direct contradiction inside:

.github/agents/rtp-investigator.agent.md

It says its input contract is:

- Jira ticket
- context register
- Nothing else

But its workflow immediately requires:

context-map output,
authority result,
config,
ADR,
searches.

Those can't both be true.

I'd rewrite the contract to something like:

INPUT

- MFIN-2088 ticket
- participant's promoted context register
- Stage 1 authority/context-map evidence
- config/fee-schedule.yaml
- ADR-0007

Do not receive:
- implementation conversation
- full source file unless the handoff cannot be formed from promoted evidence

Then the role boundary is coherent.

4. P1 — Reviewer input contract is slightly out of order

The reviewer currently says it receives:

latest verify-change.sh result

as part of its starting context.

But Stage 5.1 happens before Stage 5.2 runs the deterministic verifier.

And the reviewer workflow itself later says:

run verify-change.sh.

Pick one.

I'd prefer:

Reviewer starts with
ticket
config
decisions
diff

Then independently reviews.

Afterward:

run verify-change.sh

Now you really have:

fresh reasoning → deterministic second signal

rather than feeding the deterministic answer into the reviewer before it reasons.

That's cleaner.

5. P1 — Subagents are technically present, but the lab never actually teaches the connection

This surprised me.

Your Skills correctly use:

context: fork

and you enable:

"github.copilot.chat.skillTool.enabled": true

Current VS Code behavior for context: fork is exactly what fits this lab: the skill runs in a dedicated subagent context, and only its final result returns to the parent context.

But LAB_ACTION_GUIDE.md never says subagent or forked context.

So you built the feature but aren't teaching why it matters.

I would not add a new exercise.

Add a 2-minute callout around Stage 4:

Custom agent vs forked subagent

The Investigator demonstrates a persistent role/capability boundary. Earlier skills use context: fork: when invoked, their internal work happens in an isolated subagent context and only the compact result returns to the parent. These solve related but different problems:

Custom agent: “Who is doing this work, and what capabilities do they have?”
Forked skill/subagent: “Can this bounded piece of work happen outside my main context and return only its result?”

Then perhaps manually invoke one skill once.

That's enough.

It cleanly covers the advanced context-isolation concept you originally wanted.

6. P1 — docs/INTELLIJ_PATH.md is stale

Your main guide now says JetBrains custom agents are Preview.

Good.

But docs/INTELLIJ_PATH.md still says:

IntelliJ does not currently expose equivalent custom agents, skills, or hooks.

That's no longer accurate.

Current GitHub documentation says:

Custom agents: Preview in JetBrains
Subagents: Preview
Agent skills: Preview
Hooks: not supported in JetBrains

Since this is participant-facing, update it.

Your workshop can absolutely still say:

“We use the manual fallback for custom agents/skills in IntelliJ because Preview behavior is not something we want to make load-bearing during a live workshop.”

That's reasonable.

But distinguish:

available in Preview

from:

not available.

Also fix this stale row:

Stage 7 (no harness)

to:

Stage 7 — Build Beyond the Harness
7. P1 — IntelliJ hook description doesn't match your actual hook architecture

The IntelliJ document says roughly:

hook fires loop.sh on task completion.

Your actual hooks do not do that.

You have:

SessionStart
PreToolUse → quiet-build.sh
PreToolUse → loop-bound.sh

loop.sh is still run explicitly.

The hook merely sees the state afterward and blocks standard edit/write paths when the state says STOP.

So describe it as:

Manual deterministic loop + optional PreToolUse enforcement layer

not:

automatic loop hook.

Same stale wording appears in the beginning of LAB_ACTION_GUIDE.md:

“hook-triggered loop”

I'd change that to:

hook-backed repair bound

or:

optional hook enforcement around the deterministic loop.

8. P1 — One hook statement in Troubleshooting is still too strong

docs/TROUBLESHOOTING.md says:

agent is told to stop → agent cannot proceed.

But your own loop-bound.sh correctly documents:

runCommands can still mutate.

So your code is more honest than your troubleshooting guide.

Use:

instruction-only stop → standard edit/write path is deterministically blocked

That's what you actually built.

And that's still a good lesson.

9. P1 — The config contains a Stage 1 answer you don't really need there

config/fee-schedule.yaml currently contains:

Retired. Never current. Never cite.
LegacyPaymentUtils ... dead code
0 bytecode dependencies
verify with authority.sh

This isn't necessary for a fee config.

And it effectively tells Copilot the result of Stage 1's authority demonstration before the learner runs it.

I'd remove that Legacy section from the config entirely.

Keep:

current effective fee values

The whole point of Stage 1 is:

textual evidence makes Legacy look relevant → bytecode proves otherwise.

Let the participant earn that evidence.

This isn't a fatal issue because Stage 0 no longer depends on a wrong answer, but removing it makes the storyline cleaner.

10. P1 — Your participant archive mode claim failed in my actual validation

Your distribution builder says:

TAR preserves POSIX executable bits.

I generated the TAR from this exact uploaded repo and inspected it.

It contains:

-rw-r--r-- scripts/context-map.sh
-rw-r--r-- .github/hooks/bin/quiet-build.sh

not executable.

The reason is that your Git index records these correctly as 100755, but the working-tree files in the uploaded ZIP are currently 0644.

So:

Git clone

Likely fine — Git index says executable.

Generated tar from this working tree

Not fine.

I'd make the packaging process robust instead of depending on working-tree modes.

For example:

build a temporary staging directory
copy included files
chmod +x scripts/*.sh .github/hooks/bin/*.sh
tar the staging directory

Or after the final commit, use a Git-based archive strategy that honors committed modes.

Until then, don't tell participants:

tar definitely preserves executable bits.

I tested it; this particular tar does not.

11. P1 — Your current Git state is not push-ready

This is mundane but critical.

The ZIP contains a repo whose current branch is:

remediation/plan-execution

and git status shows 24 modified tracked files.

So a plain:

git push

will not push most of the latest hardening changes.

Before pushing:

git status
git diff
git diff --cached

then intentionally:

git add -A
git diff --cached
git commit -m "finalize context engineering part 2 lab"

Then generate the participant artifact from the committed state, not before.

Also add:

dist/

unless you intentionally want generated archives tracked.

12. Important: decide what “push to GitHub” means

The source branch still contains:

ARCHITECTURE.md
changes.md
validation reports
completed context examples
handoff example
facilitator fixtures

Your participant distribution correctly excludes them.

Therefore:

If GitHub is the author/source repository

and Fidelity gets:

participant-distribution

Good.

If Fidelity participants will do:
git clone <this exact branch>

NO-GO.

Because their Copilot can discover all of the answer-bearing authoring material.

In that case, either:

create a clean participant branch, or
publish the generated participant artifact as the release asset they download.

This is the biggest deployment decision, not a curriculum issue.

Minor cleanup

A few things I'd fix but wouldn't block delivery individually:

pom.xml still says:

PIT mutation testing — Stage 4.

Mutation testing is now explicitly out of scope and not Stage 4. Remove the stale stage reference.

Stage 4 currently emits:

HUMAN DECISION REQUIRED

but the story now correctly acknowledges the evidence already strongly identifies current config.

I'd make this:

HUMAN RATIFICATION / GOVERNANCE RECORD REQUIRED

That is more truthful.

Add explicit name: fields to the custom agents:
name: RTP Investigator
name: RTP Implementer
name: RTP Reviewer

so the UI label exactly matches the guide rather than depending on filename formatting.

Jeff verdict

At this point Jeff's original criticism is essentially solved.

The progression is now:

USE prepared mechanism
        ↓
DECONSTRUCT how it works
        ↓
UNDERSTAND transferable pattern
        ↓
APPLY on a different claim
        ↓
BUILD a new mechanism with Copilot
        ↓
VALIDATE KEEP / DISCARD / FAILURE
        ↓
DECIDE how it belongs in a real workflow

That is not:

“Run the shell scripts we gave you.”

anymore.

Jeff gap resolution: 9.3/10

The remaining 0.7 is mostly around making the customization/isolation story fully explicit and ensuring the participant artifact truly behaves the way the curriculum claims.

Final push recommendation

I would make these 8 fixes before calling it final:

Add disable-model-invocation: true to all three custom agents.
Scope Stage 0 explicitly away from lab-scaffolding files.
Fix Investigator input-contract contradiction.
Fix Reviewer starting-context ordering.
Add the small forked skill/subagent explanation/demo.
Update INTELLIJ_PATH.md + stale hook wording.
Remove the Legacy answer from fee-schedule.yaml.
Fix participant archive executable permissions and commit the current dirty working tree.