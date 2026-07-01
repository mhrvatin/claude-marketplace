#!/usr/bin/env bash
# PreToolUse(ExitWorktree): stop the grove dev server for the worktree being
# torn down, so its detached FE+BE don't leak as orphans after the worktree is
# removed. Runs BEFORE removal while the dir + instance file still exist, so
# grove-down can resolve and match it. Self-guards: no-op outside a worktree
# and in any repo without grove (tools/grove/grove-down.ts absent).
set -euo pipefail
input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')

case "$cwd" in */.claude/worktrees/*) ;; *) exit 0 ;; esac
repo="${cwd%%/.claude/worktrees/*}"
rest="${cwd#"$repo"/.claude/worktrees/}"
name="${rest%%/*}"                                   # active worktree = instance name

[ -f "$repo/tools/grove/grove-down.ts" ] || exit 0   # not a grove repo
(cd "$repo" && bun run tools/grove/grove-down.ts "$name") || true
exit 0
