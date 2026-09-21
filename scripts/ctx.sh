#!/usr/bin/env bash
#
# ctx.sh — durable engineering state, written by a tool so it stays auditable.
#
#   EVIDENCE        .context/evidence-ledger.yaml    what a mechanism observed about a claim
#   DURABLE CONTEXT .context/context-register.yaml   what is verified, decided, constrained, unknown
#   TASK HANDOFF    .workflow/HANDOFF.md             a bounded projection for the next actor
#   OUTCOME         .workflow/outcome.yaml           what actually happened
#
# You decide the content. This script owns the shape and the rules:
#   - a fact can only be promoted from recorded evidence, never typed in from memory
#   - an unresolved claim cannot become a fact; it becomes an unknown
#   - a decision must cite an authority file that exists, and it retires the unknown it
#     resolves — an issue can never be both decided and still open
#   - a handoff cannot be produced while a blocking unknown for that work unit is open
#
# commands
#   init --objective TEXT [--work-item ID]
#   evidence add --claim TEXT --status verified|rejected|unproven|unresolved
#                --mechanism TEXT --source TEXT [--observed TEXT] [--applies-to TAG]
#   evidence capture --source TEXT [--applies-to TAG]     (reads a tool's EVIDENCE: line on stdin)
#   evidence list
#   promote EV-ID --fact TEXT [--applies-to TAG]
#   unknown add (--question TEXT | --from EV-ID) [--blocking] [--applies-to TAG]
#   constraint add --text TEXT --basis ID|ticket:ID [--applies-to TAG]
#   decide --resolves UNK-ID --decision TEXT --authority PATH --decided-by NAME
#          [--supersedes PATH --scope TEXT]
#   package WORK-UNIT
#   handoff WORK-UNIT --scope Class.method [--scope ...] --next TEXT [--proof TEXT ...]
#   outcome --work-unit TAG --status implemented|partial|blocked --next TEXT
#           [--test TEXT ...] [--finding "SUMMARY::DISPOSITION" ...]
#   check
#   rehydrate-check
#
# exit 0 ok · 1 invariant or verification failure · 2 bad usage · 3 missing state · 4 blocked

set -uo pipefail
cd "$(dirname "$0")/.." || exit 3

LEDGER=".context/evidence-ledger.yaml"
REG=".context/context-register.yaml"
HANDOFF=".workflow/HANDOFF.md"
CONSUMED=".workflow/handoff-consumed"
OUTCOME=".workflow/outcome.yaml"
US=$'\037'

die()  { echo "ctx: $2" >&2; exit "$1"; }
q()    { local v="$1"; v="${v//\\/\\\\}"; v="${v//\"/\\\"}"; printf '"%s"' "$v"; }
need() { [ -f "$1" ] || die 3 "no $1 — run: ./scripts/ctx.sh init --objective \"...\""; }

hash12() {
  if command -v shasum >/dev/null 2>&1; then shasum | cut -c1-12
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -c1-12
  else cksum | tr -d ' \n' | cut -c1-12; fi
}

# entries FILE SECTION -> one line per entry: id=X<US>key=val<US>key=val
entries() {
  SEC="$2" awk '
    function unq(v) {
      if (v ~ /^".*"$/) { v = substr(v, 2, length(v) - 2); gsub(/\\"/, "\"", v); gsub(/\\\\/, "\\", v) }
      return v
    }
    /^[a-z_]+:/ { if (cur != "") { print cur; cur = "" } insec = ($0 ~ ("^" ENVIRON["SEC"] ":")); next }
    insec && /^  - id: / { if (cur != "") print cur; v = $0; sub(/^  - id: /, "", v); cur = "id=" unq(v); next }
    insec && /^    [a-z_]+: / {
      line = $0; sub(/^    /, "", line); k = line; sub(/:.*/, "", k); v = line; sub(/^[a-z_]+: /, "", v)
      cur = cur "\037" k "=" unq(v); next
    }
    END { if (cur != "") print cur }
  ' "$1"
}

# field ENTRY-LINE KEY
field() {
  local IFS="$US" kv
  for kv in $1; do [ "${kv%%=*}" = "$2" ] && { printf '%s' "${kv#*=}"; return 0; }; done
  return 1
}

