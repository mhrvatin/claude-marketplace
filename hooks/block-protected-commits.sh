#!/bin/bash
# PreToolUse hook: block `git commit` on the default branch, main, or master.
# Exit 0 = allow. Exit 2 = block with stderr shown to model.

cmd=$(jq -r '.tool_input.command // ""')

# Only act on git commit invocations. Match `git commit`, `git -C path commit`,
# `git -c key=val commit`, and chained forms (`... && git commit ...`). Leading git
# option tokens are skipped — including ones whose value is a SEPARATE token
# (`-C <path>`, `-c <key=val>`) — so an interposed flag can't hide the subcommand.
echo "$cmd" | grep -qE '(^|[[:space:];&|(][[:space:]]*)git([[:space:]]+-[^[:space:]]+(=[^[:space:]]+)?([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+commit([[:space:]]|$)' || exit 0

# If the command targets another repo via a top-level `git -C <dir>` (before the
# subcommand — not `git commit -C <commit>`, which reuses a message), check THAT
# repo's branch, else `git -C /other commit` is judged against the wrong HEAD.
dir=$(echo "$cmd" | grep -oE 'git([[:space:]]+-[^C[:space:]][^[:space:]]*(=[^[:space:]]+)?([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+-C[[:space:]]+[^[:space:]]+' | head -1 | grep -oE '[^[:space:]]+$')
gitc=(); [ -n "$dir" ] && gitc=(-C "$dir")

branch=$(git "${gitc[@]}" rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
[ -z "$branch" ] && exit 0

default=$(git "${gitc[@]}" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')

if [ "$branch" = "main" ] || [ "$branch" = "master" ] || { [ -n "$default" ] && [ "$branch" = "$default" ]; }; then
  echo "Refusing to commit on protected branch '$branch'. Create a feature branch first (e.g. git checkout -b <name>)." >&2
  exit 2
fi

exit 0
