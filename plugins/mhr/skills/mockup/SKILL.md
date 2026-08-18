---
name: mockup
description: >
  Use when the user asks to mock up, prototype, propose a new layout for,
  redesign, or show options for a specific part of an existing UI/view —
  e.g. "mock up a new layout for these buttons", "I want a high-fidelity
  mockup of...", "redesign the rating widget", "show me an alternative for
  this card" — based on a screenshot or an existing screen. Locks in the
  current design system (colors, typography, spacing, icons, copy,
  unrelated elements) and changes only what was explicitly named. Do NOT
  use for greenfield design with no existing reference, or for a full
  redesign where the user wants a genuinely different visual world.
---

# Mockup (Constrained Redesign)

## Philosophy

A mockup answers "what if this one piece looked different" — not "what if
this whole screen were reinvented." The existing screen is ground truth.
Anything not explicitly named stays byte-for-byte: same colors, same font,
same spacing scale, same icons, same copy, same unrelated components. A
green "Middag" tag stays that exact green, that shape, that label — even
though nobody asked about it.

## Workflow

### 1. Establish ground truth

- If the project's source is available, read the actual tokens (theme file,
  CSS variables, Tailwind config, component library) — don't approximate
  colors or spacing from a screenshot when the real values are one grep
  away.
- If only a screenshot exists, extract concretely from the image: read off
  the actual colors, note the real font characteristics (serif vs sans,
  weight, size relationships), measure the real spacing relationships. Do
  not substitute "typical app" defaults — Material blue, system fonts, an
  8px grid — for what the image actually shows.

### 2. Scope the change

List it explicitly, in two columns:

- **Change** — only what the user named.
- **Preserve** — everything else, named concretely (each label, tag, icon,
  spacing relationship, color, and the copy's language).

If the ask is ambiguous about how far the change extends (e.g. "new layout
for the rating" — does the favorite star move too?), ask rather than guess.

### 3. Absolute constraints

- [ ] No new colors outside the extracted palette
- [ ] No new fonts or weights outside what's already used
- [ ] No new spacing or radius values outside the existing scale
- [ ] Copy and language untouched — don't translate, rephrase, or "improve"
      text outside the Change list
- [ ] Nothing outside the Change list is removed, recolored, resized, or
      relabeled
- [ ] The changed element follows existing interaction patterns for its
      type (if buttons elsewhere are pill-shaped outline, a new button
      stays pill-shaped outline)

### 4. Build it

Produce the mockup at native fidelity — real code/CSS using the extracted
tokens, not a fresh interpretation. Prefer a self-contained artifact (HTML/
CSS, or the project's actual component) that mirrors the original 1:1
outside the changed region, rendered so it's directly comparable to the
source screenshot. Show multiple options only if the user asked for
options; one faithful mockup beats three divergent ones.

### 5. Self-check before presenting

Diff the output against the original, element by element. Anything on the
Preserve list that looks different is a bug — fix it before showing the
user. State plainly what changed and what was preserved, so the user can
confirm the constraint held without re-deriving the diff themselves.

## Checklist

```
[ ] Ground truth pulled from source or measured from the image, not assumed
[ ] Change/Preserve scope confirmed or reasonably inferred
[ ] No new colors, fonts, spacing, or icons introduced
[ ] Unrelated elements (tags, labels, copy) untouched
[ ] Output states what changed vs preserved
```