# find_entry FILE SECTION ID
find_entry() { entries "$1" "$2" | while IFS= read -r e; do [ "$(field "$e" id)" = "$3" ] && { printf '%s\n' "$e"; break; }; done; }

# append FILE SECTION BLOCK
append() {
  BLK="$3" SEC="$2" awk '
    /^[a-z_]+:/ { if (insec && !done) { printf "%s\n", ENVIRON["BLK"]; done = 1 } insec = ($0 ~ ("^" ENVIRON["SEC"] ":")) }
    { print }
    END { if (insec && !done) printf "%s\n", ENVIRON["BLK"] }
  ' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

# remove FILE SECTION ID
remove() {
  SEC="$2" RID="$3" awk '
    /^[a-z_]+:/ { insec = ($0 ~ ("^" ENVIRON["SEC"] ":")); skip = 0 }
    insec && /^  - id: / { v = $0; sub(/^  - id: /, "", v); gsub(/"/, "", v); skip = (v == ENVIRON["RID"]) }
    !skip { print }
  ' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

# next_id FILE PREFIX
next_id() {
  local n
  n="$( { grep -oE "id: \"?$2-[0-9]+" "$1" 2>/dev/null || true; } | grep -oE '[0-9]+$' | sort -n | tail -1)"
  printf '%s-%03d' "$2" $(( ${n:-0} + 1 ))
}

# block ID key val key val ... -> formatted YAML entry
block() {
  local out="  - id: $1"$'\n'; shift
  while [ $# -ge 2 ]; do
    [ -n "$2" ] && out="${out}    $1: $(q "$2")"$'\n'
    shift 2
  done
  printf '%s' "$out"
}

applies() { # applies ENTRY UNIT -> true if global or tagged for UNIT
  local t; t="$(field "$1" applies_to || true)"
  [ -z "$t" ] || [ "$t" = "$2" ]
}

scalar() { # scalar FILE KEY -> top-level scalar value
  sed -n "s/^$2: *\"\{0,1\}\([^\"]*\)\"\{0,1\} *$/\1/p" "$1" | head -1
}

# ---------------------------------------------------------------------------------------
cmd_init() {
  local objective="" item=""
  while [ $# -gt 0 ]; do case "$1" in
    --objective) objective="$2"; shift 2 ;;
    --work-item) item="$2"; shift 2 ;;
    *) die 2 "init: unknown option $1" ;; esac; done
  [ -n "$objective" ] || die 2 "init: --objective is required (one line, in your own words)"
  [ -f "$REG" ] && die 2 "init: $REG already exists — it is durable state; delete it deliberately if you mean to start over"
  mkdir -p .context .workflow
  {
    echo "# context-register.yaml — durable, verified engineering state. Written by scripts/ctx.sh."
    echo "# Nothing here came from a conversation: every fact cites evidence, every decision cites authority."
    echo ""
    echo "objective: $(q "$objective")"
    [ -n "$item" ] && echo "work_item: $(q "$item")"
    for s in verified_facts authoritative_sources decisions constraints superseded_sources unknowns retired_unknowns; do
      echo ""; echo "$s:"
    done
  } > "$REG"
  [ -f "$LEDGER" ] || {
    echo "# evidence-ledger.yaml — claim-specific observations. Written by scripts/ctx.sh."
    echo "# Evidence is not yet durable truth: promote it into the register once it settles a claim."
    echo ""
    echo "evidence:"
  } > "$LEDGER"
  echo "created $REG"
  echo "ledger  $LEDGER"
}

cmd_evidence() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    add)
      local claim="" status="" mech="" src="" obs="" tag=""
      while [ $# -gt 0 ]; do case "$1" in
        --claim) claim="$2"; shift 2 ;; --status) status="$2"; shift 2 ;;
        --mechanism) mech="$2"; shift 2 ;; --source) src="$2"; shift 2 ;;
        --observed) obs="$2"; shift 2 ;; --applies-to) tag="$2"; shift 2 ;;
        *) die 2 "evidence add: unknown option $1" ;; esac; done
      [ -n "$claim" ] && [ -n "$status" ] && [ -n "$mech" ] && [ -n "$src" ] \
        || die 2 "evidence add: --claim, --status, --mechanism and --source are all required"
      case "$status" in verified|rejected|unproven|unresolved) ;; *)
        die 2 "evidence add: --status must be verified, rejected, unproven or unresolved" ;; esac
      ensure_ledger
      local id; id="$(next_id "$LEDGER" EV)"
      append "$LEDGER" evidence "$(block "$id" claim "$claim" status "$status" mechanism "$mech" source "$src" observed "$obs" applies_to "$tag")"
      echo "$id  [$status]  $claim"
      ;;
    capture)
      local src="" tag=""
      while [ $# -gt 0 ]; do case "$1" in
        --source) src="$2"; shift 2 ;; --applies-to) tag="$2"; shift 2 ;;
        *) die 2 "evidence capture: unknown option $1" ;; esac; done
      [ -n "$src" ] || die 2 "evidence capture: --source is required (the command whose output you piped in)"
      local input line; input="$(cat)"
      printf '%s\n' "$input"
      line="$(printf '%s\n' "$input" | grep '^EVIDENCE: ' | tail -1)"
      [ -n "$line" ] || die 3 "evidence capture: no EVIDENCE line in the input — the mechanism produced no evidence, so nothing was recorded"
      local claim status mech obs
      claim="$(printf '%s' "$line" | sed -n 's/.*claim="\([^"]*\)".*/\1/p')"
      status="$(printf '%s' "$line" | sed -n 's/.* status=\([a-z]*\).*/\1/p')"
      mech="$(printf '%s' "$line" | sed -n 's/.* mechanism=\([^ ]*\).*/\1/p')"
      obs="$(printf '%s' "$line" | sed 's/^EVIDENCE: claim="[^"]*" status=[a-z]* mechanism=[^ ]* *//')"
      echo ""
      cmd_evidence add --claim "$claim" --status "$status" --mechanism "$mech" --source "$src" --observed "$obs" --applies-to "$tag"
      ;;
    list)
      ensure_ledger
      echo "| ID | Status | Claim | Mechanism | Observed |"
      echo "|---|---|---|---|---|"
      entries "$LEDGER" evidence | while IFS= read -r e; do
        printf '| %s | %s | %s | %s | %s |\n' "$(field "$e" id)" "$(field "$e" status)" \
          "$(field "$e" claim)" "$(field "$e" mechanism)" "$(field "$e" observed || true)"
      done
      ;;
    *) die 2 "evidence: use add, capture or list" ;;
  esac
}

