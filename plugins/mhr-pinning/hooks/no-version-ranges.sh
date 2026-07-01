#!/usr/bin/env bash
# PreToolUse (Write|Edit|MultiEdit): block introducing non-exact dependency versions in package.json.
# Policy: pin all package versions exactly — no ^, ~, or * (workspace:* is allowed).
set -euo pipefail

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')
case "$FILE" in
  */package.json | package.json) ;;
  *) exit 0 ;;
esac

# Write → .content; Edit → .new_string; MultiEdit → each edits[].new_string (no
# top-level content/new_string), so concatenate them or a MultiEdit slips through.
NEW=$(printf '%s' "$INPUT" | jq -r '(.tool_input.content // .tool_input.new_string // "") + ([.tool_input.edits[]? | .new_string // empty] | join("\n"))')

# Match dependency lines:  "name": "^1.2.3" | "~1.2" | "*"  (workspace:* starts with 'w', not flagged).
# ponytail: catches the common "add/replace a whole dep line" case; a value-only Edit
# (new_string == "^1.2.4" with no key/quotes) slips through. Nothing backstops that
# today (no pre-commit/CI range check) — `bun add --exact` is the real safeguard.
BAD=$(printf '%s' "$NEW" | grep -nE '"[^"]+"[[:space:]]*:[[:space:]]*"[~^][0-9]|"[^"]+"[[:space:]]*:[[:space:]]*"\*"' || true)

if [ -n "$BAD" ]; then
  reason="Pin package versions exactly: no ^, ~, or * ranges — workspace:* is allowed. Use \`bun add --exact\` (or your package manager's exact-pin flag) or write the exact version. Offending: ${BAD//$'\n'/ ; }"
  jq -n --arg r "$reason" '{decision:"block", reason:$r}'
  exit 0
fi
exit 0
