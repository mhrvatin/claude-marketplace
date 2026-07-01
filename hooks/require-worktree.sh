#!/usr/bin/env bash
# PreToolUse (Write|Edit|MultiEdit): block editing unless inside a git worktree.
# Policy: never work in the main checkout — always create/use a worktree (EnterWorktree).
# ponytail: a linked worktree's git-dir is .git/worktrees/<name>; the main checkout's
# is plain .git. Matching /worktrees/ in the git-dir is the whole test — symlink-proof,
# no branch names, no path-of-cwd matching.
set -euo pipefail

cat >/dev/null  # drain stdin; only our location matters

git_dir=$(git rev-parse --git-dir 2>/dev/null || true)
[ -z "$git_dir" ] && exit 0  # not a git repo — don't interfere

case "$git_dir" in
  */worktrees/*) exit 0 ;;  # linked worktree — allowed
esac

reason="Work in a worktree, not the main checkout. Create one with the EnterWorktree tool, then make all edits there."
jq -n --arg r "$reason" '{decision:"block", reason:$r}'
exit 0