ensure_ledger() {
  [ -f "$LEDGER" ] && return 0
  mkdir -p .context
  { echo "# evidence-ledger.yaml — claim-specific observations. Written by scripts/ctx.sh."
    echo ""; echo "evidence:"; } > "$LEDGER"
}

cmd_promote() {
  local ev="${1:-}"; shift || true
  local fact="" tag=""
  while [ $# -gt 0 ]; do case "$1" in
    --fact) fact="$2"; shift 2 ;; --applies-to) tag="$2"; shift 2 ;;
    *) die 2 "promote: unknown option $1" ;; esac; done
  need "$REG"; ensure_ledger
  [ -n "$ev" ] && [ -n "$fact" ] || die 2 "promote: usage: promote EV-ID --fact \"what the evidence establishes, in your words\""
  local e; e="$(find_entry "$LEDGER" evidence "$ev")"
  [ -n "$e" ] || die 3 "promote: no evidence $ev in $LEDGER"
  local st; st="$(field "$e" status)"
  [ "$st" = "unresolved" ] && die 1 "promote: $ev is unresolved — an unresolved claim is not a fact. Record it with: ctx.sh unknown add --from $ev"
  [ -n "$tag" ] || tag="$(field "$e" applies_to || true)"
  local id; id="$(next_id "$REG" VF)"
  append "$REG" verified_facts "$(block "$id" claim "$fact" evidence_id "$ev" evidence_status "$st" \
    mechanism "$(field "$e" mechanism)" source "$(field "$e" source)" applies_to "$tag")"
  echo "$id  promoted from $ev ($st, $(field "$e" mechanism))  $fact"
}

