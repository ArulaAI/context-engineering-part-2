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
# the register with plain awk/bash and no YAML library at all, matching every other
# script in this repo's "no dependencies beyond what's already installed" rule. No
# Python either: the register's shape is fixed and known, so an awk state machine
# (the same style outline.sh already uses for Java structure) is enough.
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

for key in objective verified_facts authoritative_sources decisions constraints superseded_sources unknowns; do
  grep -q "^${key}:" "$REGISTER" || {
    echo "context-for: register is missing required key: $key" >&2
    exit 2
  }
done

PARSED="$(awk '
function unquote(s) {
    gsub(/^[ \t]+/, "", s); gsub(/[ \t]+$/, "", s)
    n = length(s)
    if (n >= 2) {
        first = substr(s, 1, 1); last = substr(s, n, 1)
        if ((first == DQ && last == DQ) || (first == SQ && last == SQ))
            s = substr(s, 2, n - 2)
    }
    return s
}
function flush_item() {
    if (cur_section != "" && is_object[cur_section] && item_started) {
        print "ITEM\t" cur_section "\t" item_line
    }
    item_started = 0
    item_line = ""
}
BEGIN {
    DQ = sprintf("%c", 34)
    SQ = sprintf("%c", 39)
    SEP = sprintf("%c", 1)
    is_object["verified_facts"] = 1
    is_object["decisions"] = 1
    is_object["superseded_sources"] = 1
    is_scalar["authoritative_sources"] = 1
    is_scalar["constraints"] = 1
    is_scalar["unknowns"] = 1
    cur_section = ""
    obj_first_line = ""
    obj_text = ""
    item_started = 0
    item_line = ""
}
/^[a-z_]+:/ {
    if (cur_section == "objective") {
        if (obj_first_line == ">") { OBJECTIVE = obj_text }
        else if (obj_first_line != "") { OBJECTIVE = unquote(obj_first_line) }
        else { OBJECTIVE = obj_text }
    }
    flush_item()
    line = $0
    match(line, /^[a-z_]+/)
    key = substr(line, RSTART, RLENGTH)
    rest = substr(line, RLENGTH + 2)
    gsub(/^[ \t]+/, "", rest); gsub(/[ \t]+$/, "", rest)
    cur_section = key
    if (key == "objective") { obj_first_line = rest; obj_text = "" }
    next
}
cur_section == "objective" {
    line = $0
    gsub(/^[ \t]+/, "", line)
    if (line != "") { obj_text = (obj_text == "" ? line : obj_text " " line) }
    next
}
cur_section != "" && is_scalar[cur_section] {
    line = $0
    gsub(/^[ \t]+/, "", line)
    if (line ~ /^-[ \t]/) {
        val = substr(line, 3)
        gsub(/^[ \t]+/, "", val)
        print "LIST\t" cur_section "\t" unquote(val)
    }
    next
}
cur_section != "" && is_object[cur_section] {
    raw = $0
    if (raw ~ /^[ \t]+-[ \t]+[a-z_]+:/) {
        flush_item()
        item_started = 1
        tmp = raw
        sub(/^[ \t]+-[ \t]+/, "", tmp)
        match(tmp, /^[a-z_]+/)
        k = substr(tmp, RSTART, RLENGTH)
        v = substr(tmp, RLENGTH + 2)
        gsub(/^[ \t]+/, "", v)
        item_line = k "=" unquote(v)
    } else if (raw ~ /^[ \t]+[a-z_]+:/ && item_started) {
        tmp = raw
        gsub(/^[ \t]+/, "", tmp)
        match(tmp, /^[a-z_]+/)
        k = substr(tmp, RSTART, RLENGTH)
        v = substr(tmp, RLENGTH + 2)
        gsub(/^[ \t]+/, "", v)
        item_line = item_line SEP k "=" unquote(v)
    }
    next
}
END {
    if (cur_section == "objective") {
        if (obj_first_line == ">") { OBJECTIVE = obj_text }
        else if (obj_first_line != "") { OBJECTIVE = unquote(obj_first_line) }
        else { OBJECTIVE = obj_text }
    }
    flush_item()
    print "OBJ\t" OBJECTIVE
}
' "$REGISTER")"

OBJECTIVE=""
FACT_ITEMS=()
DECISION_ITEMS=()
SUPERSEDED_ITEMS=()
AUTH_SOURCES=()
CONSTRAINTS=()
UNKNOWNS=()

while IFS=$'\t' read -r tag section rest; do
  case "$tag" in
    OBJ) OBJECTIVE="$section" ;;
    LIST)
      case "$section" in
        authoritative_sources) AUTH_SOURCES+=("$rest") ;;
        constraints)           CONSTRAINTS+=("$rest") ;;
        unknowns)               UNKNOWNS+=("$rest") ;;
      esac
      ;;
    ITEM)
      case "$section" in
        verified_facts)       FACT_ITEMS+=("$rest") ;;
        decisions)             DECISION_ITEMS+=("$rest") ;;
        superseded_sources)    SUPERSEDED_ITEMS+=("$rest") ;;
      esac
      ;;
  esac
