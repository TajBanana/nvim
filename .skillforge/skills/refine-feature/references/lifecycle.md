# Feature-spec lifecycle

Shared across the feature-spec skills (`add-backlog`, `refine-feature`,
`review-feature`, `verify-feature-deps`, `implement-feature`,
`reconcile-feature`, `change-feature`, `refine-tech-task`, `implement-tech-task`,
`reconcile-tech-task`). They install together as the `skills`
group, so this file resolves from any sibling skill at
`../refine-feature/references/lifecycle.md`.

## Map

```
                    free-form description ──┐
                                            │
                    add-backlog ────────┼─→ docs/features/backlog/
                    (log idea to backlog)   │   B-XXX-*.md
                                            │        │
                    backlog stub  ──────────┤        │ (later, via refine-feature)
                    (B-XXX-*.md)            │        ▼
                                            ├─→ refine-feature
                                            │   (authors: create /
                                            │    bootstrap / iterate;
                                            │    feature.md, stories/,
                                            │    use-cases/)
                                            │                    │
                                            │                    ▼
                                            │            review-feature
                                            │       (optional quality gate:
                                            │        judge spec, fix issues)
                                            │                    │
                                            │                    ▼
                                            │         verify-feature-deps
                                            │       (optional pre-impl check:
                                            │        are cross-repo deps clear?)
                                            │                    │
                                            │                    ▼
                                            │            implement-feature
                                            │       (design + DDRs, plan, TDD;
                                            │        composes superpowers skills)
                                            │                    │
                                            │                    ▼
                                            │           reconcile-feature
                                            │       (drift fixes, promote
                                            │        proposed → implemented)
                                            │                    │
                                            │                    ▼
                                            │      docs/features/implemented/
                                            │              F-XXX-*/
                                            │                    │
                                            ▼                    ▼
                                    change-feature ◄────── shipped feature
                                    (delta specs)               needs a change
                                            │
                                            ▼
                                    reconcile-feature
                                    (apply deltas onto
                                     implemented spec)
```

## Storage

Three durable locations under each repo's `docs/features/`:

| Path                                                | Holds                              | Written by                          |
|-----------------------------------------------------|------------------------------------|-------------------------------------|
| `docs/features/backlog/B-XXX-<slug>.md`              | Stubs for later promotion          | add-backlog (new stub from description); refine (split-off); implement (annotates Related links) |
| `docs/features/proposed/F-XXX-<slug>/`               | In-flight specs and pending change folders | refine, change  |
| `docs/features/implemented/F-XXX-<slug>/`            | Durable source of truth            | reconcile (promote / apply)         |
| `docs/tech-tasks/backlog/B-XXX-<slug>.md` (type: tech) | Tech ideas for later promotion   | add-backlog; refine/refine-tech-task (split-off) |
| `docs/tech-tasks/proposed/T-XXX-<slug>.md`           | In-flight tech-tasks               | refine-tech-task                    |
| `docs/tech-tasks/implemented/T-XXX-<slug>.md`        | Retired (as-built) tech-tasks      | reconcile-tech-task (promote on completion) |
| `docs/{features,tech-tasks}/.../rejected/`            | Decided-against stubs and specs (`## Rejected`) | refine-feature / refine-tech-task (backlog); implement-feature (spec) |

Change folders live at
`docs/features/proposed/F-XXX-<slug>/changes/YYYY-MM-DD-<change-title>/`
while a change is in flight, and at
`docs/features/implemented/F-XXX-<slug>/changes/YYYY-MM-DD-<change-title>/`
once `reconcile-feature` archives them.

## One-line role of each skill

- **`add-backlog`** — log a feature idea directly to the backlog as a
  `B-XXX` stub without starting a full spec. Sweeps for near-duplicates and
  confirms with the user before writing.
- **`refine-feature`** — author a not-yet-shipped feature spec: create the
  proposed folder from a free-form description or backlog stub
  (`references/creating-and-promoting.md`), bootstrap when handed an empty
  folder, then iteratively draft and refine.
