#!/usr/bin/env bash
# Self-check for block-worktree-escape.sh + worktree-setup.sh.
# Run: bash ~/.claude/hooks/worktree-hooks.test.sh
set -uo pipefail
H="$(cd "$(dirname "$0")" && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
wt="$repo/.claude/worktrees/feat+x"
mkdir -p "$wt/packages" "$repo/packages" "$repo/.claude/skills/impeccable"

fail=0
ok() { echo "ok: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

# --- block-worktree-escape.sh ---
run() { # tool, json-payload-of-tool_input ; echoes exit code
  printf '%s' "$1" | bash "$H/block-worktree-escape.sh" >/dev/null 2>&1
  echo $?
}
guard() { # tool_name, tool_input(json) -> exit code, cwd=worktree
  local in; in=$(jq -nc --arg cwd "$wt" --arg t "$1" --argjson ti "$2" \
    '{cwd:$cwd, tool_name:$t, tool_input:$ti}')
  printf '%s' "$in" | bash "$H/block-worktree-escape.sh" >/dev/null 2>&1; echo $?
}

# Edit outside worktree -> blocked (2)
[ "$(guard Edit "$(jq -nc --arg f "$repo/packages/a.ts" '{file_path:$f}')")" = 2 ] \
  && ok "edit main-checkout blocked" || bad "edit main-checkout should block"
# Edit inside worktree -> allowed (0)
[ "$(guard Edit "$(jq -nc --arg f "$wt/packages/a.ts" '{file_path:$f}')")" = 0 ] \
  && ok "edit in-worktree allowed" || bad "edit in-worktree should pass"
# Edit with `..` traversal escaping the worktree -> blocked (path normalized)
[ "$(guard Edit "$(jq -nc --arg f "$wt/../../secret.ts" '{file_path:$f}')")" = 2 ] \
  && ok "edit ..-escape blocked" || bad "edit ..-escape should block"
# Bash cd to repo root -> blocked
[ "$(guard Bash "$(jq -nc --arg c "cd $repo && ls" '{command:$c}')")" = 2 ] \
  && ok "bash cd-to-root blocked" || bad "bash cd-to-root should block"
# Bash find on main checkout -> blocked
[ "$(guard Bash "$(jq -nc --arg c "find $repo/packages -name '*.ts'" '{command:$c}')")" = 2 ] \
  && ok "bash find-on-root blocked" || bad "bash find-on-root should block"
# Bash --flag=PATH form -> blocked
[ "$(guard Bash "$(jq -nc --arg c "grep --include=x -r foo $repo/packages" '{command:$c}')")" = 2 ] \
  && ok "bash flag-path blocked" || bad "bash flag-path should block"
# Bash staying in worktree -> allowed
[ "$(guard Bash "$(jq -nc --arg c "find $wt/packages -name '*.ts'" '{command:$c}')")" = 0 ] \
  && ok "bash in-worktree allowed" || bad "bash in-worktree should pass"
# Bash absolute `..` token escaping the worktree -> blocked (path normalized)
[ "$(guard Bash "$(jq -nc --arg c "cat $wt/../../secret.ts" '{command:$c}')")" = 2 ] \
  && ok "bash ..-token-escape blocked" || bad "bash ..-token-escape should block"
# Bash cd into worktree with trailing ';' -> allowed (metachar peeled off)
[ "$(guard Bash "$(jq -nc --arg c "cd $wt; ls" '{command:$c}')")" = 0 ] \
  && ok "bash cd-worktree+semicolon allowed" || bad "bash cd-worktree+semicolon should pass"
# Bash relative cd OUT of the worktree -> blocked (the linchpin)
[ "$(guard Bash "$(jq -nc '{command:"cd ../../.. && grep -r x ."}')")" = 2 ] \
  && ok "bash relative cd-out blocked" || bad "bash relative cd-out should block"
# Bash `cd ..` (one level out) -> blocked
[ "$(guard Bash "$(jq -nc '{command:"cd .. && ls"}')")" = 2 ] \
  && ok "bash cd-one-level-out blocked" || bad "bash cd-one-level-out should block"
# Bash `cd` with no arg (home) -> blocked
[ "$(guard Bash "$(jq -nc '{command:"cd"}')")" = 2 ] \
  && ok "bash bare-cd-home blocked" || bad "bash bare-cd-home should block"
# Bash cd into a worktree subdir -> allowed
[ "$(guard Bash "$(jq -nc --arg c "cd $wt/packages && ls" '{command:$c}')")" = 0 ] \
  && ok "bash cd-worktree-subdir allowed" || bad "bash cd-worktree-subdir should pass"
# Bash referencing ~/.claude (outside repo) -> allowed
[ "$(guard Bash "$(jq -nc '{command:"cat /Users/x/.claude/skills/impeccable/SKILL.md"}')")" = 0 ] \
  && ok "bash outside-repo allowed" || bad "bash outside-repo should pass"
# Not in a worktree at all -> allowed regardless
notwt=$(jq -nc --arg cwd "$repo" '{cwd:$cwd, tool_name:"Bash", tool_input:{command:"cd / && ls"}}')
printf '%s' "$notwt" | bash "$H/block-worktree-escape.sh" >/dev/null 2>&1
[ "$?" = 0 ] && ok "non-worktree session allowed" || bad "non-worktree should pass"

# --- worktree-setup.sh (skill symlink bridge) ---
setup=$(jq -nc --arg wt "$wt" '{tool_response:{worktreePath:$wt}}')
printf '%s' "$setup" | bash "$H/worktree-setup.sh" >/dev/null 2>&1
if [ -L "$wt/.claude/skills/impeccable" ]; then ok "skill symlinked into worktree"; else bad "skill should be symlinked"; fi

exit $fail
