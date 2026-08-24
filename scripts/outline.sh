#!/usr/bin/env bash
#
# outline.sh — print the structure of a Java file without printing the file.
#
# Stage 1 ("Read Less") uses this to answer "what is in this class?" for a couple of
# hundred tokens instead of attaching several hundred lines. You then pull in only the
# part you actually need.
#
# NOTE: VS Code has no line-range attach syntax. (`#file.cs: 66-72` is Visual Studio,
# a different product.) In VS Code the line numbers below are for YOU — use them to
# jump to the span, then hand Copilot the narrow thing:
#     #selection      highlight the span first — cheapest possible attachment
#     #symbolName     open the file, then mention the method by name
#
# Usage:
#   ./scripts/outline.sh src/main/java/com/meridian/payments/PaymentService.java
#   ./scripts/outline.sh $(find src/main -name '*.java')
#
# No dependencies beyond bash + awk. Works on macOS and Linux.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <file.java> [file.java ...]" >&2
  exit 2
fi

for FILE in "$@"; do
  if [ ! -f "$FILE" ]; then
    echo "outline: no such file: $FILE" >&2
    continue
  fi

  TOTAL=$(wc -l < "$FILE" | tr -d ' ')
  echo ""
  echo "=== $FILE  (${TOTAL} lines) ==="

  awk '
    function tidy(s) {
      gsub(/^[ \t]+/, "", s); gsub(/[ \t]+$/, "", s)
      gsub(/[ \t]*\{[ \t]*$/, "", s); gsub(/[ \t]+/, " ", s)
      return s
    }
    # Looks like the beginning of a member declaration (not a control statement).
    function is_decl(s) {
      return s ~ /^[ \t]*(public|private|protected|static|final|synchronized|abstract|native)[ \t]/ &&
             s !~ /^[ \t]*(if|for|while|switch|catch|try|else|do|return|new)[ \t(]/
    }

    BEGIN { depth = 0; in_method = 0; in_comment = 0; pending = 0 }
    {
      # Work on a sanitised copy so braces inside strings/comments do not skew depth.
      line = $0
      gsub(/"([^"\\]|\\.)*"/, "\"\"", line)
      sub(/\/\/.*/, "", line)
    }
    in_comment { if (line ~ /\*\//) in_comment = 0; next }
    line ~ /\/\*/ && line !~ /\*\// { in_comment = 1; next }
    {
      opens  = gsub(/\{/, "{", line)
      closes = gsub(/\}/, "}", line)

      # --- continue a multi-line signature (e.g. a constructor with one param per line)
      if (pending) {
        sig = sig " " tidy(line)
        if (opens > 0)      { in_method = 1; pending = 0 }
        else if (line ~ /;[ \t]*$/) {
          printf "  field   %10s         %s\n", start "-" NR, tidy(sig)
          pending = 0
        }
      }
      # --- members sit at depth 1, directly inside the class body
      else if (depth == 1 && !in_method && is_decl(line)) {
        if (line ~ /\(/ && opens > 0) {              # single-line method signature
          sig = tidy(line); start = NR; in_method = 1
        }
        else if (line ~ /\(/ && line !~ /;[ \t]*$/) { # signature continues on later lines
          sig = tidy(line); start = NR; pending = 1
        }
        else if (line ~ /;[ \t]*$/ && opens == 0) {   # field / constant
          printf "  field   %10s         %s\n", NR, tidy(line)
        }
      }

      depth += opens - closes

      if (in_method && depth <= 1 && closes > 0) {
        printf "  method  %10s  %6s  %s\n", start "-" NR, "(" (NR - start + 1) "L)", sig
        in_method = 0
      }
    }
  ' "$FILE"
done

cat <<'EOF'

Line numbers above are for navigation, not for attaching — VS Code has no
line-range mention syntax. To hand Copilot just one method:

  1. Go to the line range above (Ctrl+G / Cmd+G)
  2. Select the method body, then type  #selection   <- cheapest
     or, with the file open, mention it by name:  #processPayment

EOF
