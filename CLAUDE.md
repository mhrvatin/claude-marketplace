# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal Claude Code **marketplace** — a static distribution of commands, agents, and skills. There is no build, test, or lint step; the "code" is Markdown prompts plus shell/Python hook scripts. Changes are validated by installing and running them, not by a test suite.

## Layout

- `.claude-plugin/marketplace.json` — marketplace manifest. Lists plugins and their `source` paths. Edit when adding/removing a plugin.
- `plugins/mhr/` — commands/agents/skills. Its `.claude-plugin/plugin.json` is the plugin manifest; `commands/`, `agents/`, and `skills/` hold the actual content (each a Markdown file with YAML frontmatter; skills are directories containing `SKILL.md` plus reference `.md` files).
- `plugins/mhr-guardrails/`, `plugins/mhr-worktree/`, `plugins/mhr-pinning/` — themed Claude Code hook plugins. Each has `hooks/hooks.json` (the wiring, using `${CLAUDE_PLUGIN_ROOT}`) plus the hook scripts themselves. Split by theme, not bundled into one, so installing one doesn't turn on unrelated hooks.
- `hooks/` — a **standalone library** of git pre-commit hook scripts only (Claude Code hooks live in the plugins above). No plugin delivery mechanism exists for these — they run via lefthook/`.git/hooks`, outside Claude Code entirely. Consumed by copying a script into a target repo. See `hooks/README.md`.

When editing a plugin, keep three places in sync: the content files, the descriptions in `marketplace.json`, and the tables in the root `README.md`.

## File conventions

- **Agents** (`agents/*.md`): frontmatter `name`, `description`, `tools`, `model`. Two kinds: **review agents** (`code-reviewer`, `security-auditor`, `architect-reviewer`) are report-only — read-only tools (`Read`/`Grep`/`Glob`[/`Bash`]) and a description ending in "Returns actionable findings only." style scoping; **working agents** (`devops-engineer`, `sql-pro`, `pr`) carry `Write`/`Edit` and actually change files (`pr` also commits/pushes).
- **Commands** (`commands/*.md`): the body IS the prompt executed when the user runs `/<name>`.
- **Skills** (`skills/<name>/SKILL.md`): frontmatter `name` + `description`; the description's trigger conditions decide when the skill auto-activates, so write them precisely.

## Two distinct hook mechanisms

These do not interchange — wiring one as the other silently never fires:
- **Claude Code hooks** (in the `plugins/mhr-*` plugins) wire via `hooks/hooks.json`, `PreToolUse`/`PostToolUse`, can block a tool call.
- **Git pre-commit hooks** (in `hooks/`) wire into a git hook runner (lefthook / `.git/hooks`), scan the staged diff, `exit 1` to abort.

Some pairs enforce the same intent via both mechanisms (e.g. protected-branch commits) — install one, not both. See the "Overlaps" section in `hooks/README.md`.

Hook self-tests: `bash plugins/mhr-worktree/hooks/worktree-hooks.test.sh` (covers the worktree hooks only).

## Tooling assumptions baked into the prompts

The review/PR/build flows assume the *target* project uses **`just`** (`just lint`, `just build <pkg>`, `just test`, `just lint-fix`) and **`bun`**. `sql-pro` assumes **Drizzle ORM + Postgres**. These are assumptions about repos the tools run against, not about this repo.
