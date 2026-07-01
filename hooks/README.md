# hooks

Git pre-commit hooks live here as a copy-paste library. Claude Code hooks moved out
to installable plugins — see below — since Claude Code plugins *can* bundle
`PreToolUse`/`PostToolUse` hooks, unlike git pre-commit hooks which have no plugin
delivery mechanism at all (they run via lefthook/`.git/hooks`, outside Claude Code
entirely).

**Two kinds of hook, wired two different ways. They do not interchange** — a git
pre-commit script pasted into `settings.json` never fires, and a Claude
`PreToolUse` script dropped into `.git/hooks` never fires.

---

## 1. Claude Code hooks — now plugins

Installable via `claude plugin install <name>@mhrvatin`, grouped by theme so you
opt into a theme instead of every hook at once:

| Plugin | Hooks | What it does |
|--------|-------|--------------|
| `mhr-guardrails` | `no-x-commands.sh`, `no-add-secrets.sh`, `block-protected-commits.sh`, `guard-git-add.py` | `PreToolUse(Bash)`: blocks `npx`/`bunx`-style runners, `--no-verify`, force-push, broad `git add`, commits on `main`/`master`, and staging secret files. |
| `mhr-worktree` | `require-worktree.sh`, `block-worktree-escape.sh`, `worktree-setup.sh`, `worktree-grove-down.sh` | Requires edits happen inside a git worktree, blocks escaping back to the main checkout, and provisions/tears down worktrees on `EnterWorktree`/`ExitWorktree`. |
| `mhr-pinning` | `no-version-ranges.sh`, `no-unpinned-actions.sh` | `PreToolUse(Write\|Edit\|MultiEdit)`: blocks non-exact `package.json` version ranges and GitHub Actions not pinned to a commit SHA. |

Source lives in each plugin's `plugins/<name>/hooks/` — see there for the scripts
and `hooks.json` wiring. `mhr-guardrails` bundles both `guard-git-add.py` and the
`git add` branch of `no-x-commands.sh`; they enforce the same thing redundantly
(harmless — either can fire) rather than conflict.

If you'd rather copy-paste a single script into a target repo instead of installing
a themed plugin, grab it from the relevant `plugins/<name>/hooks/` directory and
wire it into that repo's `.claude/settings.json` yourself, using
`$CLAUDE_PROJECT_DIR` in place of `${CLAUDE_PLUGIN_ROOT}`.

### Optional inline formatter (no script — a `PostToolUse` one-liner)

Not part of any plugin since it's not a script file. Adapt the tool to your project
and wire directly into `settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          { "type": "command", "command": "jq -r '.tool_input.file_path // empty' | { read -r f; [ -n \"$f\" ] && just lint-fix \"$f\"; } || true" }
        ]
      }
    ]
  }
}
```

---

## 2. Git pre-commit hooks (wire via lefthook or `.git/hooks`)

These run at `git commit` time, scan the staged diff, and `exit 1` to abort the
commit. They are **not** Claude hooks, and there's no plugin delivery for them —
copy the script into the target repo and wire it into that repo's git hook runner.

| Script | What it does | Assumes |
|--------|--------------|---------|
| `no-secrets-commit.sh` | Refuses to commit secret/credential files (`.env`, `*.pem`, `id_rsa`, …). The robust backstop for `no-add-secrets.sh` (in `mhr-guardrails`). | — |
| `no-destructive-migration.sh` | Blocks destructive SQL (`DROP`/`RENAME`/`TRUNCATE`/`DELETE`) in any staged `migrations/*.sql`. | A `migrations/` dir of `.sql` files (path is generalized; narrow the grep if you want). |
| `no-main-commit.sh` | Refuses commits on `main`. | — |
| `no-node-modules-commit.sh` | Rejects a staged `node_modules` (catches symlinks that slip past `.gitignore`). | — |

### Wiring — lefthook (`lefthook.yml`)

```yaml
pre-commit:
  commands:
    no-secrets:
      run: bash .claude/hooks/no-secrets-commit.sh
    no-destructive-migration:
      run: bash .claude/hooks/no-destructive-migration.sh
    no-node-modules:
      run: bash .claude/hooks/no-node-modules-commit.sh
    no-main-commit:
      run: bash .claude/hooks/no-main-commit.sh
```

### Wiring — native git (`.git/hooks/pre-commit`)

```bash
#!/usr/bin/env bash
set -e
for h in no-secrets-commit no-destructive-migration no-node-modules-commit no-main-commit; do
  bash "$(git rev-parse --show-toplevel)/.claude/hooks/$h.sh"
done
```

---

## Overlaps — don't install redundant guards

These pairs enforce the same intent two different ways. Pick the one that matches
where you want the check to fire (in Claude vs. at commit time), not both:

- **Protected-branch commits:** `block-protected-commits.sh` (in `mhr-guardrails`, Claude `PreToolUse`) ≈ `no-main-commit.sh` (git pre-commit).
- **Secret files:** `no-add-secrets.sh` (in `mhr-guardrails`, Claude, early) is the soft gate; `no-secrets-commit.sh` (git, robust) is the backstop. These two *complement* each other — installing both is intentional.

## Testing

`plugins/mhr-worktree/hooks/worktree-hooks.test.sh` is a self-check for
`block-worktree-escape.sh` + `worktree-setup.sh`. Run it from that dir: `bash
worktree-hooks.test.sh`.
