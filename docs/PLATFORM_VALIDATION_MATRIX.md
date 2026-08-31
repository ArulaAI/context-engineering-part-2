# Platform Validation Matrix

**Created:** 2026-08-29  
**Phase:** 3.2  
**Scope:** Four environment combinations — VS Code + Windows, VS Code + macOS, IntelliJ + Windows, IntelliJ + macOS  
**Remediation rows:** R5 (IDE support), R6 (OS portability)

---

## How to Read This Table

| Status | Meaning |
|---|---|
| PASS | Verified or strongly evidenced by code analysis on this platform |
| ANALYZED | Code review says it should work; requires live test to confirm |
| KNOWN ISSUE | Identified problem with documented workaround |
| NOT SUPPORTED | Platform combination cannot support this capability; reason documented |
| NOT TESTED | No analysis performed |

**What was analyzed:** All scripts in `scripts/`, hooks in `.github/hooks/bin/`, skills in `.github/skills/`, agent definitions in `.github/agents/`, `.vscode/settings.json`, `.gitattributes`, `docs/INTELLIJ_PATH.md`, and `docs/verify.sh`.

**What cannot be validated here:** Actual runtime behavior on macOS or inside IntelliJ's plugin layer. Those combinations are marked ANALYZED where code review is favorable and KNOWN ISSUE where a gap is identified.

---

## Environment Matrix

### Capability Categories

| # | Capability |
|---|---|
| 1 | Setup — clone, toolchain check (`java 17+`, `mvn`, `jshell`, `jdeps`, `git`), `mvn clean test` baseline |
| 2 | Shell execution — all `scripts/*.sh` run from the terminal |
| 3 | Agent/skill availability — custom agents and skills in Copilot |
| 4 | Hook behavior — `loop-bound.sh`, `session-constraints.sh`, `quiet-build.sh` fire on appropriate events |
| 5 | Shell assumptions — hash fallback chain, no `bc`, LF enforcement, no Python |
| 6 | Fallback path — manual terminal equivalents for IDE-specific features |
| 7 | Deterministic checks — `verify-change.sh` check 4 (`jshell`), `verify.sh` A5 (awk in-place fix) |
| 8 | Grading/verification — `docs/verify.sh` facilitator script |

---

## VS Code + Windows

**Terminal requirement:** Git Bash (documented in LAB_ACTION_GUIDE.md Platform Requirements callout).

| Capability | Status | Evidence / Notes |
|---|---|---|
| 1. Setup | PASS | `docs/verify.sh` A1 checks `java`, `mvn`, `jshell`, `jdeps`, `git` via `command -v`. Git Bash on Windows provides all of these via the JDK and Maven installations. |
| 2. Shell execution | PASS | All scripts use `#!/usr/bin/env bash` and `set -uo pipefail`. No `bash`-isms beyond POSIX + arrays (Bash 3.2+ compatible). Git Bash ships Bash 5.x on modern Windows. `.gitattributes` enforces `eol=lf` on `*.sh` preventing CRLF breakage on checkout. `files.eol: "\n"` in `.vscode/settings.json` prevents CRLF on editor save. |
| 3. Agent/skill availability | PASS | VS Code + GitHub Copilot extension supports custom agents (`.github/agents/*.agent.md`) and skills (`.github/skills/*/SKILL.md`) natively. Platform is Windows — no OS dependency on agent/skill loading. |
| 4. Hook behavior | PASS | `.github/hooks/bin/loop-bound.sh`, `session-constraints.sh`, and `quiet-build.sh` use `grep`, `sed`, `printf` — all available in Git Bash. Hook payload parsing uses pure grep/sed (no Python, confirmed by script headers). `cat` stdin reads correctly in Git Bash. |
| 5. Shell assumptions — hash fallback | PASS | `scripts/loop.sh` `hash_verdict()` checks `shasum` first, then `sha256sum`, then `cksum`. Git for Windows bundles `sha256sum`; `cksum` is in coreutils. At least one branch will succeed. |
| 5. Shell assumptions — no `bc` | PASS | `docs/verify.sh` A2 uses `awk '{s+=$1} END {print s+0}'` for arithmetic (both occurrences). No `bc` dependency remains (F7 fix verified in matrix row F7: PASS). |
| 5. Shell assumptions — no Python | PASS | `docs/verify.sh` A5 in-place fix uses `awk` + temp file + `mv` (pure POSIX). `context-for.sh` uses awk state machine. `loop.sh` uses `sed`/`grep` for state reads. All script headers confirm "No Python." |
| 5. Shell assumptions — LF | PASS | `.gitattributes` sets `*.sh text eol=lf`, `*.yaml text eol=lf`, `*.yml text eol=lf`, `*.md text eol=lf`. VS Code `files.eol: "\n"` prevents editor-written CRLF. Covers both git checkout and editor save paths. |
| 6. Fallback path | PASS | VS Code is the primary path. All skills and hooks are designed for this environment. `chat.tools.terminal.autoApprove` in `.vscode/settings.json` whitelists `scripts/*.sh` and blocks raw `mvn` invocations and `rm`. No fallback needed. |
| 7. Deterministic checks | PASS | `jshell` is on PATH (JDK 17+). `verify-change.sh` check 4 calls `jshell --class-path target/classes`. `docs/verify.sh` A1 explicitly checks for `jshell`. |
| 8. Grading/verification | PASS | `docs/verify.sh` A1–A5 use: `command -v` (bash builtin), `java -version` + `sed`, `mvn -q`, `grep`, `awk`, `git apply`, `git checkout --`. All available in Git Bash. Arithmetic via `awk`, not `bc`. |

