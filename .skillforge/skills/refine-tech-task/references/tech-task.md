---
epic_ref: E-NNN   # optional — omit this entire block when there is no parent epic
---
# T-XXX: Tech-Task Title

A short, descriptive title for the technical change. Use the slug rule in
`../refine-feature/references/conventions.md` for the filename slug.

## Problem

What is wrong today and why this change is needed. State the technical pain,
constraint, or risk being addressed.

## Goal

The desired technical end state in one or two sentences.

## Scope

### In scope

- Bullets naming what this tech-task will change.

### Out of scope

- Bullets naming explicitly-excluded work.

## Intended Approach

The intended technical approach. This is an *intention, not a binding
constraint*: every architectural and design decision here may be revisited
during implementation, and the as-built review reconciles this spec to what was
actually built.

## Design constraints

*(Optional — include only when there are strict, binding decisions.)*

Decisions implementation **must** honor (settled HOW): required
protocol/transport, technology/platform, deployment target, fixed performance
budgets, etc. Mirrors the feature spec's `## Design constraints`.

## Consequences

### Positive

- Benefits gained by making the change.

### Negative

- Costs, regressions risked, or complexity incurred.

## Affected features

The features whose *implementation* this change touches — the regression /
blast-radius scope, even though no behavior changes. One bullet per feature as a
markdown link with a note on what part is affected:

- [F-001: Feature Title](../../features/implemented/F-001-slug/feature.md) — which part is touched and why.

## Risks and mitigations

- **Risk:** … **Impact:** … **Mitigation / rollback:** …

## Acceptance criteria

Verifiable criteria. **Must** include a behavior-parity assertion and how it is
checked, e.g.:

- No externally-observable behavior change: existing tests for affected features
  remain green; outputs/contracts unchanged (evidence: …).
- …

## Durable doc impact

Which DDRs to add/update (`docs/ddr/DDR-NNN-*.md`) and which `architecture.md` /
tech-docs sections to refresh.

## Dependencies

*(Optional — include only when there is at least one cross-repo dependency.)*

Follows the feature `## Dependencies` convention.

## Jira

<!-- Maintained by this repo's CI pipeline. Do not edit by hand. -->

The Jira issue for this tech-task is created and kept in sync by this repo's CI
pipeline (component / assembly / release). On merge it creates the Jira issue
(type **task**), writes the issue link into this section, and updates the Jira
status as the tech-task ships. No manual ticket creation is needed; do not author
or edit the link by hand - the pipeline owns this section.

## Origin

Free-form provenance: how this tech-task came to exist, date-stamped per
`../refine-feature/references/conventions.md`.

## Open questions

*(Optional.)*
