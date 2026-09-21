#!/usr/bin/env bash
#
# methods.sh — machine-readable method line ranges for a Java file.
#
# outline.sh is for people: its output is formatted for reading and may change. This is for
# scripts: one tab-separated line per method, a stable contract that does not change when the
# display format does. (verify-change.sh once parsed outline.sh's display output; when that
# output became a markdown table the parse broke silently. Keep display and data separate.)
#
# usage: scripts/lib/methods.sh <File.java>
# output: <name>\t<start>\t<end>      e.g.  calculateFee\t237\t248
# exit 0 ok · 2 no such file

set -uo pipefail
FILE="${1:-}"
[ -f "$FILE" ] || { echo "methods.sh: no such file: $FILE" >&2; exit 2; }

awk '
  function is_decl(s) {
    return s ~ /^[ \t]*(public|private|protected|static|final|synchronized|abstract|native)[ \t]/ &&
           s !~ /^[ \t]*(if|for|while|switch|catch|try|else|do|return|new)[ \t(]/
  }
  function name_of(s,   n) {
    n = s; sub(/\(.*/, "", n); sub(/.*[ \t]/, "", n); return n
  }
  BEGIN { depth = 0; in_method = 0; in_comment = 0; pending = 0 }
  {
    line = $0
    gsub(/"([^"\\]|\\.)*"/, "\"\"", line)
    sub(/\/\/.*/, "", line)
  }
  in_comment { if (line ~ /\*\//) in_comment = 0; next }
  line ~ /\/\*/ && line !~ /\*\// { in_comment = 1; next }
  {
    opens  = gsub(/\{/, "{", line)
    closes = gsub(/\}/, "}", line)
    if (pending) {
      if (opens > 0)              { in_method = 1; pending = 0 }
      else if (line ~ /;[ \t]*$/) { pending = 0 }
    }
    else if (depth == 1 && !in_method && is_decl(line) && line ~ /\(/) {
      name = name_of(line); start = NR
      if (opens > 0) in_method = 1
      else if (line !~ /;[ \t]*$/) pending = 1
    }
    depth += opens - closes
    if (in_method && depth <= 1 && closes > 0) {
      printf "%s\t%d\t%d\n", name, start, NR
      in_method = 0
    }
  }
' "$FILE"
