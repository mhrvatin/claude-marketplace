#!/usr/bin/env python3
"""PreToolUse(Bash) guard: block `git add` forms that stage broadly.

Allows `git add <explicit paths>`; denies `git add .`, `-A`, `--all`,
`-u`, `--update`, `:/`, `*`, and bundled short flags containing A or u
(e.g. `-Av`). Sees the literal command before the shell expands globs,
so `git add *` is caught too.

Deny == JSON permissionDecision on stdout, exit 0. Anything else: exit 0,
no output (defer to normal permission flow).
"""
import sys, json, shlex, re

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

cmd = (data.get("tool_input") or {}).get("command", "")
if not cmd or "git" not in cmd or "add" not in cmd:
    sys.exit(0)


def deny(reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }}))
    sys.exit(0)


DANGEROUS = {".", "-A", "--all", "-u", "--update", ":/", "*"}
BUNDLED = re.compile(r"-[A-Za-z]*[Au][A-Za-z]*$")  # -A, -u, -Av, -uf, -Au ...

# Split on shell separators so we inspect each sub-command.
for seg in re.split(r"&&|\|\||\||;|\n", cmd):
    try:
        toks = shlex.split(seg)
    except ValueError:
        toks = seg.split()
    n = len(toks)
    i = 0
    while i < n:
        if toks[i] != "git":
            i += 1
            continue
        # Skip git's own option tokens to reach the subcommand — including options
        # whose value is a SEPARATE token (`-C <path>`, `-c <key=val>`) — so an
        # interposed flag like `git -C /repo add .` can't hide the `add`.
        j = i + 1
        while j < n and toks[j].startswith("-"):
            j += 2 if toks[j] in ("-C", "-c") and j + 1 < n else 1
        if j < n and toks[j] == "add":
            for a in toks[j + 1:]:
                if a in DANGEROUS or BUNDLED.fullmatch(a):
                    deny(
                        f"`git add {a}` stages broadly and is blocked by policy. "
                        "Stage explicit filenames instead (e.g. `git add path/to/file`)."
                    )
            break
        i = j + 1

sys.exit(0)
