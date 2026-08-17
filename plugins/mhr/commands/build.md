Take a spec or decision that `/mhr:interview` already finished — this session, or a doc reference you pass in — all the way to open PR(s). Chains `/mhr:to-tickets` then `/mhr:implement` over every immediately-ready ticket. This command does not interview you itself: a raw, ungrilled idea needs a human answering rounds of questions, which nothing here can do on your behalf.

> $ARGUMENTS

---

## 1. Check there's something to build

- If `$ARGUMENTS` is empty, use the spec/decisions finalized earlier in this session's `/mhr:interview` run, if there was one.
- If `$ARGUMENTS` references a doc, section, or ID range, use that instead (same input shape `/mhr:to-tickets` itself accepts). To implement an already-filed issue directly, skip this command and use `/mhr:implement <issue>` — that's not what `build` is for.
- If neither exists — no interview finished in this session and no reference given — stop and tell the user to run `/mhr:interview` first, or pass a reference. Do not attempt to grill them yourself.

## 2. Ticket it

Invoke `/mhr:to-tickets` on the source from step 1. It confirms the breakdown with the user once, then publishes the tickets to GitHub with their blocking edges wired. Do not replicate any of that logic here — just hand off and take its reported list of filed tickets (ready vs. blocked) back.

## 3. Implement the ready frontier

For every ticket `/mhr:to-tickets` just filed with **no open blockers**, invoke `/mhr:implement <ticket>` — one at a time. Each run goes all the way through `/mhr:implement`'s own invocation of `/mhr:pr`, including CI watch (capped ~20 min) — this is genuinely sequential, not fire-and-forget, so a multi-ticket batch takes roughly that long per ticket. If a ticket's review turns up a Surface finding, `/mhr:pr` will pause for your input before that ticket's slot finishes — that's expected, not a bug: it's the one point in the whole pipeline where a human call is genuinely required, and it only happens on the ambiguous cases by construction. Exit the worktree (`ExitWorktree`, keep — the branch a PR was just opened from) once a ticket's run reaches a conclusion, before entering a new one for the next ticket.

If a given ticket's `/mhr:implement` run stops on a blocker or on red/unresolved CI (per that command's own "when to stop" rules and its report), note it and continue to the next ready ticket rather than aborting the whole batch.

Tickets that came back blocked from step 2 are left untouched — they aren't ready, and forcing them isn't this command's job. They become implementable on a later `/mhr:build` or `/mhr:implement` call once their blockers merge and close.

To run several ready tickets concurrently instead of sequentially (e.g. across separate cmux panes), invoke `/mhr:implement <ticket>` directly, per ticket, in each pane — that's a manual choice outside this command's single-session default.

## 4. Report

One message: the tickets filed (with links); which got a PR opened (with links and each one's CI state — green, red, or unresolved); which stopped on a blocker (with what blocked them); and which are still waiting on another ticket in the same batch. Nothing else.