done <<< "$PARSED"

get_field() {
  # $1 = SOH-joined key=value item, $2 = key to extract.
  # Deliberately does not rely on `IFS=<ctrl-char> read -a` to split fields —
  # that construct silently produced a single unsplit field on this repo's own
  # bash (3.2.57), a real and reproducible quirk, not a hypothetical one.
  # `tr` to newlines + a plain `while read` loop is the boring, reliable way.
  local item="$1" key="$2" part
  while IFS= read -r part; do
    if [ "${part%%=*}" = "$key" ]; then
      printf '%s' "${part#*=}"
      return 0
    fi
  done < <(printf '%s\n' "$item" | tr '\001' '\n')
}

# ---- filter verified_facts by applies_to tag -------------------------------
FACTS_FOR_UNIT=()
DISCARDED=0
for item in "${FACT_ITEMS[@]}"; do
  tag_val="$(get_field "$item" applies_to)"
  if [ -z "$tag_val" ] || [ "$tag_val" = "$WORK_UNIT" ]; then
    FACTS_FOR_UNIT+=("$item")
  else
    DISCARDED=$((DISCARDED + 1))
  fi
done

# ---- print the package ------------------------------------------------------
echo "CONTEXT PACKAGE — ${WORK_UNIT}"
echo "====================================================="
echo "Objective"
if [ -n "$OBJECTIVE" ]; then echo "  $OBJECTIVE"; else echo "  (none set)"; fi
echo ""

echo "Relevant source files"
if [ "${#FACTS_FOR_UNIT[@]}" -gt 0 ]; then
  SEEN_SRC=()
  for item in "${FACTS_FOR_UNIT[@]}"; do
    src="$(get_field "$item" source)"
    [ -z "$src" ] && continue
    already=0
    for s in "${SEEN_SRC[@]:-}"; do [ "$s" = "$src" ] && already=1 && break; done
    if [ "$already" -eq 0 ]; then
      SEEN_SRC+=("$src")
      echo "  $src"
    fi
  done
else
  echo "  (none promoted yet)"
fi
echo ""

echo "Applicable verified facts"
if [ "${#FACTS_FOR_UNIT[@]}" -gt 0 ]; then
  for item in "${FACTS_FOR_UNIT[@]}"; do
    claim="$(get_field "$item" claim)"; [ -z "$claim" ] && claim="(no claim text)"
    src="$(get_field "$item" source)"; [ -z "$src" ] && src="unknown"
    st="$(get_field "$item" source_type)"; [ -z "$st" ] && st="unspecified type"
    echo "  - $claim"
    echo "    (source: $src, $st)"
  done
else
  echo "  (none promoted yet)"
fi
echo ""

echo "Authoritative contracts/config"
if [ "${#AUTH_SOURCES[@]}" -gt 0 ]; then
  for s in "${AUTH_SOURCES[@]}"; do echo "  $s"; done
else
  echo "  (none declared)"
fi
if [ "${#SUPERSEDED_ITEMS[@]}" -gt 0 ]; then
  for item in "${SUPERSEDED_ITEMS[@]}"; do
    src="$(get_field "$item" source)"; [ -z "$src" ] && src="?"
    by="$(get_field "$item" superseded_by)"; [ -z "$by" ] && by="?"
    warn="$(get_field "$item" warning)"
    echo "  $src is SUPERSEDED by $by — $warn"
  done
fi
echo ""

echo "Constraints"
if [ "${#CONSTRAINTS[@]}" -gt 0 ]; then
  for c in "${CONSTRAINTS[@]}"; do echo "  - $c"; done
else
  echo "  (none recorded)"
fi
echo ""

if [ "${#DECISION_ITEMS[@]}" -gt 0 ]; then
  echo "Decisions"
  for item in "${DECISION_ITEMS[@]}"; do
    d="$(get_field "$item" decision)"; [ -z "$d" ] && d="?"
    ab="$(get_field "$item" approved_by)"; [ -z "$ab" ] && ab="unspecified"
    echo "  - $d  (approved by: $ab)"
  done
  echo ""
fi

echo "Open questions"
if [ "${#UNKNOWNS[@]}" -gt 0 ]; then
  for u in "${UNKNOWNS[@]}"; do echo "  - $u"; done
else
  echo "  (none recorded)"
fi
echo ""

echo "-- ${#FACTS_FOR_UNIT[@]} promoted fact(s) packaged; ${DISCARDED} excluded (not tagged for this work unit)."
