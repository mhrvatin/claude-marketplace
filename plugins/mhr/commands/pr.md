Ship all current changes to main via a pull request — but only after a full automated review passes.

This command runs a review gate first. If there are findings that need your input, the PR is **not** created — you'll see the findings and can decide what to do. Auto-fixable issues are applied before shipping.

---

## Phase 1: Review gate

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
- **Score < 60, high-stakes finding (security, real performance impact, data-loss, destructive operation, user-facing contract change):** do NOT drop — route directly to **Surface** with a `(low confidence — verify)` annotation.

Findings from the project's advisory pre-push checks (above) are deterministic — skip scoring and carry them forward unchanged.

Merge surviving findings (passing the score filter + pre-check). Deduplicate overlaps. Sort each into one of four buckets:

- **Auto-fix** — purely mechanical: unused imports, dead code, obvious typos in strings/comments, stale references, naming nits, code-quality cleanups with no behavior change. Apply silently. **Never** auto-fix anything that changes runtime behavior, validation, or logic.
- **Decide-and-apply** — implementation choices where one option is clearly better and the wrong one wouldn't cause a real problem (refactor shape, library/style choice, scope-creep nits, idiomatic restructuring). Pick the better option, apply it, list it in the Phase 2 PR summary so the user has an audit trail.
- **Advisor-mediated** — non-obvious correctness calls where the right fix is ambiguous, *but the impact is not security / perf / data / user-facing contract*. Call `advisor()` with the finding and candidate fixes. If the advisor is decisive, apply and note in the recap. If the advisor is ambiguous or flags real uncertainty, promote to **Surface**. Use discretion on when to call — skip for findings where you're already confident. (Requires the `advisor` tool in this session; if not available, treat advisor-mediated findings as **Surface**.)
- **Surface** — always escalate to the user: security impact, real performance impact (latency, memory, query count, bundle size), data-loss risk, destructive operations, user-facing contract changes, anything the advisor flagged as ambiguous.

After applying auto-fix and decide-and-apply items, run `just lint-fix` to apply formatting (skip for docs-only). **Don't re-run build, tests, or the project's other hooks/checks here** — the project's pre-commit and pre-push hooks run them when the Phase 2 agent commits and pushes, and that agent fixes anything that fails. Re-running them here is redundant.

### 1e. Gate decision

**If any Surface items exist:**

Stop. Do NOT proceed to Phase 2 yet. Report concisely — one step back from the code, no file paths or function names, no line-by-line. For frontend findings especially, describe what the user sees or what risk it carries, not implementation mechanics. Keep each finding to 2–3 options. Order options by what you'd recommend (A first); when "do nothing / accept as-is" is a real option, include it.

Format:

> ### Review needs your input
>
> **Applied automatically:** one short line — or omit if nothing was applied.
>
> **Findings to decide:**
>
> **F1 — \<short title, ~6 words\>** *(security | perf | data | correctness | UX)*
> One-sentence overview. No jargon unless unavoidable.
> - **A.** \<option, one short line\>
> - **B.** \<option, one short line\>
> - **C.** \<option, one short line — often "leave as-is"\>
>
> **F2 — …** *(same format)*
>
> Reply with your picks (e.g. `F1: B, F2: A`) and I'll apply them and finish the PR — you don't need to re-run `/pr`.

When the user replies with picks, apply them, re-run lint/build per 1d, then continue to Phase 2. Do not re-gate the same findings.

**Otherwise (no Surface items):** one-line summary of auto-fixes and any decide-and-apply / advisor-mediated calls, then continue to 1f.

### 1f. Doc status sync

After the gate passes (and after any Surface picks are applied), sync status markers in tracking docs to reflect what this PR actually ships. Run **after** all code changes are settled so doc updates capture the final state.

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
> - **Decide-and-apply choices:** [list or "none"]
> - **Advisor-mediated calls:** [list or "none"]
> - **User picks at gate:** [list or "none"]
> - **Doc status updates:** [list of `file — item: old → new` or `file — item: skipped (<reason>)` lines, or "none"]
>
> Lint verified.

When the agent finishes:
- If response contains `PR_URL:`, reply with **"PR created"** + URL + brief recap of fixes.
- If "Nothing to ship.", relay it.
- If something failed, relay the error.