cmd_unknown() {
  [ "${1:-}" = "add" ] || die 2 "unknown: use: unknown add (--question TEXT | --from EV-ID) [--blocking] [--applies-to TAG]"
  shift
  local qn="" from="" blocking="false" tag=""
  while [ $# -gt 0 ]; do case "$1" in
    --question) qn="$2"; shift 2 ;; --from) from="$2"; shift 2 ;;
    --blocking) blocking="true"; shift ;; --applies-to) tag="$2"; shift 2 ;;
    *) die 2 "unknown add: unknown option $1" ;; esac; done
  need "$REG"
  local obs=""
  if [ -n "$from" ]; then
    ensure_ledger
    local e; e="$(find_entry "$LEDGER" evidence "$from")"
    [ -n "$e" ] || die 3 "unknown add: no evidence $from"
    [ -n "$qn" ] || qn="$(field "$e" claim)"
    obs="$(field "$e" observed || true)"
    [ -n "$tag" ] || tag="$(field "$e" applies_to || true)"
  fi
  [ -n "$qn" ] || die 2 "unknown add: --question or --from is required"
  local id; id="$(next_id "$REG" UNK)"
  append "$REG" unknowns "$(block "$id" question "$qn" status open blocking "$blocking" evidence_id "$from" observed "$obs" applies_to "$tag")"
  echo "$id  [open$( [ "$blocking" = true ] && echo ', blocking')]  $qn"
}

cmd_constraint() {
  [ "${1:-}" = "add" ] || die 2 "constraint: use: constraint add --text TEXT --basis ID|ticket:ID"
  shift
  local text="" basis="" tag=""
  while [ $# -gt 0 ]; do case "$1" in
    --text) text="$2"; shift 2 ;; --basis) basis="$2"; shift 2 ;; --applies-to) tag="$2"; shift 2 ;;
    *) die 2 "constraint add: unknown option $1" ;; esac; done
  need "$REG"
  [ -n "$text" ] && [ -n "$basis" ] || die 2 "constraint add: --text and --basis are required"
  case "$basis" in
    ticket:*) ;;
    *) grep -qE "id: \"?${basis}\"?$" "$REG" || die 3 "constraint add: basis $basis is not an ID in the register" ;;
  esac
  local id; id="$(next_id "$REG" C)"
  append "$REG" constraints "$(block "$id" constraint "$text" basis "$basis" applies_to "$tag")"
  echo "$id  $text  (basis: $basis)"
}

cmd_decide() {
  local res="" dec="" auth="" by="" sup="" scope=""
  while [ $# -gt 0 ]; do case "$1" in
    --resolves) res="$2"; shift 2 ;; --decision) dec="$2"; shift 2 ;;
    --authority) auth="$2"; shift 2 ;; --decided-by) by="$2"; shift 2 ;;
    --supersedes) sup="$2"; shift 2 ;; --scope) scope="$2"; shift 2 ;;
    *) die 2 "decide: unknown option $1" ;; esac; done
  need "$REG"
  [ -n "$res" ] && [ -n "$dec" ] && [ -n "$auth" ] && [ -n "$by" ] \
    || die 2 "decide: --resolves, --decision, --authority and --decided-by are all required"
  local u; u="$(find_entry "$REG" unknowns "$res")"
  [ -n "$u" ] || die 3 "decide: $res is not an open unknown in the register"
  [ -f "$auth" ] || die 3 "decide: authority $auth does not exist — a decision must cite a real record"
  if [ -n "$sup" ]; then
    [ -f "${sup%%#*}" ] || die 3 "decide: superseded source ${sup%%#*} does not exist"
    [ -n "$scope" ] || die 2 "decide: --supersedes needs --scope (what exactly is superseded)"
  fi
  local tag; tag="$(field "$u" applies_to || true)"
  local did; did="$(next_id "$REG" D)"
  append "$REG" decisions "$(block "$did" decision "$dec" resolves "$res" authority "$auth" decided_by "$by" applies_to "$tag")"
  if ! grep -qE "source: \"$auth\"" "$REG"; then
    local aid; aid="$(next_id "$REG" AS)"
    append "$REG" authoritative_sources "$(block "$aid" source "$auth" governs "$(field "$u" question)" applies_to "$tag")"
  fi
  if [ -n "$sup" ]; then
    local sid; sid="$(next_id "$REG" SS)"
    append "$REG" superseded_sources "$(block "$sid" source "$sup" superseded_by "$auth" scope "$scope" decision "$did")"
  fi
  remove "$REG" unknowns "$res"
  append "$REG" retired_unknowns "$(block "$res" question "$(field "$u" question)" resolved_by "$did" applies_to "$tag")"
  echo "$did  recorded  $dec"
  echo "     authority: $auth   decided by: $by"
  [ -n "$sup" ] && echo "     superseded: $sup ($scope)"
  echo "$res  retired (resolved by $did)"
}

