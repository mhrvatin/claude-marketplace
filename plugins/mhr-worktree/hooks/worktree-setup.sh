#!/usr/bin/env bash
# PostToolUse(EnterWorktree): make a new worktree self-contained, so agents
# never need to reach back to the main checkout.
#   1. install deps (a fresh worktree has no node_modules)
#   2. symlink any .claude/skills that exist in the main checkout but are
#      missing from the worktree. Gitignored skills (e.g. impeccable) aren't
#      checked out into a worktree; without this an agent finds the skill
#      absent and tries to run it from the repo root. The skills resolve all
#      their working state from cwd, so a symlink run with cwd=worktree keeps
#      state inside the worktree.
set -euo pipefail
input=$(cat)
wt=$(printf '%s' "$input" | jq -r '.tool_response.worktreePath // empty')
[ -n "$wt" ] || exit 0

# deps
if [ -f "$wt/package.json" ] && [ ! -d "$wt/node_modules" ]; then
  (cd "$wt" && bun install) || true
fi

# bridge local-only skills
case "$wt" in
  */.claude/worktrees/*) repo="${wt%%/.claude/worktrees/*}" ;;
  *) exit 0 ;;
esac
src="$repo/.claude/skills"
dst="$wt/.claude/skills"
[ -d "$src" ] || exit 0
mkdir -p "$dst"

# .gitignore uses dir patterns (trailing slash) that don't match a symlink, so
# git would see the bridged skill as untracked. Add it to the repo-local
# info/exclude (shared, never committed) so it can't be staged. In the main
# checkout the real dir is already ignored, so the extra entry is a no-op.
exclude=$(cd "$wt" && git rev-parse --git-path info/exclude 2>/dev/null || true)
ignore() {
  [ -n "$exclude" ] || return 0
  grep -qxF "$1" "$exclude" 2>/dev/null || echo "$1" >>"$exclude"
}

for d in "$src"/*/; do
  [ -d "$d" ] || continue                       # no-match glob guard
  name=$(basename "$d")
  if [ -L "$dst/$name" ]; then ignore "/.claude/skills/$name"; continue; fi  # ours; heal exclude
  if [ -e "$dst/$name" ]; then continue; fi     # committed dir/file — leave alone
  ln -s "$src/$name" "$dst/$name"
  ignore "/.claude/skills/$name"
done
exit 0
