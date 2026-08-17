Break a spec section, a decision just recorded, or the current conversation into vertical-slice GitHub issues, wire their blocking edges with the tracker's native relationship, and mark them `ready-for-agent`. Confirms the breakdown with the user once, then publishes — this command does not implement anything itself, and `/mhr:implement` doesn't require the label either (a hand-filed issue works too); it's a convention for anything building a backlog view on top, not an enforced gate.

> $ARGUMENTS

---

## 1. Gather the source

- If `$ARGUMENTS` references a doc, section, or ID range, read it in full.
- If `$ARGUMENTS` is empty and a spec/decision was just finalized earlier in this conversation (e.g. an `/mhr:interview` session that just wrapped), use that.
- If neither applies, stop and ask what to break down — don't guess a scope.

## 2. Explore the codebase, as needed

Understand the current state near the change so ticket titles and descriptions use the project's own vocabulary and respect its ADRs. Look for prefactoring opportunities — "make the change easy, then make the easy change." Any needed prefactor becomes its own ticket, sequenced first.

## 3. Draft vertical slices

Break the work into tracer-bullet tickets:

- Each slice cuts a narrow but **complete** path through every layer it touches (schema, API, UI, tests) — vertical, not a horizontal slice of one layer.
- A completed slice is demoable or verifiable on its own.
- Each slice is sized to fit inside a single `/mhr:implement` run (one fresh context window).

**Wide, mechanical refactors are the exception.** A wide refactor — rename a column, retype a shared symbol — has a blast radius that fans across the whole codebase; no vertical slice can land green for it. Sequence it instead as expand (add the new form beside the old, nothing breaks) → migrate in batches sized by blast radius, each its own ticket blocked by the expand → contract (delete the old form, blocked by every migrate batch).

Give each ticket its blocking edges — the other tickets that must land first. A ticket with no blockers can start immediately.

## 4. Confirm with the user — once

Present the proposed breakdown as a numbered list, one entry per ticket: title, blocked by (or "none"), what it delivers end-to-end. Ask whether the granularity and blocking edges look right, and iterate until approved. This is the only interactive step in this command — do not add others.

## 5. Publish to GitHub

Ensure the label exists first — `gh issue create --label` does not auto-create it, and will fail on a repo where it's never been used before:

```bash
gh label create ready-for-agent --color 0E8A16 --description "Filed by /mhr:to-tickets, ready for /mhr:implement" 2>/dev/null || true
```

Then create the issues **in dependency order** (blockers first, so blocking edges can reference real issue numbers):

```bash
gh issue create --title "<title>" --body "<body>" --label ready-for-agent
```

- **Title:** if the source doc uses an ID scheme (e.g. `SPEC.md`-style requirement IDs), lead with the ID(s) this ticket covers — `AUTH-9: recovery invite for lost passkeys` — so the join key between doc and tracker survives. Otherwise a short descriptive title.
- **Body template:**

  ```markdown
  ## What to build

  <the end-to-end behaviour this ticket makes work, from the user's perspective — not a layer-by-layer implementation list>

  ## Acceptance criteria

  - [ ] <criterion>

  ## Spec reference

  <doc path + section/IDs this ticket implements, if applicable>
  ```

  Avoid file paths or code snippets in the body — they go stale. Exception: a decision that's more precisely a type shape, schema, or state machine than prose can inline it briefly.

Once every ticket exists, wire blocking edges in a second pass:

```bash
gh issue edit <ticket> --add-blocked-by <blocker>
```

(one call per blocking edge; `gh issue edit` also takes `--add-blocking` if it reads better from the other ticket's side — pick one direction per edge, don't set both).

## 6. Report

One message: the tickets filed, in dependency order, each as `#<n> <title>` with its link — grouped into **ready now** (no open blockers) and **blocked** (waiting on another ticket in this batch). Nothing else — publishing is the deliverable here, not implementing.