cmd_package() {
  local unit="${1:-}"
  [ -n "$unit" ] || die 2 "package: usage: package WORK-UNIT"
  need "$REG"
  local excluded=0 n=0
  echo "CONTEXT PACKAGE — $unit"
  echo "Built from $REG (durable, verified state) — not from any conversation."
  echo ""
  echo "Objective: $(scalar "$REG" objective)"
  local item; item="$(scalar "$REG" work_item)"; [ -n "$item" ] && echo "Work item: $item"
  section() { # section TITLE SECTION FORMAT-FN
    local out="" e
    while IFS= read -r e; do
      [ -n "$e" ] || continue
      if applies "$e" "$unit"; then out="${out}$($3 "$e")"$'\n'; else excluded=$((excluded + 1)); fi
    done < <(entries "$REG" "$2")
    echo ""
    echo "$1"
    if [ -n "$out" ]; then printf '%s' "$out"; else echo "  (none)"; fi
  }
  f_fact() { echo "  $(field "$1" id): $(field "$1" claim)   [evidence $(field "$1" evidence_id): $(field "$1" mechanism), $(field "$1" source)]"; }
  f_dec()  { echo "  $(field "$1" id): $(field "$1" decision)   [authority: $(field "$1" authority); decided by $(field "$1" decided_by); resolves $(field "$1" resolves)]"; }
  f_auth() { echo "  $(field "$1" id): $(field "$1" source) — governs: $(field "$1" governs)"; }
  f_con()  { echo "  $(field "$1" id): $(field "$1" constraint)   [basis: $(field "$1" basis)]"; }
  f_sup()  { echo "  $(field "$1" id): $(field "$1" source) — superseded by $(field "$1" superseded_by) ($(field "$1" scope))"; }
  f_unk()  { echo "  $(field "$1" id): $(field "$1" question)$( [ "$(field "$1" blocking)" = true ] && echo '   [BLOCKING]')$( o="$(field "$1" observed || true)"; [ -n "$o" ] && echo "   [observed: $o]")"; }
  section "Decisions (human, with authority)" decisions f_dec
  section "Verified facts (with evidence)" verified_facts f_fact
  section "Authoritative sources" authoritative_sources f_auth
  section "Constraints" constraints f_con
  section "Superseded sources" superseded_sources f_sup
  section "Open unknowns" unknowns f_unk
  echo ""
  echo "-- ${excluded} entr$( [ "$excluded" -eq 1 ] && echo y || echo ies) excluded (tagged for a different work unit)."
}

