Ship all current changes to main via a pull request, fully automated: an agent panel reviews the diff, mechanical/clear-cut findings are fixed before shipping, the PR opens without waiting for you, CI is watched through to a resolved state (fixed automatically if it goes red, up to 2 attempts), and only then are any ambiguous findings surfaced to you in chat — held back so they don't distract from or block the ship.

---

## Phase 1: Review & auto-fix

### 1a. Gather changes

First run `git fetch origin main --quiet` **and wait for it to finish** — this refreshes `origin/main` so the diff base isn't stale. Do NOT fold it into the parallel batch below; the diffs must see the freshly-fetched ref.

Then run the rest in parallel:

- `git branch --show-current`
- `git status --porcelain`
- `git log origin/main..HEAD --oneline 2>/dev/null`
- `git diff origin/main`
- `git diff --name-only origin/main`
- `git diff --stat origin/main`

If `git diff origin/main` is empty **and** there are no untracked files, say "Nothing to ship." and stop.

### 1b. Determine review tier

**Build the full changed-files set:** tracked files from `git diff --name-only origin/main` **plus** untracked files (the `??` lines from `git status --porcelain`). Count source files and diff lines from this combined set. For untracked files, count their line count as the line delta. Untracked files are otherwise invisible to `git diff` — missing them would misclassify any PR that adds new files.

| Tier | Trigger | Agents |
|------|---------|--------|
| **Docs-only** | All changed files (tracked + untracked) are `.md`/`.yml`/`.yaml`/non-schema `.json` | R1 code-reviewer only |
| **Small** | ≤5 source files AND ≤200 diff lines | R1 code-reviewer + R2 history agent + R3 security-auditor (conditional — skip if the change touches no backend/API, database, or schema/validation code) |
| **Standard** | >5 source files OR >200 diff lines | R1 code-reviewer + R2 history agent + R3 security-auditor (conditional) + R4 architect-reviewer |

"Source files" = `.ts`/`.tsx`/`.js`/`.jsx`.

### 1c. Spawn review agents

**Emit all agent calls as a single parallel batch — multiple tool_use blocks in one message. Do not spawn one agent, wait for it, then spawn the next.**

All review agents (R1–R4) receive the same inputs:

- The full `git diff origin/main` output
- The combined list of changed file paths — tracked (from `git diff --name-only origin/main`) + untracked (the `??` paths from `git status --porcelain`), with untracked ones marked as `(untracked)` so the agent knows they're not in the diff

Do **not** include full file contents in the agent prompts — the agents have `Read` and can pull what they need. Untracked files' content is *only* visible via Read, so the agent must read them itself if a finding hinges on their content.

Tell R1, R3, R4: return actionable findings only, in the format defined in their agent file. If nothing to report, return `No findings.` and stop.

**R1 — code-reviewer** (all tiers): standard correctness review per the agent file.

**R2 — history agent** (Small + Standard tiers only): Use `subagent_type: general-purpose`. Task prompt:

> You are reviewing a working-tree diff against origin/main for potential regressions against prior deliberate work.
>
> For each changed file, run: `git log --follow -20 --format="%h %s%n%b" -- <file>` and `git blame -L <changed-line-range> -- <file>` on the regions the diff touches. Skip any file marked `(untracked)` — it has no git history to blame. Read commit messages to understand why code was written a particular way. Flag if the current diff appears to revert or contradict a deliberate prior fix — e.g. a commit that fixed a bug, added a guard, or hardened behaviour that this diff now removes or weakens.
>
> Return findings only where something concrete warrants flagging. If nothing to report, return `No findings.` and stop.

**R3 — security-auditor** (conditional — skip if the change touches no backend/API, database, or schema/validation code): standard security review per the agent file.

**R4 — architect-reviewer** (Standard tier only): standard architecture review per the agent file.

**Docs-only tier:** spawn only R1 (code-reviewer). Append to its prompt:

> This is a docs-only change. Skip code-correctness checks — they don't apply. Look for: internal inconsistencies (refs to sections/steps that no longer exist after a trim), stale cross-references (files, commands, agents, paths renamed or removed in this same diff), contradictions between docs that orchestrate each other (e.g. a command file and the agent files it spawns), broken instructions a future invocation would actually trip on (e.g. an agent told to return findings in a format the orchestrator no longer parses), accuracy of documented statuses (e.g. status markers in the project's spec/docs matching reality), and obvious typos in user-visible strings. Skip nitpicks about style or voice.

### 1d. Collect, score, deduplicate, triage

**Project-specific advisory pre-push checks.** If the project defines advisory pre-push checks (checks that print findings on push but do not block it), resolve any that apply to this change now rather than leaving them to print as a push-time reminder — you have this PR's full context (which the Phase 2 agent does not), so it's cheaper to fix them here. Treat anything ambiguous or non-mechanical as a **Surface** finding instead of guessing. If the project has no such checks, skip this step.

**Confidence scoring.** Once all spawned agents for this tier have returned, collect every finding they produced into a single numbered list (assign each an index as you collect them). Spawn one Haiku agent with the indexed list and ask it to score each finding on a 0–100 scale using this rubric (pass verbatim):

