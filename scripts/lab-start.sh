#!/usr/bin/env bash
#
# lab-start.sh — preflight, then record where this run of the lab started.
#
# Three jobs, all deterministic:
#   1. Refuse to start if a tool the lab depends on is missing. A missing tool must be
#      visible now, not silently degrade an evidence check later.
#   2. Record the starting commit in .workflow/baseline. verify-change.sh measures the
#      scope of your change against THIS commit, not against HEAD — so committing your
#      work in Stage 5 cannot make the scope check pass vacuously.
#
#   3. Refuse to start on top of a previous run's state. A leftover register or handoff
#      would make later stages look already-done and would break `ctx.sh init`.
#
# usage: scripts/lab-start.sh [--reset]
#   --reset  delete every runtime artifact a previous run left behind, then start
# exit 0 ready · 3 a required tool is missing · 4 the baseline build is not green
#      · 5 a previous run's state is still here (re-run with --reset)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

# Every path below is runtime state, listed in .gitignore for the same reason: it is one
# participant's own engineering state and it must never be inherited by the next run.
STATE="
.context/context-register.yaml
.context/evidence-ledger.yaml
.context/bundles
.workflow/baseline
.workflow/HANDOFF.md
.workflow/handoff-consumed
.workflow/outcome.yaml
.workflow/review-package.md
.workflow/state.json
.workflow/attempts.tsv
.workflow/last-verdict.txt
"

reset=0
[ "${1:-}" = "--reset" ] && reset=1

stale=""
for p in $STATE; do [ -e "$p" ] && stale="$stale $p"; done
for p in .context/context-map-*.md .context/outline-*.md .context/context-run-*.md .workflow/fault-backup.*; do
  [ -e "$p" ] && stale="$stale $p"
done

if [ -n "$stale" ] && [ "$reset" -eq 0 ]; then
  echo "lab-start: a previous run's state is still in this working tree:" >&2
  for p in $stale; do echo "  $p" >&2; done
  echo "" >&2
  echo "Those files are durable engineering state. Later stages would treat them as already" >&2
  echo "done, and 'ctx.sh init' refuses to overwrite a register. To start the lab cleanly:" >&2
  echo "  ./scripts/lab-start.sh --reset" >&2
  exit 5
fi

if [ "$reset" -eq 1 ]; then
  if [ -n "$stale" ]; then
    for p in $stale; do rm -rf "$p"; done
    echo "Reset: cleared $(echo $stale | wc -w) runtime artifact(s) from a previous run."
  else
    echo "Reset: nothing to clear — no previous run state found."
  fi
  git checkout -- src config docs/adr 2>/dev/null || true
fi

missing=""
for tool in git mvn java javac jdeps javap jshell awk sed grep; do
  command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done
if [ -n "$missing" ]; then
  echo "lab-start: missing required tool(s):$missing" >&2
  echo "jdeps, javap and jshell ship with every JDK 17+. If java works but they do not," >&2
  echo "a java-only shim (e.g. Windows' javapath) is ahead of your JDK's bin/ on PATH." >&2
  exit 3
fi

echo "Tools: git mvn java javac jdeps javap jshell — all present."

if ! bash scripts/verify.sh >/tmp/lab-start-verify.$$ 2>&1; then
  echo "lab-start: the baseline build is not green:" >&2
  cat /tmp/lab-start-verify.$$ >&2
  rm -f /tmp/lab-start-verify.$$
  exit 4
fi
echo "Baseline: $(cat /tmp/lab-start-verify.$$)"
rm -f /tmp/lab-start-verify.$$

mkdir -p .workflow
git rev-parse HEAD > .workflow/baseline
echo "Recorded starting commit $(cut -c1-7 .workflow/baseline) in .workflow/baseline"
echo "Ready."