**Overall: PASS (code-evidenced).** Requires live dry-run for timing confirmation (R8).

---

## VS Code + macOS

**Terminal requirement:** macOS default terminal (zsh or bash). Both are POSIX-compatible.

| Capability | Status | Evidence / Notes |
|---|---|---|
| 1. Setup | ANALYZED | Same toolchain requirements as Windows. macOS ships `git`; JDK 17+ and Maven installed separately (Homebrew or download). `docs/verify.sh` A1 checks all required tools. No macOS-specific blocker identified in code. |
| 2. Shell execution | ANALYZED | All scripts use `#!/usr/bin/env bash`. macOS ships Bash 3.2.57 (license restriction). Scripts use `+=` array append and `<<<` here-string — both supported in 3.2+. `context-for.sh` `get_field()` explicitly avoids `IFS=<ctrl-char> read -a` due to a documented Bash 3.2 quirk (uses `tr` to newlines + plain `while read` instead). No CRLF concern on macOS. |
| 3. Agent/skill availability | ANALYZED | VS Code + GitHub Copilot extension on macOS supports the same agent/skill model as Windows. No OS-specific gap expected. Requires live test to confirm Copilot extension version parity. |
| 4. Hook behavior | ANALYZED | Hook scripts are pure bash/grep/sed/printf — no OS-specific tools. `cat` stdin works identically. No macOS-specific blocker identified. Requires live test to confirm hook firing order. |
| 5. Shell assumptions — hash fallback | ANALYZED | macOS ships `shasum` (first branch of `hash_verdict()`). Fallback chain will succeed at the first branch. No issue expected. |
| 5. Shell assumptions — no `bc` | ANALYZED | `docs/verify.sh` uses `awk` arithmetic — no `bc`. macOS ships `bc` but the script no longer uses it; this is a non-issue in either direction. |
| 5. Shell assumptions — no Python | ANALYZED | Same analysis as Windows. No Python dependency in any script. `docs/verify.sh` A5 awk fix is OS-independent. |
| 5. Shell assumptions — LF | ANALYZED | macOS git does not apply CRLF conversion by default (`core.autocrlf` defaults to `false`). `.gitattributes` still enforces `eol=lf` but the risk is lower than Windows. No expected issue. |
| 6. Fallback path | ANALYZED | VS Code is the primary path — same as Windows. No macOS-specific fallback needed. |
| 7. Deterministic checks | ANALYZED | `jshell` available with JDK 17+. `verify-change.sh` check 4 has no OS-specific dependencies. `mktemp` behavior on macOS: `mktemp` without `-t` works on both GNU and BSD. All script uses are compatible. |
| 8. Grading/verification | ANALYZED | `docs/verify.sh` uses standard POSIX tools. macOS versions of `grep`, `sed`, `awk` are BSD variants — the scripts use basic patterns that are compatible with both GNU and BSD. One risk: `sed -E` (extended regex) — tested pattern `s/.*"([0-9]+).*/\1/` is BSD-compatible. |

