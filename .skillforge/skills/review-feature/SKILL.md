---
name: review-feature
type: skill
tags: [documentation, specs]
description: Use when reviewing or judging an existing feature spec under `docs/features/proposed/F-XXX-*/` (or `implemented/`) for content quality and structural conformance, before accepting it for implementation. Read-only by default; offers to fix issues on request.
argument-hint: "[feature title or path to docs/features/proposed/F-XXX-*/]"
version: 1.1.0
compatibility: [copilot, claude]
---

## Overview

Reviews an existing feature spec (`feature.md` + `stories/` + `use-cases/`) and
reports per-criterion verdicts against the rubric in `references/rubric.md` —
covering both **content quality** (title shape, description pattern, scope balance,
acceptance-criterion testability, main-flow concreteness, cross-reference coverage,
origin provenance, reference formatting) and **structural conformance** (required
sections, ID format, index-matches-files, resolvable cross-references). It then
offers to fix the failures in place.

This is the quality gate between drafting a spec and accepting it for
implementation. It does not draft new specs — it judges specs that already exist.

Part of the feature-spec lifecycle: see
`../refine-feature/references/lifecycle.md` for the full workflow map and redirect
rules.

## When to use

- The user wants a spec under `docs/features/proposed/F-XXX-*/` reviewed or judged
  before accepting it for implementation.
- The user wants a second-pass quality check after `refine-feature` has drafted a
  spec.
- The user wants to assess an already-shipped spec under
  `docs/features/implemented/F-XXX-*/` (read-only review).

When NOT to use (redirect instead):

- The spec does not exist yet (brand-new feature) → use `refine-feature`, which
  creates the folder and drafts the spec.
- The spec exists but still needs drafting / iteration (missing stories, use cases,
  or sections) → use `refine-feature`. Use `review-feature` to *judge* a drafted
  spec, not to author one.
- A review of an `implemented/` spec surfaces changes the user wants to make → the
  fixes are not edits to the implemented spec; route to `change-feature` (only
  `reconcile-feature` writes to `implemented/`). `review-feature` may still apply
  fixes in place for a `proposed/` spec.

## Procedure

**Resolve the spec path.** The user provides a feature title or a path as
`$ARGUMENT`. If neither is given, ask for the feature title or path. Resolve it to
a feature folder under `docs/features/proposed/F-XXX-*/` or
`docs/features/implemented/F-XXX-*/`. The folder must contain at least a
`feature.md`; if `stories/` or `use-cases/` is absent, proceed and let the coverage
criteria note the gap. If the title matches no folder, list the candidates and ask.

**Load the rubric.** Read `references/rubric.md` — it holds the content criteria
and the structural criteria, each with a stable `id`, rule, and pass condition.

**Read the spec files** in full:

- `feature.md`
- every `stories/US-XXX-*.md` (alphabetical)
- every `use-cases/UC-XXX-*.md` (alphabetical)

**Run the structural pass.** Check each structural criterion against the shipped
conventions and templates — `../refine-feature/references/conventions.md`,
`../refine-feature/references/feature.md`, `../refine-feature/references/user-story.md`,
`../refine-feature/references/use-case.md`. These are mechanical checks: section
presence, ID zero-padding, `## Stories` index ↔ `stories/` files, story
`## Use cases` ↔ `use-cases/` files, reference-link and backtick formatting,
`## Origin` presence. The git-dependent `filename_slug_immutable` check is
best-effort — skip it silently when history is unavailable.

**Run the content pass.** Judge each content criterion against its rule and
pass condition. Be strict but fair: a criterion passes only when you can verify the
pass condition from the spec text. Do not manufacture failures over stylistic
preference, and do not pass on benefit-of-the-doubt — if you cannot verify a pass
condition, mark fail and cite what you needed and could not find.

**Present the verdict table.** Show one row per criterion:

| Criterion | Verdict | Reason |
| --- | --- | --- |
| `feature_title_shape` | pass / **fail** | ≤2 sentences; cite the specific text |

Group the table into Content and Structural sections, and end with a summary line:
`X/Y criteria pass`. For each fail, give a concrete pointer to the offending text
and what would make it pass.

**Offer to fix inline.** After presenting verdicts, ask whether to fix the
failures. This is the only step that writes files — nothing is written before the
user accepts. When the user accepts:

- For a spec under `proposed/`: apply the fixes directly, following the drafting
  rules in `../refine-feature/references/spec-writing-principles.md` and the
  relevant template (`feature.md`, `user-story.md`, `use-case.md`). Do not
  duplicate those rules here — defer to them. For substantial restructuring
  (splitting the feature, adding whole stories/use cases), hand back to
  `refine-feature` rather than reimplementing its drafting flow.
- For a spec under `implemented/`: do **not** edit it. Explain that implemented
  specs are durable and changes must go through `change-feature` →
  `reconcile-feature`.

Apply only the fixes the user approves. After editing, **re-judge the touched
criteria** and report the updated verdicts.

**Stay read-only by default.** Never write test-harness bookkeeping — this skill
does not touch `tests/feature-workflow/results/INDEX.md` or
`docs/superpowers/test-runs/` (those belong to the in-repo test harness, not to an
installed skill). The only writes this skill makes are user-approved fixes to the
spec under review.

## Common mistakes

| Mistake | Correct behavior |
| ------- | ---------------- |
| Drafting missing stories/use cases from scratch here | `review-feature` judges existing specs. For authoring or substantial drafting, redirect to `refine-feature`. |
| Editing a spec under `docs/features/implemented/` to fix a finding | Implemented specs are durable. Route fixes through `change-feature` → `reconcile-feature`; never edit `implemented/` here. |
| Writing fixes before the user accepts them | The skill is read-only until the user approves fixes. Present verdicts first, then ask. |
| Passing a criterion you could not verify, to be lenient | If the pass condition is not verifiable from the spec text, mark fail and cite what was missing. Strict but fair. |
| Restating the conventions or drafting rules in this skill | Reference `../refine-feature/references/conventions.md`, the templates, and `spec-writing-principles.md`; do not copy their text. |
| Skipping the structural pass because "there is a validator" | An installed repo has no `validate_spec.py`. The structural criteria in `references/rubric.md` are the user's only structural check — always run them. |
| Re-deriving criteria instead of reading the rubric | The criteria live in `references/rubric.md` (the single source of truth, shared with the `/judge-feature-spec` test command). Read it; do not invent criteria. |
