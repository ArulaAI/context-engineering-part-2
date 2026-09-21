#!/usr/bin/env bash
#
# lab-start.sh — preflight, then record where this run of the lab started.
#
# Two jobs, both deterministic:
#   1. Refuse to start if a tool the lab depends on is missing. A missing tool must be
#      visible now, not silently degrade an evidence check later.
#   2. Record the starting commit in .workflow/baseline. verify-change.sh measures the
#      scope of your change against THIS commit, not against HEAD — so committing your
#      work in Stage 5 cannot make the scope check pass vacuously.
#
# usage: scripts/lab-start.sh
# exit 0 ready · 3 a required tool is missing · 4 the baseline build is not green

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

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
