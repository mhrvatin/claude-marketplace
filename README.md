# mhrvatin marketplace

A personal Claude Code marketplace — commands, agents, and skills usable across any project.

## Install

```bash
claude plugin marketplace add /path/to/this/checkout
claude plugin install mhrvatin-tools@mhrvatin
```

## Contents (`mhrvatin-tools`)

| Type | Name | Notes |
|------|------|-------|
| command | `pr` | Sizes the diff into a tier, fans out review agents, scores findings, applies fixes, then spawns the `pr` agent to commit/push/open the PR. |
| command | `interview` | Requirements-interviewer that writes a spec section (assumes a `docs/SPEC.md`-style spec if present). |
| command | `todo-minor` | Surfaces minor, bite-sized work items. |
| agent | `code-reviewer` | Correctness/edge-case/test review. |
| agent | `security-auditor` | Injection, auth, secrets, validation, deps. |
| agent | `architect-reviewer` | Boundaries, coupling, API/data-flow alignment. |
| agent | `sql-pro` | SQL/Postgres + Drizzle ORM review. |
| agent | `devops-engineer` | CI/CD, containerization, infra. |
| agent | `pr` | Commits, branches, pushes, and opens the PR to the default branch; spawned by the `pr` command. |
| skill | `test-driven-development` | TDD discipline + supporting refs. |

(The `pr` command also spawns a `pr` agent that commits, pushes, and opens the PR to the default branch.)

## Hooks (`hooks/`)

A library of opt-in hook scripts (secrets/`git add`/force-push guards, worktree
isolation, dep/Actions pinning, destructive-migration blocking). They're **not**
wired into this repo or bundled into the plugin — copy a script into a target repo
and add the wiring snippet. See [`hooks/README.md`](hooks/README.md), which splits
them into Claude Code hooks (`settings.json`) vs. git pre-commit hooks.

## Assumptions

Two tooling assumptions are baked into the review/build/PR flows:

- **`just`** — recipes like `just lint`, `just build <package>`, `just test`, `just lint-fix`. Projects without a `justfile` will need these adapted.
- **`bun`** — dependency-pinning guidance references `bun add -E`.

`sql-pro` additionally assumes **Drizzle ORM + Postgres** (that's its domain). Everything else (project name, package layout, UI language, spec/hook specifics) is generalized to "the project" / "if present".
