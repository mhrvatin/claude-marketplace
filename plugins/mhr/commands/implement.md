Implement a GitHub issue end to end and hand it to `/mhr:pr`, with no plan check-in and no "here's what I'm about to do" pause. The issue is the agreed plan — everything in `to-tickets`/`/mhr:interview` already happened before this issue existed. This command's job is to turn it into a green, reviewed, open PR without further prompting, and to stop only when genuinely blocked.

> $ARGUMENTS

---

## 1. Resolve and claim the issue

- Parse `$ARGUMENTS` as an issue URL, `owner/repo#N`, or a bare number against the current repo. If no argument was given, stop and ask which issue to work.
- `gh issue view <ref> --json title,body,state,assignees,comments,blockedBy`.
- If the issue is closed, or already assigned to someone/something else, stop and report — do not barge in on it.
- Claim it: `gh issue edit <ref> --add-assignee @me`, so a concurrent session (another cmux pane, another agent) skips it.

## 2. Isolate

Call `EnterWorktree` before any `Write`/`Edit` — unconditionally. Do this even if it looks unnecessary; the project's worktree-isolation hook blocks file edits outside one anyway, so skipping this step just fails later.

## 3. Read context

- The issue body and comments are the spec for this slice of work.
- Read the project's own `CLAUDE.md` for where its spec/architecture docs and test/build commands live (e.g. `docs/SPEC.md`, `docs/ARCHITECTURE.md`, `just` recipes). Read only the section(s) the issue actually references — don't re-read an entire spec doc for one ticket.
- Check `blockedBy` from step 1's fetch. For each blocker, `gh issue view <blocker> --json state` — if any is still `OPEN`, stop and report. Don't implement around a dependency that isn't there yet.

Post a short comment on the issue stating your planned approach in a sentence or two — informational, not a request for approval. It gives the user a way to redirect if they see it before the PR lands, without you waiting on a reply.

## 4. Implement

Follow the project's TDD discipline if it has one (e.g. `test-driven-development`) for its *mechanics* — vertical slices, one tracer-bullet test at a time, red before green, minimal code per cycle. Skip its interactive planning checkpoints ("confirm with user what interface/behaviors to test") — the issue body is already the confirmed plan; re-asking here reintroduces the exact back-and-forth this command exists to remove. If the project has no TDD skill, default to the same discipline anyway.

Take the sane, defensive option whenever the issue leaves a genuine implementation-level choice open (naming, error handling, edge cases) — don't stop to ask about these, decide and move on. Only stop (see "When to stop" below) if the issue's actual requirement is ambiguous or contradicts what you find in the codebase — that's a blocker, not a detail.

## 5. Verify

Run the project's own check/test commands (from its `CLAUDE.md` — e.g. `just check` / `just test` / `just test-integration`). If the change touches UI and the project has a way to drive/screenshot it (e.g. a `run`-style skill), use it before calling this done — a green test suite proves correctness, not that the feature works.

Do not proceed to step 6 until everything is green.

## 6. Ship it

Invoke `/mhr:pr` — it reviews the diff, fixes mechanical findings, commits, pushes, and opens the PR (its Phase 2), then watches CI to a resolved state and, only if there are ambiguous findings, pauses to ask about them in chat (its Phases 3–4). Do not re-implement any of that here.

As soon as Phase 2 reports "PR created" with a URL and number — before Phase 3/4 run — link the issue so merging the PR closes it:

```bash
gh pr edit <PR_NUMBER> --body "$(gh pr view <PR_NUMBER> --json body -q .body)

Fixes #<issue-number>"
```

Then let `/mhr:pr` continue through Phase 3 (CI watch, capped ~20 min) and Phase 4 (only if Surface findings exist, which pauses for your input — that's the one point in this whole command where a human decision is genuinely expected, not a defect).

## 7. Report

One message: the PR link, plus CI's final state — green, red, or unresolved (don't report "shipped" if CI didn't actually pass). Nothing else — the user tests and merges from here.

## When to stop instead of guessing

- The issue is closed or already claimed (step 1).
- A referenced blocking ticket is still open (step 3).
- The issue's requirement is genuinely ambiguous or conflicts with the current codebase — not a detail you could reasonably decide defensively.
- Tests won't go green after a reasonably focused effort.

In every case: stop, release the claim if you haven't shipped (`gh issue edit <ref> --remove-assignee @me`), and report the blocker plus what you'd need to proceed, in one message. Once a PR is open, leave the assignment in place as the record of who's on it — don't release it in step 6/7.
