#!/usr/bin/env bash
# make_participant_distribution.sh — build a clean participant archive.
#
# Excludes all internal authoring, validation, facilitation, and
# curriculum-development artifacts.  Prints a manifest so the exclusion
# is auditable.
#
# Usage:  bash scripts/make_participant_distribution.sh
#         bash scripts/make_participant_distribution.sh --dry-run   # manifest only

set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

DIST_DIR=dist
OUT="$DIST_DIR/participant-distribution.zip"

# ── Exclusion list ──────────────────────────────────────────────────
# Each pattern is one line.  Comments and blank lines are stripped.
EXCLUDE_PATTERNS=$(cat <<'PATTERNS'
# Research / review / critique reports
docs/research/
docs/review/

# Internal validation & acceptance material
docs/ADVERSARIAL_VALIDATION_REPORT.md
docs/GO_NOGO_EVIDENCE.md
docs/REDESIGN_CONTRACT.md
docs/REMEDIATION_ACCEPTANCE_MATRIX.md
docs/TRANSFER_VALIDATION_FRAMEWORK.md
docs/PLATFORM_VALIDATION_MATRIX.md

# Facilitator-only material
docs/TIMED_FACILITATION_GUIDE.md
docs/VERIFICATION.md
docs/verify.sh

# Facilitator fixtures (used by docs/verify.sh, not by participants)
fixtures/rtp-correct.awk
fixtures/sepa-.*

# Answer-bearing artifacts that spoil the lab
ARCHITECTURE.md
changes.md

# Future-state answer examples (contain Stage 4+ decisions)
\.context/context-register-completed.yaml.example
\.context/context-register.yaml.example
\.workflow/HANDOFF.md.example

# Implementation plans / prompt files
FINAL_IMPLEMENTATION_PLAN.md
plan.md
review.md
prompt5.md

# Superpowers / orchestration artifacts
\.superpowers/

# Journey logs
journey/

# Claude Code config
\.claude/

# Workflow runtime state (examples are kept; live state is gitignored)
\.workflow/state\.json$
\.workflow/HANDOFF\.md$

# This script itself (meta — not participant-facing)
scripts/make_participant_distribution.sh
PATTERNS
)

# Build the grep -E pattern: strip comments, blank lines, join with |
REGEX=$(echo "$EXCLUDE_PATTERNS" \
  | grep -v '^\s*#' \
  | grep -v '^\s*$' \
  | sed 's/^/^/' \
  | paste -sd '|' -)

TMP_ALL=$(mktemp)
TMP_PART=$(mktemp)
TMP_EXCL=$(mktemp)
trap 'rm -f "$TMP_ALL" "$TMP_PART" "$TMP_EXCL"' EXIT

# All tracked files
git ls-files > "$TMP_ALL"

# Partition
grep -E "$REGEX" "$TMP_ALL" > "$TMP_EXCL" || true
grep -v -E "$REGEX" "$TMP_ALL" > "$TMP_PART"

TOTAL=$(wc -l < "$TMP_ALL")
KEPT=$(wc -l < "$TMP_PART")
REMOVED=$(wc -l < "$TMP_EXCL")

echo ""
echo "Participant distribution manifest"
echo "============================================"
echo "  tracked files:   $TOTAL"
echo "  included:        $KEPT"
echo "  excluded:        $REMOVED"
echo ""
echo "Excluded files:"
sed 's/^/  - /' "$TMP_EXCL"
echo ""

if $DRY_RUN; then
  echo "(dry run — no archive created)"
  exit 0
fi

mkdir -p "$DIST_DIR"

# Tarball is the primary distribution: it preserves POSIX executable bits, which
# ZIP may not restore after extraction on macOS/Linux. We also emit a ZIP for
# Windows users whose tooling prefers it, but Git Bash on Windows can unpack
# .tar.gz just as easily.
TAR_OUT="$DIST_DIR/participant-distribution.tar.gz"
rm -f "$TAR_OUT"
(cd . && tar -czf "$TAR_OUT" -T "$TMP_PART")
echo "Wrote $TAR_OUT  ($KEPT files, executable bits preserved)"

if command -v zip >/dev/null 2>&1; then
  rm -f "$OUT"
  (cd . && zip -q -@ "$OUT" < "$TMP_PART")
  echo "Wrote $OUT  ($KEPT files)"
  echo ""
  echo "NOTE: if you extract the ZIP on Unix and ./scripts/*.sh are not executable,"
  echo "use the .tar.gz archive instead, or run: chmod +x scripts/*.sh .github/hooks/bin/*.sh"
fi
