#!/usr/bin/env bash
# PreToolUse(Edit|Write|MultiEdit|Bash|Read|Glob|Grep|NotebookEdit): when the session is in a git worktree
# under .claude/worktrees/<name>, block touching repo files that live OUTSIDE
# the worktree (the main checkout) and redirect back into the worktree. The
# point of a worktree is isolation — reaching the root defeats it.
#
# Skills the worktree lacks (e.g. gitignored ones like impeccable) are
# symlinked in by worktree-setup.sh, so there is no legit reason to leave.
#
# Catches absolute references to the main checkout (`find $repo`, `--flag=$repo/x`)
# AND `cd`/`pushd` out of the worktree (relative or absolute) — the latter is the
# linchpin: once cwd drifts out, the next hook call sees a non-worktree cwd and
# the guard goes dark, so the climb must be stopped before it happens.
# ponytail ceiling: a literal "cd" token inside an arg (e.g. `echo cd ..`) can
# false-positive, and unexpanded vars (`cd $HOME`) aren't resolved. Live with it.
set -euo pipefail
input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')

# Only act inside a worktree.
case "$cwd" in */.claude/worktrees/*) ;; *) exit 0 ;; esac

repo="${cwd%%/.claude/worktrees/*}"                 # main checkout root
rest="${cwd#"$repo"/.claude/worktrees/}"
wt="$repo/.claude/worktrees/${rest%%/*}"            # active worktree root
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')

block() {                                            # $1 = offending path
  local rel="${1#"$repo"/}"
  echo "Blocked: $1 is in the main checkout, not the worktree. Stay in the worktree — use $wt/$rel instead." >&2
  exit 2
}

# Lexically resolve `.`/`..` so `$wt/../../x` can't prefix-match its way back
# "inside" the worktree and slip past escapes(). Falls back to the raw path if
# python3 is missing (same coverage as before — no regression).
normalize() { python3 -c 'import os,sys; print(os.path.normpath(sys.argv[1]))' "$1" 2>/dev/null || printf '%s' "$1"; }

# Absolute path under the repo but outside the active worktree?
escapes() { case "$1" in "$repo"|"$repo"/*) [[ "$1" != "$wt" && "$1" != "$wt"/* ]] ;; *) return 1 ;; esac; }

case "$tool" in
  Edit|Write|MultiEdit|Read)
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
    case "$file" in /*) file=$(normalize "$file"); escapes "$file" && block "$file" ;; esac
    ;;
  NotebookEdit)
    file=$(printf '%s' "$input" | jq -r '.tool_input.notebook_path // empty')
    case "$file" in /*) file=$(normalize "$file"); escapes "$file" && block "$file" ;; esac
    ;;
  Glob|Grep)
    # `path` is optional (defaults to cwd, always in-worktree) and only
    # checked when absolute — same ponytail as Edit/Write above.
    file=$(printf '%s' "$input" | jq -r '.tool_input.path // empty')
    case "$file" in /*) file=$(normalize "$file"); escapes "$file" && block "$file" ;; esac
    ;;
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
    # Peel shell metacharacters off path tokens so `cd $wt;` / `--flag=$repo/x`
    # / `a:$repo/b` tokenize to bare paths instead of gluing punctuation on.
    norm=$cmd
    for ch in '=' ':' ';' '&' '|' '(' ')' '<' '>' '"' "'" '`' ','; do norm=${norm//"$ch"/ }; done
    set -f                                           # no glob expansion while scanning
    read -ra toks <<<"$norm"
    for ((i = 0; i < ${#toks[@]}; i++)); do
      tok=${toks[i]}
      case "$tok" in *..*) tok=$(normalize "$tok") ;; esac  # collapse `..` before the prefix test
      escapes "$tok" && block "$tok"                 # absolute ref into main checkout
      case "$tok" in
        cd|pushd)                                    # leaving the worktree disarms the guard
          arg=${toks[i + 1]-}; [ -n "$arg" ] || arg=$HOME
          [ "$arg" = "-" ] && continue               # `cd -` (prev dir): unknowable, skip
          target=$(cd "$cwd" 2>/dev/null && cd "$arg" 2>/dev/null && pwd) || true
          [ -n "$target" ] && [ "$target" != "$wt" ] && [[ "$target" != "$wt"/* ]] && block "$target"
          ;;
      esac
    done
    set +f
    ;;
esac
exit 0
