#!/usr/bin/env bash
# PreToolUse hook: block package-manager "x" runner commands.
# Claude should use `bun run` or `just` instead.
#
# Stdin receives the Bash tool input as JSON: {"command": "..."}
# Output JSON with {"decision":"block","reason":"..."} to reject.

set -euo pipefail

INPUT=$(cat)

# Extract the command via jq. (Previously used `sed ... \s ...`, but BSD/macOS sed
# doesn't support \s, so extraction returned empty and this hook silently no-op'd.)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // .command // ""')

# Nothing to check
[ -z "$COMMAND" ] && exit 0

# Match: npx, bunx, pnpx, yarn dlx  (as the first token or after && / ; / |)
if echo "$COMMAND" | grep -qE '(^|&&|\|\||;|\|)[[:space:]]*(npx|bunx|pnpx|yarn[[:space:]]+dlx)\b'; then
  cat <<'EOF'
{"decision":"block","reason":"Do not use npx/bunx/pnpx/yarn dlx. Use `bun run <script>` or `just <recipe>` instead. If you need a CLI that isn't installed, ask the user before installing it."}
EOF
  exit 0
fi

# All git matches below anchor to command-start-or-separator (^ or after && || ; |),
# like the npx branch above — so a literal like "git add ." inside a quoted commit
# message (`git commit -m "ran git add ."`) is NOT a real command and won't match.
SEP='(^|&&|\|\||;|\|)[[:space:]]*'

# Block: git add -A / --all / -u / --update / bare `.` / bare `*` (incl. after a `--`
# end-of-options marker: `git add -- .`). Too broad — can stage secrets/junk.
# ponytail: matches the bare/whole-tree forms only; a narrow glob like `git add *.ts`
# or pathspec magic like `git add :/` slips through.
GITOPTS='([[:space:]]+-[^[:space:]]+(=[^[:space:]]+)?([[:space:]]+[^-[:space:]][^[:space:]]*)?)*'  # leading git flags, incl. `-C <path>`
if echo "$COMMAND" | grep -qE "${SEP}git${GITOPTS}[[:space:]]+add[[:space:]]+((-A|--all|-u|--update)\b|(--[[:space:]]+)?(\.|\*)([[:space:]]|\$))"; then
  cat <<'EOF'
{"decision":"block","reason":"Do not use `git add -A`/`--all`/`-u`/`.`/`*`. Stage specific files by name instead — it avoids committing secrets or junk."}
EOF
  exit 0
fi

# Block: --no-verify on a git commit/push — it bypasses the lefthook gates
# (lint, build, tests, coverage ratchet, destructive-migration/secrets guards).
# Also catch the short form `git commit -n` (== --no-verify): `-n` for commit can
# only be --no-verify, so any short-flag cluster containing `n` counts. NOT applied
# to push, where `-n` means --dry-run (harmless).
# ponytail: a commit MESSAGE containing the literal "--no-verify" also trips this
# (regex can't see quotes); reword the message in that rare case.
if echo "$COMMAND" | grep -qE "${SEP}git[[:space:]]+(commit|push)\b[^;&|]*--no-verify" \
  || echo "$COMMAND" | grep -qE "${SEP}git[[:space:]]+commit\b[^;&|]*[[:space:]]-[A-Za-z]*n[A-Za-z]*([[:space:]]|\$)"; then
  cat <<'EOF'
{"decision":"block","reason":"Do not use --no-verify. It bypasses the lefthook gates. Fix the underlying issue instead; a deliberate bypass requires explicit user approval in this conversation. (If this is a commit message that merely mentions the flag, reword it.)"}
EOF
  exit 0
fi

# Block: force-push (data-loss on the remote)
if echo "$COMMAND" | grep -qE "${SEP}git[[:space:]]+push\b[^;&|]*[[:space:]](--force-with-lease|--force|-f)\b"; then
  cat <<'EOF'
{"decision":"block","reason":"Do not force-push (--force/-f/--force-with-lease). It can overwrite remote history. If a push is rejected, pull/rebase and resolve, or ask the user."}
EOF
  exit 0
fi

exit 0
