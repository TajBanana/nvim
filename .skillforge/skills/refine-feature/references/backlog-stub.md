---
type: feature        # feature | tech — set by the classification gate (see classification.md)
epic_ref: E-NNN     # optional — omit this line when there is no parent epic
priority: high      # optional — critical | high | medium | low; omit the line when unspecified
---
# B-XXX: Candidate Feature Title

A short, descriptive noun-phrase title for the candidate. This is not yet
the final feature title — `refine-feature` will refine it on promotion.
Use the Descriptor + Core Function shape if possible (e.g. "Saved Filter
Sets", "Bulk Order Cancellation").

The `type:` frontmatter records the classification (`feature` or `tech`). It is
set per `classification.md` (sibling reference) and is redundant with
the stub's directory (`docs/features/backlog/` for `feature`,
`docs/tech-tasks/backlog/` for `tech`) — kept explicit so promotion can
re-review it. A `tech` stub may also describe its technical intent in
`## Description`.

The optional `epic_ref:` frontmatter records the parent epic ID in `E-NNN`
format (e.g. `E-001`). Omit the line entirely when there is no parent epic —
the `type:` field is still required even without `epic_ref:`. A valid
`epic_ref` value is the letter `E`, a hyphen, and exactly three zero-padded
digits (`E-001`…`E-999`).

`priority:` (optional) — scheduling priority `critical | high | medium | low`, distinct
from a finding's criticality; omit the line when unspecified. A producer may
set it (e.g. review-branch maps a finding's criticality 1:1 onto `priority:`).

## Description

One or two short paragraphs describing what the candidate feature is and
why it should exist. This is the seed `refine-feature` will refine into a
full feature spec when the stub is promoted. Keep this a what/why summary —
concrete specifics belong in `## Requirement details` below, not here, but they
are never dropped.

If the candidate has an obvious in-scope / out-of-scope boundary worth
recording up front, write a couple of bullets. Otherwise, leave the
scoping to `refine-feature`.

## Requirement details

*(Optional — include only when the user provided concrete specifics.)*

Preserve, losslessly, every concrete requirement substance the user gave for
this candidate: file formats, field names and types, validation rules, value
ranges, units, ordering, naming conventions, size limits, examples, sample
payloads. Re-express only transport form per `spec-writing-principles.md`; do
not condense or drop substance. If the input was unclear, record the wording you
clarified with the user. This is what gives the promoted spec full fidelity — on
promotion it feeds the use-case `## Data and contracts`.

- e.g. Input file: CSV with columns date, source, amount; amount in cents; header row required.

## Design constraints

*(Optional — include only when the user mandated a settled HOW decision.)*

Settled architectural/mechanism decisions the user fixed that would otherwise be
stripped as transport: required protocol/transport, sync/async mandate,
technology/platform, deployment target, fixed performance budgets. This is the
home for the `spec-writing-principles.md` carve-out.

- e.g. Must accept files via SFTP drop; processing must be synchronous (user requirement).

## Jira

<!-- Maintained by this repo's CI pipeline. Do not edit by hand. -->

The Jira issue for this backlog candidate is created and kept in sync by this
repo's CI pipeline (component / assembly / release). A `type: feature` stub maps
to a Jira **Story**, a `type: tech` stub to a Jira **Task**; on promotion the same
issue carries forward to the feature (`F-NNN`) or tech-task (`T-NNN`) - it is not
re-created. No manual ticket creation is needed; do not author or edit the link by
hand - the pipeline owns this section.

## Origin

Free-form context about how this candidate came to exist. Examples:

- "Split off from F-007 Smart Search Filtering during refine-feature on
  2026-05-17. The original feature scoped only column-level filters; this
  candidate covers cross-column saved filter sets, which felt like a
  separate feature."
- "Surfaced during define-feature on 2026-05-12 from input description
  '...'. The description implied three features; this is the second."
- "Surfaced during derive-feature on 2026-05-14 from upstream spec
  `repo-x/docs/features/implemented/F-014-foo/feature.md`. The upstream
  feature maps to two target features; this is the one covering bulk
  edits."

For derive-feature-created stubs, **always include the absolute or
repo-relative path to the upstream spec** so a later `derive-feature`
invocation can re-establish the upstream link.