**Overall: ANALYZED — requires live test.** No blockers identified by code analysis. BSD vs GNU tool variants are the main risk surface; patterns used are conservative.

---

## IntelliJ + Windows

**Terminal requirement:** Git Bash configured in IntelliJ Terminal settings (documented in `docs/INTELLIJ_PATH.md`).

| Capability | Status | Evidence / Notes |
|---|---|---|
| 1. Setup | ANALYZED | Documented in `docs/INTELLIJ_PATH.md` checklist: IntelliJ terminal → Git Bash, `mvn clean test` → BUILD SUCCESS, `./scripts/context-map.sh RTP` → routing table. Setup path is documented; requires live test. |
| 2. Shell execution | ANALYZED | Once IntelliJ's terminal is configured to Git Bash, all scripts run identically to VS Code + Windows. `docs/INTELLIJ_PATH.md` documents this explicitly: "Run `./scripts/*.sh` from IntelliJ's built-in terminal — Works as written." |
| 3. Agent/skill availability | KNOWN ISSUE | IntelliJ Copilot plugin does not expose custom agents or skills in the same way as the VS Code extension. **Documented fallbacks (from `docs/INTELLIJ_PATH.md`):** (a) Skills → run underlying script directly from terminal; `/context-map` → `./scripts/context-map.sh RTP`; `/context-run` → `./scripts/context-run.sh`; `/verify-change` → `./scripts/verify-change.sh`; `/context-package` → `./scripts/context-for.sh`. (b) RTP Investigator/Implementer agents → manual system prompt pasted at start of Copilot Chat session. (c) RTP Reviewer agent → new Copilot Chat panel + manually pasted agent rules. **One objective has no equivalent:** live capability-boundary proof (Stage 4.2) — the tool list cannot be enforced at the plugin layer; documented as discussion exercise. |
| 4. Hook behavior | KNOWN ISSUE | `loop-bound.sh`, `session-constraints.sh`, `quiet-build.sh` are VS Code Copilot hooks. IntelliJ Copilot does not fire these hooks. **Documented fallback:** run `scripts/loop.sh` directly from terminal. `loop.sh` itself (the bound + thrashing detector) is fully functional; only the automatic hook trigger is absent. `quiet-build.sh`'s deny gate on raw `mvn` is absent — participants in IntelliJ can run verbose Maven without being blocked (reduces learning impact of Stage 2 but does not break the lab). |
| 5. Shell assumptions — hash fallback | ANALYZED | Same as VS Code + Windows. Git Bash + `sha256sum` available. Same analysis applies. |
| 5. Shell assumptions — no `bc` | ANALYZED | Same as VS Code + Windows. |
| 5. Shell assumptions — no Python | ANALYZED | Same as VS Code + Windows. |
| 5. Shell assumptions — LF | ANALYZED | Same risk profile as VS Code + Windows. `.gitattributes` and Git Bash handle this. |
| 6. Fallback path | PASS | `docs/INTELLIJ_PATH.md` documents learning-equivalent fallbacks for every VS Code-specific mechanism. Table summarized: context-map/run/package skills → direct script invocation (identical output); agents → manual system prompt (instruction boundary, not capability boundary); hooks → direct terminal invocation of scripts; fresh-context review → new Copilot Chat panel. All CE patterns (discover, authority, reduce, promote, package, isolate, handoff, verify, review, rehydrate) are reachable via terminal. |
| 7. Deterministic checks | ANALYZED | `verify-change.sh` and `verify.sh` run from terminal — no IDE dependency. Same analysis as VS Code + Windows applies once Git Bash terminal is configured. |
| 8. Grading/verification | ANALYZED | `docs/verify.sh` runs from terminal. Same analysis as VS Code + Windows. No IDE-specific dependency. |

**Overall: ANALYZED — requires live test.** Known issues are documented with fallbacks. Two capability gaps have no equivalent: (1) automatic hook firing, (2) live capability-boundary proof. Both are acceptable per `docs/INTELLIJ_PATH.md`: hook automation is a VS Code convenience, not the lesson; the capability-boundary proof is treated as a discussion exercise.

---

## IntelliJ + macOS