> Score each finding 0–100 for confidence that it is a real, actionable issue (not a false positive or pre-existing issue):
> - 0: False positive — doesn't survive light scrutiny, or flags a pre-existing issue not introduced by this diff.
> - 25: Might be real, hard to verify; if stylistic, not explicitly required by CLAUDE.md.
> - 50: Verifiably real but a nitpick or unlikely to matter in practice.
> - 75: Very likely real and will be hit in practice; existing approach is insufficient, or the issue is directly called out in CLAUDE.md.
> - 100: Definitely real and will occur frequently; evidence directly confirms it.
>
> Return a list of `<index>: <score>` pairs — one per line.

Map scores back by index. Apply scores with **asymmetric filtering** — the dividing line is high-stakes vs. low-stakes (never silently drop a high-stakes finding):

- **Score ≥ 60:** carry forward to triage normally.
- **Score < 60, low-stakes finding:** drop — treat as noise.
- **Score < 60, high-stakes finding (security, real performance impact, data-loss, destructive operation, user-facing contract change):** do NOT drop — route directly to **Surface** with a `(low confidence — verify)` annotation. This is an explicit exception to the Surface bucket's normal criteria below — low-confidence-but-high-stakes always surfaces, regardless of whether the finding also meets (a) or (b).

Findings from the project's advisory pre-push checks (above) are deterministic — skip scoring and carry them forward unchanged.

Merge surviving findings (passing the score filter + pre-check). Deduplicate overlaps. Sort each into one of four buckets:

- **Auto-fix** — purely mechanical: unused imports, dead code, obvious typos in strings/comments, stale references, naming nits, code-quality cleanups with no behavior change. Apply silently.
- **Fix-and-apply** — any finding with a clear, unambiguous fix: correctness bugs, missing error handling, broken logic, security issues with an obvious mitigation, performance issues with a clear solution, implementation choices where one option is clearly better. **Never defer or add a TODO — fix it now.** Apply the fix; include it in the Phase 2 PR summary. Rule of thumb: if you can write the correct fix from the code alone without asking the author, it belongs here.
- **Advisor-mediated** — findings where the right fix is unclear or has real trade-offs. Call `advisor()` with the finding and candidate fixes. If decisive, apply and note in the recap. If ambiguous, promote to **Surface**. (If `advisor` is unavailable, treat as **Surface**.)
- **Surface** — only when no reasonable call can be made from the code alone: (a) the change looks like it could be intentional (removing a guard, changing a default, narrowing an API) and you cannot tell from context; (b) the correct fix depends on business rules or external facts the code does not encode. Standard patterns, conventions, and best practices are yours to apply — do not surface something just because there are multiple valid approaches.

After applying auto-fix and fix-and-apply items, run `just lint-fix` to apply formatting (skip for docs-only). **Don't re-run build, tests, or the project's other hooks/checks here** — the project's pre-commit and pre-push hooks run them when the Phase 2 agent commits and pushes, and that agent fixes anything that fails. Re-running them here is redundant.

### 1e. Hold Surface items for later

Surface items no longer block or annotate PR creation — they aren't posted as PR comments. For each Surface finding, prepare a short chat payload to show the user **after CI resolves** (Phase 4):

- **Anchor:** `file:line` if the finding has one (from the reviewing agent's `- file: <path>:<line>` output), else none.
- **Body:** one-sentence summary of the ambiguity/intent question, plus 2–3 concrete options (order by recommendation, A first, "leave as-is" is a valid option). No line-by-line diff dumps — keep it tight.

Hold this list in memory for Phase 4 — do not pass it to the Phase 2 agent.

One-line summary of auto-fixes, fix-and-apply / advisor-mediated calls, and how many Surface items are being held for the end, then continue to 1f. Do not stop here — proceed straight to 1f and Phase 2.

### 1f. Doc status sync

After triage settles (1d/1e), sync status markers in tracking docs to reflect what this PR actually ships. Run **after** all code changes are settled so doc updates capture the final state.

Scope:
- The project's spec/docs if present (e.g. a `SPEC.md` or similar tracking doc with a Status column) — the status markers are the primary target. Walk the changed files and the PR's effective behavior; for each tracked item whose implementation moved, update its status accordingly:
  - Item fully implemented and exercised by this PR → mark Done.
  - Item partially advanced (some sub-requirements landed, others still missing) → mark Partially done, and append a short parenthetical note describing what's still missing (matching the doc's existing convention).
  - Item previously Done whose backing code is being removed → downgrade to match reality.
- Other docs with explicit status/progress markers (e.g. decision-log follow-up checklists, `todo.md` items that this PR completes) — tick or remove entries that are now done.