- **`review-feature`** — judge an existing feature spec against the content and
  structural rubric (`../review-feature/references/rubric.md`) before accepting it
  for implementation. Read-only by default; offers to fix failures in place for
  `proposed/` specs. Also reviews `implemented/` specs read-only.
- **`verify-feature-deps`** — read-only pre-implementation check: resolves
  each cross-repo dep in `## Dependencies` and reports whether it has
  shipped (`clear`), needs a sync update (`sync needed`), or is still
  pending. Run before starting implementation when cross-repo deps exist.
- **`refine-tech-task`** — author a one-time tech-task spec for a purely
  technical change (no user/operator behavior change): create the proposed
  single file from a free-form technical description or a `tech` backlog stub,
  draft `## Problem` … `## Acceptance criteria`, and (after acceptance) hand
  off to `implement-feature`. Inverts `refine-feature`'s strip-the-HOW rule:
  the technical approach is the core of the doc.
- **`implement-tech-task`** — named entry-point for tech-task implementation;
  redirects immediately to `implement-feature`, which handles tech-tasks natively.
  Use this for naming symmetry when working in the tech-task lifecycle.
- **`implement-feature`** — turn an accepted spec (or change spec) into
  shipped code. Orchestrator: composes `superpowers` skills for design,
  planning, and TDD, records significant decisions as DDRs under
  `docs/ddr/`, and may annotate backlog stubs (`docs/features/backlog/B-XXX-*.md`)
  with `## Related` links when design decisions are shaped by upcoming work.
  Hands off to `reconcile-feature` for features, or `reconcile-tech-task` for
  tech-tasks. One repo per invocation.
- **`change-feature`** — produce a change spec (delta docs under
  `changes/YYYY-MM-DD-*/`) for a feature already in `implemented/`. Does
  not edit the implemented spec directly.
- **`reconcile-tech-task`** — after a tech-task's implementation lands, bring
  the single-file spec in line with what shipped (drift detection,
  open-questions gate, dep scan), then promote
  `proposed/T-XXX-*.md` → `implemented/T-XXX-*.md`.
- **`reconcile-feature`** — after implementation lands, bring the spec in
  line with what shipped, then either promote (`proposed/` → `implemented/`)
  or apply (delta files onto the implemented spec).

## Redirect rules at a glance

| Situation                                                                          | Use                |
|------------------------------------------------------------------------------------|--------------------|
| User wants to log a feature idea to the backlog without starting a full spec now   | `add-backlog`  |
| User describes a brand-new feature (no existing spec)                              | `refine-feature`   |
| Feature folder exists under `proposed/` and needs drafting / refining              | `refine-feature`   |
| A drafted spec needs a quality/structural review before it is accepted for build   | `review-feature`   |
| Feature has cross-repo deps; user wants to check if they've shipped before coding  | `verify-feature-deps` |
| Accepted spec (or change spec) is ready to be built into code                      | `implement-feature` |
| Tech-task under `docs/tech-tasks/proposed/` is accepted and ready to build         | `implement-tech-task` |
| Feature folder exists under `implemented/` and the user wants to change it         | `change-feature`   |
| Implementation has shipped; spec needs to be reconciled and promoted / applied     | `reconcile-feature`|
| Tech-task implementation has shipped; spec needs reconciling and promoting         | `reconcile-tech-task` |
| Backlog stub at `B-XXX-*.md` should become a real feature                          | `refine-feature` with stub path as input |
| `proposed/F-XXX-*/` contains only `changes/` (no `feature.md`)                     | `change-feature` (staging tree) or `reconcile-feature` (if a change is ready) |
| Input is a purely technical change (no user/operator behavior change)               | `refine-tech-task` |
| Tech backlog stub at `docs/tech-tasks/backlog/B-XXX-*.md` should become a tech-task | `refine-tech-task` with stub path as input |

## Glossary

Key terms used across these skills are defined in `references/glossary.md`
(sibling of this file): staging tree, implementation range, assembly
constraint, feature-mode skills.