**Terminal requirement:** macOS default shell in IntelliJ terminal (no configuration needed — documented in `docs/INTELLIJ_PATH.md`).

| Capability | Status | Evidence / Notes |
|---|---|---|
| 1. Setup | ANALYZED | macOS default terminal in IntelliJ is POSIX-compatible. No Git Bash setup required. Same JDK 17+ / Maven prerequisites as other combinations. `docs/INTELLIJ_PATH.md` explicitly states: "The default shell terminal in IntelliJ is already POSIX-compatible. No setup required beyond the lab's standard prerequisites." |
| 2. Shell execution | ANALYZED | IntelliJ terminal on macOS uses zsh (default since Catalina) or bash. All scripts use `#!/usr/bin/env bash`; invoking them by path runs bash explicitly. Same Bash 3.2 compatibility considerations as VS Code + macOS. No CRLF concern on macOS. |
| 3. Agent/skill availability | KNOWN ISSUE | Same as IntelliJ + Windows. IntelliJ Copilot does not expose VS Code-style agents or skills. Same documented fallbacks apply: direct script invocation for skills; manual system prompt for agents; discussion exercise for capability-boundary proof. |
| 4. Hook behavior | KNOWN ISSUE | Same as IntelliJ + Windows. VS Code hooks do not fire in IntelliJ. Direct terminal invocation of `scripts/loop.sh` provides the bound; quiet-build gate is absent. |
| 5. Shell assumptions — hash fallback | ANALYZED | macOS ships `shasum` — first branch of `hash_verdict()` succeeds. Better coverage than Windows (no need for the `sha256sum` fallback). |
| 5. Shell assumptions — no `bc` | ANALYZED | Same analysis as VS Code + macOS. `awk` arithmetic used; `bc` not invoked. |
| 5. Shell assumptions — no Python | ANALYZED | Same analysis as VS Code + macOS. No Python dependency. |
| 5. Shell assumptions — LF | ANALYZED | macOS git default behavior does not add CRLF. `.gitattributes` provides defense-in-depth. Low risk. |
| 6. Fallback path | PASS | Same fallback table as IntelliJ + Windows. Terminal-based fallbacks are IDE-agnostic. macOS terminal is POSIX-native — fallback quality is equivalent to or better than the Windows path. |
| 7. Deterministic checks | ANALYZED | Same as IntelliJ + Windows. `verify-change.sh` and `verify.sh` have no IDE dependency. BSD `awk`/`grep`/`sed` compatibility — same conservative pattern analysis as VS Code + macOS. |
| 8. Grading/verification | ANALYZED | `docs/verify.sh` from terminal. BSD vs GNU tool variant risk (same as VS Code + macOS). `sed -E`, `grep -E`, `awk` patterns reviewed as BSD-compatible. |

**Overall: ANALYZED — requires live test.** Easiest setup of the four combinations (no terminal configuration needed). Same known issues as IntelliJ + Windows for agent/skill/hook gaps. macOS POSIX-native terminal removes the Git Bash configuration risk.

---

## Summary Table

| Environment | Setup | Shell exec | Agents/Skills | Hooks | Shell assumptions | Fallback | Det. checks | Grading | Overall |
|---|---|---|---|---|---|---|---|---|---|
| VS Code + Windows | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **PASS** |
| VS Code + macOS | ANALYZED | ANALYZED | ANALYZED | ANALYZED | ANALYZED | ANALYZED | ANALYZED | ANALYZED | **ANALYZED** |
| IntelliJ + Windows | ANALYZED | ANALYZED | KNOWN ISSUE | KNOWN ISSUE | ANALYZED | PASS | ANALYZED | ANALYZED | **ANALYZED** |
| IntelliJ + macOS | ANALYZED | ANALYZED | KNOWN ISSUE | KNOWN ISSUE | ANALYZED | PASS | ANALYZED | ANALYZED | **ANALYZED** |

---

## Known Issues Summary

