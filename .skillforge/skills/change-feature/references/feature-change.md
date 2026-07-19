# Change Title

Short imperative phrase naming the change, not the feature. The folder it lives in
is `changes/YYYY-MM-DD-<change-title-slug>/`.

- Names the change (what is being modified), e.g. `Add CSV export`, `Tighten
  filter validation`.
- Keep it to a short phrase; the date in the folder name carries the when.

## Context

Why this change exists: the request or problem that prompted it, and what outcome
it should produce. This describes the **change**, not the feature's durable
behavior — it stays inside the archived change record and is not back-ported into
`feature.md`. Anything that should outlive the change belongs in the delta files'
"Full revised content".

## In scope

- Capability this change adds or modifies
- Another included change

## Out of scope

Adjacent capability deliberately excluded, with a brief reason.

Out of scope is as important as in scope — without it, scope creep in the change is
invisible until it has already happened.

## Cross-cutting concerns

*(Optional — omit the section entirely if none.)*

Data migration, deprecation / backwards-compatibility notes, rollout sequencing.
Like Context, this stays inside the archived change record.

## Affected stories

Three lists. List only story-level (`US-NNN`) items here; each links to its story
delta file under `stories/US-XXX-delta.md`.

**Add**
- [US-014: short title](stories/US-014-delta.md)

**Change**
- [US-003: short title](stories/US-003-delta.md)

**Remove**
- [US-007: short title](stories/US-007-delta.md)

## Affected use cases

*(Optional — omit the section entirely if the change produces no use-case deltas.)*

Three lists. List only use-case-level (`UC-NNN`) items here; each links to its
use-case delta file under `use-cases/UC-XXX-delta.md`.

**Add**
- [UC-009: short title](use-cases/UC-009-delta.md)

**Change**
- [UC-002: short title](use-cases/UC-002-delta.md)

**Remove**
- [UC-005: short title](use-cases/UC-005-delta.md)

## Dependencies

*(Optional — omit the section entirely if none. Populated by the post-acceptance
dep step after the user accepts the spec.)*

Cross-repo change backlog items this change depends on. `reconcile-feature` updates
each entry to `— implemented` when the downstream dep ships.

- [B-001: short title](references/repos/repo-name/docs/features/backlog/B-001-short-title.md) — pending
