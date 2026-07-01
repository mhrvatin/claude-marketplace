You are surfacing **minor, bite-sized work items** the user can pick off in a single short session. Your job is to scan, filter, and present — **not** to implement anything. The user is the PM; you are showing them a menu.

---

## Sources to scan

1. **`todo.md`** at the repo root — all sections: Tech debt, Code TODOs, Deferred features.
2. **`docs/SPEC.md`** — every requirements table. A row is a candidate **only** if its `Status` is empty (not started) or begins with the word `Partially`. Any other status — including `Done`, `Superseded`, `Deprecated`, `N/A`, `Backend done`, `Planned`, or anything beginning with `Deferred` (with or without a parenthetical, and including the case where the row was previously `Partially` but has since been parked as `Deferred`) — is **out**. A row whose Status starts with `Deferred` is parked work; never re-surface it, even if a free-text note in the same cell mentions partial implementation.

Read both files in full before deciding. Do not skim.

---

## What counts as "minor"

A candidate qualifies if **all** of these are true:

- **Small surface area** — touches roughly 1–3 files of production code, or is a self-contained extension of an existing pattern that already lives in the codebase.
- **No new architecture** — no new data model, no new auth/permission concept, no new infrastructure, no new external dependency, no new long-running background job, no new package.
- **No migration risk** — either no DB change at all, or a strictly additive change (new nullable column, new index, new table) that the current `CLAUDE.md` production-data rules already permit.
- **No spec ambiguity** — the requirement or TODO is concrete enough that you would not need to run `/interview` to clarify before starting. If the item would need a round of UX/copy questions, it is **not** minor.
- **No blocking dependency** — the item does not say "depends on X", "blocked on Y", "after Z ships", or "needs upstream fix". The bun `mock.module` collapse, PEN-62 (depends on PEN-7), and similar are **out**.
- **Bounded scope in the wording itself** — e.g., "wire an unused column", "apply existing pattern to remaining files", "add rate limiter to these two endpoints", "add a missing factory", "fix this one inline TODO". Anything that reads as a whole new feature area is **out**, even if individually each requirement is short.

Aggressively reject anything that fails even one criterion. The bar is *small and obvious*, not *technically possible in a day*.

---

## Common shapes that almost always fail the bar

These are heuristics, not blanket bans — re-evaluate each item on its own against the criteria above. A pension item could become minor if a future row is, say, "expose constant X in the admin panel". But by default, expect items of these shapes to fail:

- Items that introduce a new modeling assumption, formula, or domain concept (e.g., most net-new pension calculations, new tax-rule structures, new goal-projection math).
- Items that expand a permission/ownership model (e.g., new sharing semantics, new role).
- Refactors the TODO itself describes as cross-cutting ("still duplicated across ~14 test files", "applies to every route").
- Spec rows that read as a feature area rather than a tweak, especially when the row has no implementation hint and would need design/copy questions answered first.
- "Deferred features" entries — usually large by definition. Only include one if it is *visibly* a single isolated UI/behavior tweak.

If an item of one of these shapes still passes every criterion in the section above, include it — the criteria win.

---

## Output format

Present **3–6 candidates max** as a numbered list. Fewer is better than padding the list. Each entry is **one line**: a short bold title, an em dash, and a single-sentence summary of what the change entails. Nothing else — no source, no file list, no TDD note, no open question. Detail is reserved for expansion-on-request.

Even though the user-facing list is terse, you SHALL internally vet each candidate against every "minor" criterion above — including being able to name a TDD entry point and having at most one open question. If you cannot, drop the item. The terse format does not lower the bar; it only hides the work.

Example:

```
1. **Rate limiting on admin invite endpoints** — add a dedicated `adminInviteRateLimiter` to `POST /api/invites` and `DELETE /api/invites/current`, mirroring the existing `authRateLimiter` pattern.
2. **Factory overrides → `Partial<T>` type safety** — tighten `Record<string, unknown>` overrides on `makeAccount`, `makeBudgetItem`, `makeChild`, `makeIncomeEntry` to proper entity types.
3. **OPS-6: real `/health` check** — replace the always-200 handler with a DB ping that returns `503 {"status":"error"}` on failure.
```

After the list, end with a single line:

> Pick one or more by number (e.g. "let's do 2 and 4") and I'll expand each with source, files likely touched, TDD entry point, and any open questions before starting `/test-driven-development`. Or say "none of these" and I'll re-scan.

When the user replies with a selection, expand **only** the picked items into the full block — Source, What, Why it's minor, Files likely touched, TDD entry point, Open question if any — and wait for confirmation before writing any code. Do not expand items the user did not pick.

Do **not** start implementing. Do **not** write code. Do **not** open files beyond the two sources unless you genuinely need to confirm a path exists before listing it. Do **not** create a branch.

---

## Tone

Be terse. No preamble like "Here are some candidates I found…". Just go straight into the candidate blocks. The user reads fast.

If `todo.md` and `docs/SPEC.md` together yield zero items that pass the bar, say so in one sentence and stop — do not lower the bar to fill the list.