Rules:
- **Only touch status fields and checklist boxes.** Do not rewrite descriptions, reorder sections, add new items, or "tidy" prose. The pattern is the same as auto-fix: mechanical, no judgment calls about scope.
- Match existing conventions exactly (same status vocabulary, same checkbox style, same column width).
- If nothing in the changed files maps to a tracked item, or the project has no such tracking docs, skip this step silently.
- If a status change is genuinely ambiguous (partial work, unclear whether a sub-item counts as done), leave the doc alone and add a list entry of the form `<file> — <item>: skipped (<reason>)` to the Phase 2 "Doc status updates" list rather than guessing. This keeps the PR-body field uniformly a list (no separate skip-only recap).

Keep a short list of the doc edits made — applied (`file — item: old → new`) and skipped (`file — item: skipped (<reason>)`) — for the Phase 2 PR body.

---

## Phase 2: Create the PR

Spawn the `pr` agent with this prompt:

> Create a PR for all changes in the working tree (staged, unstaged, committed-ahead-of-main).
>
> **Hooks** (the project's git hooks, run automatically on commit/push, if configured): typically lint on changed files plus guards on commit, and build/tests on push. Some projects also run advisory-only checks that print findings without blocking the push.
>
> If commit and push succeed, the project's enforced hooks (lint, build, tests) all passed; any advisory checks may have printed findings without blocking. PR test plan should note "Verified by pre-push hooks: lint, build, tests" — don't ask the reviewer to re-run.
>
> **From this session:** automated review passed. Include the following in the PR body — substitute concrete content for each placeholder before spawning the agent:
> - **Auto-fixes:** [list or "none"]
> - **Fix-and-apply choices:** [list or "none"]
> - **Advisor-mediated calls:** [list or "none"]
> - **Doc status updates:** [list of `file — item: old → new` or `file — item: skipped (<reason>)` lines, or "none"]
>
> Lint verified.
>
> Once the PR is open, hand back — you do not post comments and you do not watch CI.

When the agent finishes:
- If "Nothing to ship.", relay it and stop.
- If something failed before PR creation, relay the error and stop.
- If response contains `PR_URL:`, report **"PR created"** + URL and a brief recap of fixes. Then continue to Phase 3 — watch CI yourself.

## Phase 3: Watch CI, dispatch fixes

You (the orchestrator) poll CI directly so progress is visible in this session — no silent multi-minute wait. Take the `PR_NUMBER` and `BRANCH` from the agent's return block.

Do **not** use `gh pr checks --watch` — it's a long-lived foreground call. Poll instead, as a sequence of short calls, and **emit a one-line status update after every single poll** (e.g. "CI still pending, checking again in ~25s" / "check `build` failed, dispatching a fix") — the whole point of this phase living here instead of in a subagent is that you narrate it instead of going silent.

1. Run `gh pr checks` and check its exit code: `0` = every check passed; `8` = checks still pending/running (including the moment right after PR creation, before CI has registered the run — expected, not a failure); any other non-zero = one or more checks failed.
2. On exit `8`: tell the user CI is still pending, then run a plain `sleep 25` Bash call, then repeat step 1. Cap total polling at **~20 minutes** of wall time. If still pending when the cap is hit, stop polling, note CI status as **unresolved**, and continue to Phase 4 — don't guess, don't keep polling past the cap.
3. On exit `0`: note CI as green and continue to Phase 4.
4. On a failing exit code: tell the user which check(s) failed, then pull the failing log yourself so you can narrate what broke:
   - `gh run list --branch <branch> --limit 1 --json databaseId -q '.[0].databaseId'`
   - `gh run view <run-id> --log-failed`
   - Summarize the failure to the user in one or two lines, then dispatch the `ci-fixer` agent, passing it: the branch name, PR number, which check(s) failed, and the log excerpt you just pulled.
   - When `ci-fixer` returns:
     - `FIX_STATUS: pushed` → tell the user a fix was pushed, then re-poll from step 1 against the new commit's checks.
     - `FIX_STATUS: flaky` → relay that the fixer judged this unrelated to the diff, and ask the user whether to re-run the job themselves (this session can't re-run CI directly). Continue to Phase 4.
     - `FIX_STATUS: stuck` → relay what the fixer found and why it couldn't fix it, note CI as red, and continue to Phase 4.
   - Cap fix dispatches at **2 attempts**. If still red after the 2nd dispatch, stop polling, summarize what both attempts tried and the remaining failure, and continue to Phase 4.

Never bypass a failing check yourself (no skipping, no disabling, no force-merge) — that rule applies to you as much as to the fixer.

## Phase 4: Surface held findings

CI is now resolved (green, red, or unresolved) and the PR is live either way. This is where the Surface findings held back in 1e finally show up — deliberately last, so they never block or delay the ship.

- If there are no Surface findings, say so briefly ("No ambiguous findings to review.") and stop — nothing else to do.
- Otherwise, present each Surface finding to the user in chat: its `file:line` anchor (if any), the one-sentence summary, and its options (A/B/C, "leave as-is" included). Ask the user which option they want for each, or whether to leave it as-is.
- This is a plain chat exchange, not a PR comment and not a gate — the PR already exists and CI has already been handled regardless of what the user decides here. Apply whatever the user picks as a follow-up if they want it done now; otherwise just leave it as their call to act on later.
