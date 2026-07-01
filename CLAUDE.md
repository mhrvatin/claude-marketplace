# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal Claude Code **marketplace** — a static distribution of commands, agents, and skills. There is no build, test, or lint step; the "code" is Markdown prompts plus shell/Python hook scripts. Changes are validated by installing and running them, not by a test suite.

## Layout

- `.claude-plugin/marketplace.json` — marketplace manifest. Lists plugins and their `source` paths. Edit when adding/removing a plugin.
- `plugins/mhrvatin-tools/` — the one plugin. Its `.claude-plugin/plugin.json` is the plugin manifest; `commands/`, `agents/`, and `skills/` hold the actual content (each a Markdown file with YAML frontmatter; skills are directories containing `SKILL.md` plus reference `.md` files).
- `hooks/` — a **standalone library** of opt-in hook scripts. Deliberately NOT bundled into the plugin and NOT wired into this repo (a plugin's hooks install all-or-nothing, which defeats per-hook opt-in). Consumed by copying a script into a target repo. See `hooks/README.md`.

When editing the plugin, keep three places in sync: the content files, the descriptions in `marketplace.json`, and the tables in the root `README.md`.

## File conventions

- **Agents** (`agents/*.md`): frontmatter `name`, `description`, `tools`, `model`. Two kinds: **review agents** (`code-reviewer`, `security-auditor`, `architect-reviewer`) are report-only — read-only tools (`Read`/`Grep`/`Glob`[/`Bash`]) and a description ending in "Returns actionable findings only." style scoping; **working agents** (`devops-engineer`, `sql-pro`, `pr`) carry `Write`/`Edit` and actually change files (`pr` also commits/pushes).
- **Commands** (`commands/*.md`): the body IS the prompt executed when the user runs `/<name>`.
- **Skills** (`skills/<name>/SKILL.md`): frontmatter `name` + `description`; the description's trigger conditions decide when the skill auto-activates, so write them precisely.

## Two distinct hook mechanisms in `hooks/`

These do not interchange — wiring one as the other silently never fires:
- **Claude Code hooks** wire into `settings.json` (`PreToolUse`/`PostToolUse`, can block a tool call).
- **Git pre-commit hooks** wire into a git hook runner (lefthook / `.git/hooks`), scan the staged diff, `exit 1` to abort.

Some pairs enforce the same intent via both mechanisms (e.g. protected-branch commits, broad `git add`) — install one, not both. See the "Overlaps" section in `hooks/README.md`.

Hook self-tests: `bash hooks/worktree-hooks.test.sh` (covers the worktree hooks only).

## Tooling assumptions baked into the prompts

The review/PR/build flows assume the *target* project uses **`just`** (`just lint`, `just build <pkg>`, `just test`, `just lint-fix`) and **`bun`**. `sql-pro` assumes **Drizzle ORM + Postgres**. These are assumptions about repos the tools run against, not about this repo.