| Issue | Affected Combinations | Workaround | Severity |
|---|---|---|---|
| Agent/skill layer absent in IntelliJ Copilot | IntelliJ + Windows, IntelliJ + macOS | Direct terminal script invocation (identical output); manual system prompt for agents | Medium — fallback is documented and tested in spirit |
| Hook auto-firing absent in IntelliJ | IntelliJ + Windows, IntelliJ + macOS | Run `scripts/loop.sh` directly from terminal; bound and thrashing detection still function | Low — hook automation is a convenience, not the lesson |
| Live capability-boundary proof (Stage 4.2) not available in IntelliJ | IntelliJ + Windows, IntelliJ + macOS | Discussion exercise — learning objective is still reachable | Low — documented as expected limitation in `docs/INTELLIJ_PATH.md` |
| Git Bash terminal setup required in IntelliJ on Windows | IntelliJ + Windows only | Documented step-by-step in `docs/INTELLIJ_PATH.md`; without it, PowerShell breaks all scripts | Medium — one-time setup; documented with failure symptom |
| BSD vs GNU tool variants on macOS | VS Code + macOS, IntelliJ + macOS | Scripts use conservative patterns verified compatible with BSD `awk`/`grep`/`sed`; requires live test | Low — code analysis is favorable; no pattern flagged as GNU-only |

---

## Pending Live Tests

The following combinations and capabilities require a live dry-run to confirm ANALYZED status:

| Test | Combination | What to observe |
|---|---|---|
| T1 | VS Code + macOS | Full `docs/verify.sh` run — confirm BSD tool compatibility and hook firing |
| T2 | VS Code + macOS | Stage 4 agent mode — confirm IntelliJ-equivalent experience not needed (VS Code primary) |
| T3 | IntelliJ + Windows | Terminal setup procedure — confirm Git Bash prompt appears, `context-map.sh RTP` runs |
| T4 | IntelliJ + Windows | Manual agent fallback — paste system prompt in Copilot Chat, confirm instruction boundary behavior |
| T5 | IntelliJ + Windows | `loop.sh` direct invocation — confirm thrashing detector and exit codes function correctly |
| T6 | IntelliJ + macOS | No terminal setup needed — confirm default shell runs all scripts |
| T7 | IntelliJ + macOS | Same as T4/T5 but macOS terminal |
| T8 | All (except VS Code+Windows) | `docs/verify.sh` A5 awk in-place fix — confirm `mktemp` and `awk` produce correct result |

---

## Relationship to Remediation Acceptance Matrix

| Matrix Row | Claim | Platform Validation Finding |
|---|---|---|
| R5 | VS Code + IntelliJ both supported | VS Code + Windows: PASS. IntelliJ paths: ANALYZED — fallbacks documented in `docs/INTELLIJ_PATH.md`. One VS Code-only objective (capability-boundary live proof) is documented. R5 status: IN PROGRESS pending live IntelliJ test (T3–T7 above). |
| R6 | Windows / Mac path viable | Windows (Git Bash): PASS — `bc` removed (F7), `.gitattributes` added (F8), `files.eol` added. macOS: ANALYZED — BSD tool compatibility is favorable by code analysis; live test needed. R6 status: PASS for Windows; macOS requires live confirmation. |

---

## Code Evidence Summary

| Evidence | File | Finding |
|---|---|---|
| LF enforcement | `.gitattributes` | `*.sh`, `*.yaml`, `*.yml`, `*.md` all `text eol=lf` |
| Editor LF enforcement | `.vscode/settings.json` | `"files.eol": "\n"` present |
| No `bc` in facilitator script | `docs/verify.sh` lines 60–65 | Both arithmetic uses replaced with `awk '{s+=$1} END {print s+0}'` |
| Hash fallback chain | `scripts/loop.sh` lines 75–82 | `shasum` → `sha256sum` → `cksum` in order |
| No Python in any script | All `scripts/*.sh`, `.github/hooks/bin/*.sh` | All headers state "No Python"; awk/sed/grep used throughout |
| Bash 3.2 `IFS` quirk workaround | `scripts/context-for.sh` lines 178–185 | Uses `tr` + `while read` instead of `IFS=<ctrl-char> read -a` |
| Git Bash terminal setup | `docs/INTELLIJ_PATH.md` lines 41–49 | Step-by-step setup with expected prompt confirmation |
| IntelliJ fallback table | `docs/INTELLIJ_PATH.md` lines 218–225 | Full divergence summary with fidelity ratings |
| VS Code tool gate | `.vscode/settings.json` lines 44–56 | `chat.tools.terminal.autoApprove` whitelist + `mvn` deny; fallback when hooks unavailable |
