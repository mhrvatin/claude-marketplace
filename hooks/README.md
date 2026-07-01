# hooks

A library of opt-in hook scripts, generalized from my personal setup so each can be
installed into whatever repo wants it.

**Nothing here is active.** These scripts are not wired into this repo's
`.claude/settings.json`, and they are deliberately *not* bundled into the
`mhrvatin-tools` plugin — a plugin's hooks are all-or-nothing on install, which
defeats per-hook opt-in. To use one, copy the script into a target repo and add the
wiring shown below. (If you ever want `claude plugin install` delivery instead, a
separate hooks-only plugin is possible — accepting that it's all-or-nothing.)

There are **two kinds of hook here, wired two different ways. They do not
interchange** — a git pre-commit script pasted into `settings.json` never fires, and
a Claude `PreToolUse` script dropped into `.git/hooks` never fires.

---

## 1. Claude Code hooks (wire in `settings.json`)

These run inside Claude Code, before/after tool calls, and can block the call.

| Script | Event / matcher | What it does | Assumes |
|--------|-----------------|--------------|---------|
| `no-x-commands.sh` | `PreToolUse` / `Bash` | Blocks `npx`/`bunx`/`pnpx`/`yarn dlx`, broad `git add` (`-A`/`.`/`*`), `--no-verify`, and force-push. | You use `bun`/`just` (the npx block assumes you have alternatives). |
| `no-add-secrets.sh` | `PreToolUse` / `Bash` | Early-blocks `git add` of secret files (`.env`, `*.pem`, `id_rsa`, …). | — |
| `block-protected-commits.sh` | `PreToolUse` / `Bash` | Blocks `git commit` on `main`/`master`/default branch. | — |
| `guard-git-add.py` | `PreToolUse` / `Bash` | Denies broad `git add` (`.`, `-A`, `-u`, `*`, bundled `-Av`…) via JSON permission decision. Requires `python3`. | — |
| `require-worktree.sh` | `PreToolUse` / `Write\|Edit\|MultiEdit` | Blocks edits unless cwd is inside a linked git worktree. | You use the `EnterWorktree` / `.claude/worktrees/` workflow. |
| `block-worktree-escape.sh` | `PreToolUse` / `Edit\|Write\|MultiEdit\|Bash` | When inside a `.claude/worktrees/<name>` worktree, blocks touching the main checkout (incl. `cd` out). No-op outside a worktree. | Same worktree workflow. |
| `no-version-ranges.sh` | `PreToolUse` / `Write\|Edit\|MultiEdit` | Blocks `^`/`~`/`*` version ranges in `package.json` (`workspace:*` allowed). No-op without a `package.json` edit. | You pin deps exactly. |
| `no-unpinned-actions.sh` | `PreToolUse` / `Write\|Edit\|MultiEdit` | Blocks GitHub Actions pinned by tag/branch instead of a 40-char commit SHA. No-op outside `.github/workflows/`. | — |
| `worktree-setup.sh` | `PostToolUse` / `EnterWorktree` | New worktree: runs `bun install` and symlinks main-checkout `.claude/skills` that the worktree lacks. | `bun`; the worktree workflow. |
| `worktree-grove-down.sh` | `PostToolUse` / `ExitWorktree` | Stops the grove dev server for the worktree being torn down. **facit-specific** — self-guards to a no-op in any repo without `tools/grove/grove-down.ts`. | grove + `bun`. |

### Wiring

Copy the script into the target repo's `.claude/hooks/`, then merge into its
`.claude/settings.json`. `$CLAUDE_PROJECT_DIR` resolves to the repo root. Example
covering several of the above (the matchers are taken verbatim from my facit setup):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/no-x-commands.sh\"" },
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/no-add-secrets.sh\"" }
        ]
      },
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/require-worktree.sh\"" },
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/no-version-ranges.sh\"" },
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/no-unpinned-actions.sh\"" }
        ]
      }
    ],
    "PostToolUse": [
      { "matcher": "EnterWorktree", "hooks": [{ "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/worktree-setup.sh\"" }] }
    ]
  }
}
```

`block-protected-commits.sh` and `guard-git-add.py` are `PreToolUse(Bash)` hooks I
run at the **user** level (`~/.claude/settings.json`, command `bash
~/.claude/hooks/<script>`). Their wiring above is **inferred from the script
headers**, not copied from a settings file. Wire them at whichever scope you want.

### Optional inline formatter (no script — a `PostToolUse` one-liner)

My facit setup also formats edited files via an inline command (not a file in this
dir). Adapt the tool to your project:

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
commit. They are **not** Claude hooks — they belong in your git hook runner.

| Script | What it does | Assumes |
|--------|--------------|---------|
| `no-secrets-commit.sh` | Refuses to commit secret/credential files (`.env`, `*.pem`, `id_rsa`, …). The robust backstop for `no-add-secrets.sh`. | — |
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

- **Protected-branch commits:** `block-protected-commits.sh` (Claude `PreToolUse`) ≈ `no-main-commit.sh` (git pre-commit).
- **Broad `git add`:** `guard-git-add.py` and the `git add` branch of `no-x-commands.sh` (both Claude `PreToolUse`).
- **Secret files:** `no-add-secrets.sh` (Claude, early) is the soft gate; `no-secrets-commit.sh` (git, robust) is the backstop. These two *complement* each other — installing both is intentional.

## Testing

`worktree-hooks.test.sh` is a self-check for `block-worktree-escape.sh` +
`worktree-setup.sh`. Run it from this dir: `bash worktree-hooks.test.sh`.
