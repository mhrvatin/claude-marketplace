#!/usr/bin/env python3
"""PreToolUse guard: best-effort early block of reading .env files via the
Read tool, Grep tool, or Bash commands that dump file contents (cat/less/
more/head/tail/sed/awk/grep/strings/xxd/od/dd/base64/tee/scp/rsync/cp/mv
plus editors like vi/vim/nano/code) — including through `sudo`/`env`/
`command`/`xargs` prefixes and nested `bash -c "..."` / `sh -c "..."` shells.

Blocks any path whose basename is `.env` or `.env.<suffix...>`, EXCEPT
common safe-template suffixes (example/sample/template/dist/defaults)
which are meant to be committed and read. Glob-style tokens (`.env*`) are
also matched.

This is string/token matching on the command line, not a filesystem-level
control — it does not catch every bypass (e.g. an interpreter one-liner
that never spells the path as a literal token, or a file already copied
under another name). It just fails sooner than letting the read happen.

Deny == JSON permissionDecision on stdout, exit 0. Anything else: exit 0,
no output (defer to normal permission flow).
"""
import sys, json, re, shlex, fnmatch, os

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool_input = data.get("tool_input") or {}

ALLOWED_SUFFIXES = {"example", "sample", "template", "dist", "defaults"}

ENV_RE = re.compile(r"(?:^|/)\.env(?:\.([A-Za-z0-9_.-]+))?$")


def is_blocked_env_path(path):
    m = ENV_RE.search(path)
    if not m:
        return False
    suffix = m.group(1)
    if suffix:
        first = suffix.split(".", 1)[0].lower()
        if first in ALLOWED_SUFFIXES:
            return False
    return True


def matches_env_glob(token):
    if not any(ch in token for ch in "*?["):
        return False
    return fnmatch.fnmatch(".env", token) or fnmatch.fnmatch(".env.local", token)


def deny(reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }}))
    sys.exit(0)


# Read tool: {"file_path": "..."}
file_path = tool_input.get("file_path")
if file_path and is_blocked_env_path(file_path):
    deny(
        f"Reading `{file_path}` is blocked by policy: .env files hold secrets. "
        "If you need to know whether a var is set, ask the user or check .env.example."
    )

# Grep tool: {"path": "...", "glob": "..."} — a matching search still returns file contents.
for key in ("path", "glob"):
    val = tool_input.get(key)
    if val and (is_blocked_env_path(val) or matches_env_glob(os.path.basename(val))):
        deny(
            f"Searching `{val}` is blocked by policy: .env files hold secrets. "
            "If you need to know whether a var is set, ask the user or check .env.example."
        )

READ_CMDS = {
    "cat", "less", "more", "head", "tail", "sed", "awk", "grep",
    "strings", "xxd", "od", "vi", "vim", "nano", "code", "bat",
    "dd", "base64", "tee", "scp", "rsync", "cp", "mv",
    "nl", "tac", "rev", "cut", "tr", "paste",
}
SHELLS = {"bash", "sh", "zsh", "dash", "ksh"}
PASSTHROUGH = {"sudo", "command", "env", "xargs", "nice", "nohup", "time"}


def check_segment(seg):
    try:
        toks = shlex.split(seg)
    except ValueError:
        toks = seg.split()
    if not toks:
        return

    cmd = os.path.basename(toks[0])

    # Strip passthrough wrappers (sudo, env, xargs, ...) and re-check the remainder.
    if cmd in PASSTHROUGH:
        rest = [t for t in toks[1:] if not (t.startswith("-") or "=" in t)]
        if rest:
            check_segment(shlex.join(rest))
        return

    # Nested shell invocation: recurse into the `-c` argument string.
    if cmd in SHELLS:
        for i, t in enumerate(toks):
            if t == "-c" and i + 1 < len(toks):
                for sub in re.split(r"&&|\|\||\||;|\n", toks[i + 1]):
                    check_segment(sub)
        return

    if cmd not in READ_CMDS:
        return

    for tok in toks[1:]:
        if tok.startswith("-"):
            continue
        base = os.path.basename(tok)
        if is_blocked_env_path(tok) or matches_env_glob(base):
            deny(
                f"Reading `.env` files via shell (`{toks[0]} {tok}`) is blocked by policy: "
                "they hold secrets. If you need to know whether a var is set, ask the user "
                "or check .env.example."
            )


# Bash tool: {"command": "..."}
cmd = tool_input.get("command", "")
if cmd:
    for seg in re.split(r"&&|\|\||\||;|\n", cmd):
        check_segment(seg)

sys.exit(0)
