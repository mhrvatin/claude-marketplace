# mhrvatin marketplace

A personal Claude Code marketplace — commands, agents, and skills usable across any project.

## Install

```bash
claude plugin marketplace add /path/to/this/checkout
claude plugin install mhr@mhrvatin
```

## Contents (`mhr`)

| Type | Name | Notes |
|------|------|-------|
| command | `pr` | Sizes the diff into a tier, fans out review agents, scores findings, applies fixes, spawns the `pr` agent to commit/push/open the PR without waiting for input, polls CI itself and dispatches the `ci-fixer` agent (up to 2 attempts) if it goes red, then surfaces any ambiguous findings in chat last. |
| command | `interview` | Requirements-interviewer that writes a spec section (assumes a `docs/SPEC.md`-style spec if present). |
| command | `todo-minor` | Surfaces minor, bite-sized work items. |
| agent | `code-reviewer` | Correctness/edge-case/test review. |
| agent | `security-auditor` | Injection, auth, secrets, validation, deps. |
| agent | `architect-reviewer` | Boundaries, coupling, API/data-flow alignment. |
| agent | `sql-pro` | SQL/Postgres + Drizzle ORM review. |
| agent | `devops-engineer` | CI/CD, containerization, infra. |
| agent | `pr` | Commits, branches, pushes, and opens the PR; spawned by the `pr` command, which then watches CI itself and surfaces ambiguous findings in chat once CI resolves. |
| agent | `ci-fixer` | Diagnoses and fixes a red CI check on the current branch, pushes a new commit; spawned by the `pr` command's own CI poll loop when a check fails. |
| skill | `test-driven-development` | TDD discipline + supporting refs. |

(The `pr` command spawns a `pr` agent that just commits, pushes, and opens the PR, then polls CI itself in the main session, dispatches a `ci-fixer` agent to fix any red checks, and only afterward surfaces ambiguous review findings in chat for you to decide on.)

## Hooks

Claude Code hooks (`PreToolUse`/`PostToolUse`) are installable as themed plugins —
opt into a theme instead of every hook at once:

```bash
claude plugin install mhr-guardrails@mhrvatin   # command-safety guards
claude plugin install mhr-worktree@mhrvatin     # worktree isolation workflow
claude plugin install mhr-pinning@mhrvatin      # dependency/Actions pinning
```

Git pre-commit hooks (secrets/destructive-migration/`node_modules` blocking) have
no plugin delivery mechanism — they're a copy-paste library in `hooks/`, wired into
a target repo's lefthook/`.git/hooks`. See [`hooks/README.md`](hooks/README.md).

## Assumptions

Two tooling assumptions are baked into the review/build/PR flows:

- **`just`** — recipes like `just lint`, `just build <package>`, `just test`, `just lint-fix`. Projects without a `justfile` will need these adapted.
- **`bun`** — dependency-pinning guidance references `bun add -E`.

`sql-pro` additionally assumes **Drizzle ORM + Postgres** (that's its domain). Everything else (project name, package layout, UI language, spec/hook specifics) is generalized to "the project" / "if present".