cmd_handoff() {
  local unit="${1:-}"; shift || true
  local scopes=() proofs=() next=""
  while [ $# -gt 0 ]; do case "$1" in
    --scope) scopes+=("$2"); shift 2 ;; --proof) proofs+=("$2"); shift 2 ;;
    --next) next="$2"; shift 2 ;; *) die 2 "handoff: unknown option $1" ;; esac; done
  [ -n "$unit" ] && [ ${#scopes[@]} -gt 0 ] && [ -n "$next" ] \
    || die 2 "handoff: usage: handoff WORK-UNIT --scope Class.method [--scope ...] --next TEXT"
  need "$REG"
  local blocking=""
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    applies "$e" "$unit" && [ "$(field "$e" blocking)" = "true" ] && blocking="$blocking $(field "$e" id)"
  done < <(entries "$REG" unknowns)
  [ -z "$blocking" ] || die 4 "handoff: blocking unknown(s) still open for $unit:$blocking — a handoff cannot carry an undecided question the implementation depends on. Record the decision first (ctx.sh decide)."
  local s cls meth file
  for s in "${scopes[@]}"; do
    cls="${s%%.*}"; meth="${s#*.}"
    file="$(find src/main/java -name "${cls}.java" | head -1)"
    [ -n "$file" ] || die 3 "handoff: scope $s — no class $cls in src/main/java"
    bash scripts/lib/methods.sh "$file" | cut -f1 | grep -qx "$meth" || die 3 "handoff: scope $s — no method $meth in $file"
  done
  [ ${#proofs[@]} -gt 0 ] || proofs=("./scripts/verify-change.sh reports VERDICT: PASS" \
                                     "permanent tests cover the approved rule (ticket Definition of Done)")
  mkdir -p .workflow
  local body
  body="$(
    echo "# HANDOFF — $unit"
    echo ""
    echo "handoff_id: @@ID@@"
    echo "work_item: $(scalar "$REG" work_item)"
    echo "generated_from: $REG"
    echo ""
    echo "This is a projection of verified engineering state for one task. It is not a"
    echo "conversation summary. Anything not written here was deliberately left out."
    echo ""
    echo "## Objective"; echo ""; echo "$(scalar "$REG" objective)"; echo ""
    echo "## Approved decisions"; echo ""
    local e any=0
    while IFS= read -r e; do [ -n "$e" ] || continue; applies "$e" "$unit" || continue; any=1
      echo "- **$(field "$e" id)** $(field "$e" decision) — authority: \`$(field "$e" authority)\`"
    done < <(entries "$REG" decisions); [ $any -eq 1 ] || echo "- none"
    echo ""; echo "## Allowed change scope"; echo ""
    for s in "${scopes[@]}"; do echo "- \`$s\`"; done
    echo "- tests under \`src/test/java\`"
    echo ""; echo "Anything outside this scope is out of bounds: stop and report it instead."
    echo ""; echo "## Known constraints"; echo ""
    any=0
    while IFS= read -r e; do [ -n "$e" ] || continue; applies "$e" "$unit" || continue; any=1
      echo "- **$(field "$e" id)** $(field "$e" constraint)"
    done < <(entries "$REG" constraints)
    while IFS= read -r e; do [ -n "$e" ] || continue; applies "$e" "$unit" || continue; any=1
      echo "- **$(field "$e" id)** (verified fact) $(field "$e" claim)"
    done < <(entries "$REG" verified_facts); [ $any -eq 1 ] || echo "- none"
    echo ""; echo "## Required proof"; echo ""
    local p; for p in "${proofs[@]}"; do echo "- $p"; done
    echo ""; echo "## Unresolved questions"; echo ""
    any=0
    while IFS= read -r e; do [ -n "$e" ] || continue; applies "$e" "$unit" || continue; any=1
      echo "- **$(field "$e" id)** $(field "$e" question) (not blocking this task — do not resolve it)"
    done < <(entries "$REG" unknowns); [ $any -eq 1 ] || echo "- none"
    echo ""; echo "## Next action"; echo ""; echo "$next"
    echo ""; echo "## Return contract"; echo ""
    echo "Begin your return with the line \`HANDOFF_ID: <the handoff_id above>\`. It proves you"
    echo "worked from this file rather than from a conversation."
  )"
  local id; id="H-$(printf '%s' "$body" | hash12)"
  printf '%s\n' "${body//@@ID@@/$id}" > "$HANDOFF"
  rm -f "$CONSUMED"
  echo "wrote $HANDOFF"
  echo "handoff_id: $id"
}

cmd_outcome() {
  local unit="" status="" next="" tests=() findings=()
  while [ $# -gt 0 ]; do case "$1" in
    --work-unit) unit="$2"; shift 2 ;; --status) status="$2"; shift 2 ;;
    --next) next="$2"; shift 2 ;; --test) tests+=("$2"); shift 2 ;;
    --finding) findings+=("$2"); shift 2 ;; *) die 2 "outcome: unknown option $1" ;; esac; done
  [ -n "$unit" ] && [ -n "$status" ] && [ -n "$next" ] \
    || die 2 "outcome: --work-unit, --status and --next are required"
  case "$status" in implemented|partial|blocked) ;; *) die 2 "outcome: --status must be implemented, partial or blocked" ;; esac
  need "$REG"
  [ -f "$HANDOFF" ] || die 3 "outcome: no $HANDOFF — there is no task this outcome belongs to"
  [ -f .workflow/baseline ] || die 3 "outcome: no .workflow/baseline — run ./scripts/lab-start.sh"
  local hid consumed="false" base head dirty loc="" f
  hid="$(sed -n 's/^handoff_id: *//p' "$HANDOFF" | head -1)"
  [ -f "$CONSUMED" ] && [ "$(cat "$CONSUMED")" = "$hid" ] && consumed="true"
  base="$(cat .workflow/baseline)"; head="$(git rev-parse HEAD)"
  dirty="$(git status --porcelain -- src 2>/dev/null)"
  for f in $(git diff --name-only "$base" -- src/main/java); do
    local ranges; ranges="$(bash scripts/lib/methods.sh "$f" 2>/dev/null)"
    while IFS= read -r h; do
      local start="${h%%,*}" m
      m="$(printf '%s\n' "$ranges" | awk -F'\t' -v l="$start" '$2<=l && l<=$3 {print $1; exit}')"
      loc="${loc}${loc:+; }$(basename "$f" .java).${m:-<outside any method>} ($f:${start})"
    done < <(git diff -U0 "$base" -- "$f" | sed -n 's/^@@ -[0-9,]* +\([0-9]*\).*/\1/p')
  done
  local vout vrc vline
  vout="$(bash scripts/verify-change.sh 2>&1)"; vrc=$?
  vline="$(printf '%s\n' "$vout" | grep '^VERDICT:' | tail -1)"
  local verdict="FAIL"; [ "$vrc" -eq 0 ] && verdict="PASS"
  mkdir -p .workflow
  {
    echo "# outcome.yaml — what actually happened. Written by scripts/ctx.sh from repository state."
    echo ""
    echo "work_item: $(q "$(scalar "$REG" work_item)")"
    echo "work_unit: $(q "$unit")"
    echo "handoff_id: $(q "$hid")"
    echo "handoff_consumed: $consumed"
    echo "approved_decisions:"
    entries "$REG" decisions | while IFS= read -r e; do applies "$e" "$unit" && echo "  - $(q "$(field "$e" id): $(field "$e" decision)")"; done
    echo "implementation:"
    echo "  status: $status"
    echo "  location: $(q "${loc:-no change under src/main/java since the baseline}")"
    if [ -n "$dirty" ]; then echo "  commit: \"uncommitted\""; else echo "  commit: $(q "$head")"; fi
    echo "tests:"
    if [ ${#tests[@]} -eq 0 ]; then echo "  - \"none recorded\""; else for f in "${tests[@]}"; do echo "  - $(q "$f")"; done; fi
    echo "review_findings:"
    if [ ${#findings[@]} -eq 0 ]; then echo "  - \"none recorded\""; else
      local i=0; for f in "${findings[@]}"; do i=$((i + 1))
        echo "  - id: $(printf 'RF-%03d' $i)"
        echo "    summary: $(q "${f%%::*}")"
        echo "    disposition: $(q "${f#*::}")"; done; fi
    echo "verification:"
    echo "  command: \"./scripts/verify-change.sh\""
    echo "  verdict: $verdict"
    echo "  detail: $(q "${vline:-no verdict produced}")"
    echo "  verdict_hash: $(q "$(printf '%s' "$vout" | hash12)")"
    echo "remaining_unknowns:"
    local any=0
    while IFS= read -r e; do [ -n "$e" ] || continue; applies "$e" "$unit" || continue; any=1
      echo "  - $(q "$(field "$e" id): $(field "$e" question)")"
    done < <(entries "$REG" unknowns)
    [ $any -eq 1 ] || echo "  - \"none\""
    echo "next_action: $(q "$next")"
  } > "$OUTCOME"
  echo "wrote $OUTCOME"
  echo "  verification: $verdict — ${vline:-no verdict}"
  echo "  handoff consumed: $consumed"
  [ -n "$dirty" ] && echo "  WARNING: uncommitted changes under src/ — commit before relying on this outcome."
  [ "$verdict" = "PASS" ] || return 1
}

cmd_check() {
  need "$REG"; ensure_ledger
  local bad=0 e id
  while IFS= read -r e; do [ -n "$e" ] || continue; id="$(field "$e" id)"
    local ev; ev="$(field "$e" evidence_id || true)"
    if [ -z "$ev" ] || [ -z "$(find_entry "$LEDGER" evidence "$ev")" ]; then
      echo "✗ $id: verified fact without recorded evidence"; bad=1; fi
  done < <(entries "$REG" verified_facts)
  while IFS= read -r e; do [ -n "$e" ] || continue; id="$(field "$e" id)"
    local a; a="$(field "$e" authority)"
    [ -f "$a" ] || { echo "✗ $id: authority $a does not exist"; bad=1; }
    local r; r="$(field "$e" resolves)"
    [ -n "$(find_entry "$REG" retired_unknowns "$r")" ] || { echo "✗ $id: resolves $r, which is not retired"; bad=1; }
  done < <(entries "$REG" decisions)
  while IFS= read -r e; do [ -n "$e" ] || continue; id="$(field "$e" id)"
    [ -n "$(find_entry "$REG" retired_unknowns "$id")" ] && { echo "✗ $id: listed as open AND as resolved"; bad=1; }
  done < <(entries "$REG" unknowns)
  while IFS= read -r e; do [ -n "$e" ] || continue; id="$(field "$e" id)"
    [ -f "$(field "$e" superseded_by)" ] || { echo "✗ $id: superseded_by $(field "$e" superseded_by) does not exist"; bad=1; }
  done < <(entries "$REG" superseded_sources)
  if [ $bad -eq 0 ]; then echo "✓ register consistent: facts cite evidence, decisions cite authority, no issue is both open and resolved"; fi
  return $bad
}

cmd_rehydrate_check() {
  local ok=1 v
  row() { if [ -n "$3" ]; then printf '| %s | %s | %s |\n' "$1" "$2" "$3"; else printf '| %s | %s | **MISSING** |\n' "$1" "$2"; ok=0; fi; }
  ofield() { [ -f "$OUTCOME" ] && sed -n "s/^  *$1: *\"\{0,1\}\([^\"]*\)\"\{0,1\} *$/\1/p;s/^$1: *\"\{0,1\}\([^\"]*\)\"\{0,1\} *$/\1/p" "$OUTCOME" | head -1; }
  echo "| Question a fresh actor must answer | Durable source | Present |"
  echo "|---|---|---|"
  row "1. What was requested?" "register objective + outcome work_item" "$( [ -f "$REG" ] && scalar "$REG" objective)"
  v=""; [ -f "$REG" ] && v="$(entries "$REG" verified_facts | grep -c . || true)"; [ "${v:-0}" -gt 0 ] || v=""
  row "2. What was verified?" "register verified_facts" "${v:+$v fact(s) with evidence}"
  v=""; [ -f "$REG" ] && v="$(entries "$REG" decisions | head -1)"; [ -n "$v" ] && v="$(field "$v" id) by $(field "$v" decided_by), authority $(field "$v" authority)"
  row "3. What human decision was made?" "register decisions" "$v"
  row "4. What was implemented?" "outcome implementation" "$(ofield location)"
  v="$(ofield verdict)"; [ "$v" = "PASS" ] || { [ -n "$v" ] && v="$v (not passing)"; }
  row "5. What verification passed?" "outcome verification" "$v"
  v=""; [ -f "$OUTCOME" ] && grep -q '^remaining_unknowns:' "$OUTCOME" && v="$(awk '/^remaining_unknowns:/{f=1;next} /^[a-z_]+:/{f=0} f' "$OUTCOME" | sed 's/^ *- //; s/"//g' | paste -sd';' -)"
  row "6. What remains unresolved?" "outcome remaining_unknowns" "$v"
  row "7. What should happen next?" "outcome next_action" "$(ofield next_action)"
  echo ""
  if [ $ok -eq 1 ]; then echo "REHYDRATABLE: every question has a durable source."; return 0
  else echo "NOT REHYDRATABLE: a fresh actor would have to guess the missing answers."; return 1; fi
}

case "${1:-}" in
  init)            shift; cmd_init "$@" ;;
  evidence)        shift; cmd_evidence "$@" ;;
  promote)         shift; cmd_promote "$@" ;;
  unknown)         shift; cmd_unknown "$@" ;;
  constraint)      shift; cmd_constraint "$@" ;;
  decide)          shift; cmd_decide "$@" ;;
  package)         shift; cmd_package "$@" ;;
  handoff)         shift; cmd_handoff "$@" ;;
  outcome)         shift; cmd_outcome "$@" ;;
  check)           shift; cmd_check ;;
  rehydrate-check) shift; cmd_rehydrate_check ;;
  *) sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
