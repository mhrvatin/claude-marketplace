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
| command | `pr` | Sizes the diff into a tier, fans out review agents, scores findings, applies fixes, then spawns the `pr` agent to commit/push/open the PR without waiting for input. |
| command | `interview` | Requirements-interviewer that writes a spec section (assumes a `docs/SPEC.md`-style spec if present). |
| command | `todo-minor` | Surfaces minor, bite-sized work items. |
| agent | `code-reviewer` | Correctness/edge-case/test review. |
| agent | `security-auditor` | Injection, auth, secrets, validation, deps. |
| agent | `architect-reviewer` | Boundaries, coupling, API/data-flow alignment. |
| agent | `sql-pro` | SQL/Postgres + Drizzle ORM review. |
| agent | `devops-engineer` | CI/CD, containerization, infra. |
| agent | `pr` | Commits, branches, pushes, opens the PR, posts ambiguous review findings as PR comments, and watches CI to resolution (auto-fixing red checks, up to 2 attempts); spawned by the `pr` command. |
| skill | `test-driven-development` | TDD discipline + supporting refs. |

(The `pr` command also spawns a `pr` agent that commits, pushes, opens the PR, posts findings as comments, and watches CI to resolution.)

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
