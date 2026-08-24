#!/usr/bin/env bash
#
# context-for.sh — package already-promoted facts for one work unit.
#
# Stage 3 ("Promote & Package") makes "promote once, package many times" real: this
# script does not re-derive facts, it filters .context/context-register.yaml down to
# the entries tagged for one work unit (plus untagged/global entries) and prints a
# ready-to-use package. If the register is empty or missing, that's the honest answer
# — nothing has been promoted yet.
#
# .context/context-register.yaml is a DELIBERATELY FLAT YAML subset (two levels of
# nesting max, one scalar per line, an optional `>` folded block only on `objective`).
# That's not a limitation slipped in by accident — it's what lets this script parse
# the register with Python's standard library and no third-party YAML dependency,
# matching every other script in this repo's "no dependencies beyond what's already
# installed" rule.
#
# usage: scripts/context-for.sh <work-unit>

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

WORK_UNIT="${1:-}"
REGISTER=".context/context-register.yaml"

if [ -z "$WORK_UNIT" ]; then
  echo "usage: context-for.sh <work-unit>" >&2
  exit 3
fi

if [ ! -f "$REGISTER" ]; then
  echo "context-for: no register at $REGISTER — nothing has been promoted yet." >&2
  echo "Run Stage 3 first: create .context/context-register.yaml (see .context/README.md)." >&2
  exit 3
fi

python3 - "$REGISTER" "$WORK_UNIT" <<'PY'
import sys, re

path, work_unit = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().splitlines()

def unquote(s):
    s = s.strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in ('"', "'"):
        return s[1:-1]
    return s

# ---- pass 1: split into top-level sections -------------------------------
sections = {}
current_key = None
buf = []
i = 0
required = {"objective", "verified_facts", "authoritative_sources",
            "decisions", "constraints", "superseded_sources", "unknowns"}

while i < len(lines):
    line = lines[i]
    m = re.match(r'^([a-z_]+):(.*)$', line)
    if m and not line.startswith((' ', '\t')):
        if current_key is not None:
            sections[current_key] = buf
        current_key = m.group(1)
        rest = m.group(2).strip()
        buf = [rest] if rest else []
    else:
        if current_key is not None:
            buf.append(line)
    i += 1
if current_key is not None:
    sections[current_key] = buf

missing = required - set(sections.keys())
if missing:
    print(f"context-for: register is missing required key(s): {', '.join(sorted(missing))}", file=sys.stderr)
    sys.exit(2)

# ---- objective: either inline or a `>` folded block ------------------------
obj_lines = sections["objective"]
if obj_lines and obj_lines[0].strip() == ">":
    objective = " ".join(l.strip() for l in obj_lines[1:] if l.strip())
elif obj_lines and obj_lines[0].strip():
    objective = unquote(obj_lines[0])
else:
    objective = " ".join(l.strip() for l in obj_lines if l.strip())

# ---- list-of-scalars sections ----------------------------------------------
def parse_scalar_list(raw_lines):
    out = []
    for l in raw_lines:
        s = l.strip()
        if s.startswith("- "):
            out.append(unquote(s[2:]))
    return out

authoritative_sources = parse_scalar_list(sections["authoritative_sources"])
constraints = parse_scalar_list(sections["constraints"])
unknowns = parse_scalar_list(sections["unknowns"])

# ---- list-of-objects sections ("  - key: value" then "    key: value") ----
def parse_object_list(raw_lines):
    items = []
    current = None
    for l in raw_lines:
        s = l.rstrip()
        if not s.strip():
            continue
        m = re.match(r'^\s*-\s+([a-z_]+):\s*(.*)$', s)
        if m and s.lstrip().startswith("-"):
            if current is not None:
                items.append(current)
            current = {m.group(1): unquote(m.group(2))}
            continue
        m2 = re.match(r'^\s+([a-z_]+):\s*(.*)$', s)
        if m2 and current is not None:
            current[m2.group(1)] = unquote(m2.group(2))
    if current is not None:
        items.append(current)
    return items

verified_facts = parse_object_list(sections["verified_facts"])
decisions = parse_object_list(sections["decisions"])
superseded_sources = parse_object_list(sections["superseded_sources"])

def applies(fact):
    tag = fact.get("applies_to")
    return tag is None or tag == "" or tag == work_unit

facts_for_unit = [f for f in verified_facts if applies(f)]
discarded = len(verified_facts) - len(facts_for_unit)

# ---- print the package ------------------------------------------------------
print(f"CONTEXT PACKAGE — {work_unit}")
print("=====================================================")
print("Objective")
print(f"  {objective}" if objective else "  (none set)")
print()

print("Relevant source files")
seen_src = []
for f in facts_for_unit:
    src = f.get("source", "")
    if src and src not in seen_src:
        seen_src.append(src)
if seen_src:
    for src in seen_src:
        print(f"  {src}")
else:
    print("  (none promoted yet)")
print()

print("Applicable verified facts")
if facts_for_unit:
    for f in facts_for_unit:
        print(f"  - {f.get('claim', '(no claim text)')}")
        print(f"    (source: {f.get('source', 'unknown')}, {f.get('source_type', 'unspecified type')})")
else:
    print("  (none promoted yet)")
print()

print("Authoritative contracts/config")
if authoritative_sources:
    for s in authoritative_sources:
        print(f"  {s}")
else:
    print("  (none declared)")
if superseded_sources:
    for s in superseded_sources:
        print(f"  {s.get('source','?')} is SUPERSEDED by {s.get('superseded_by','?')} — {s.get('warning','')}")
print()

print("Constraints")
if constraints:
    for c in constraints:
        print(f"  - {c}")
else:
    print("  (none recorded)")
print()

if decisions:
    print("Decisions")
    for d in decisions:
        print(f"  - {d.get('decision','?')}  (approved by: {d.get('approved_by','unspecified')})")
    print()

print("Open questions")
if unknowns:
    for u in unknowns:
        print(f"  - {u}")
else:
    print("  (none recorded)")
print()

print(f"-- {len(facts_for_unit)} promoted fact(s) packaged; {discarded} excluded (not tagged for this work unit).")
PY
