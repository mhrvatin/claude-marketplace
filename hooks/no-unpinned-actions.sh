#!/usr/bin/env bash
# PreToolUse (Write|Edit|MultiEdit): block GitHub Actions pinned by tag/branch instead of a commit SHA.
# Policy: pin GitHub Actions by full 40-char commit SHA with a `# vX` comment.
set -euo pipefail

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')
case "$FILE" in
  *.github/workflows/*.yml | *.github/workflows/*.yaml) ;;
  *) exit 0 ;;
esac

# Write → .content; Edit → .new_string; MultiEdit → each edits[].new_string (no
# top-level content/new_string), so concatenate them or a MultiEdit slips through.
NEW=$(printf '%s' "$INPUT" | jq -r '(.tool_input.content // .tool_input.new_string // "") + ([.tool_input.edits[]? | .new_string // empty] | join("\n"))')

# `uses: owner/repo@<ref>` where ref is NOT a 40-hex SHA, ignoring local (./) actions.
BAD=$(printf '%s' "$NEW" \
  | grep -nE '^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*[^@[:space:]]+@[^[:space:]]+' \
  | grep -vE 'uses:[[:space:]]*\./' \
  | grep -vE '@[0-9a-f]{40}([[:space:]]|#|$)' || true)

if [ -n "$BAD" ]; then
  reason="Pin GitHub Actions by full 40-char commit SHA with a \`# vX\` comment, not a tag/branch. Offending: ${BAD//$'\n'/ ; }"
  jq -n --arg r "$reason" '{decision:"block", reason:$r}'
  exit 0
fi
exit 0
