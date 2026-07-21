---
epic_ref: E-NNN   # optional — omit this entire block when there is no parent epic
---
# Feature Title

Feature title should be clear and concise

- Uses a noun phrase to state exactly what the feature is.
- Names the **feature** (a capability or thing), not the **task** of building it.
  Drop task/process words — implementation, support, rework, build, MVP, v2,
  integration of, add, enable — when they only describe the activity rather than
  the feature itself.
- Structure: Descriptor + Core Function
- Examples:
  - Smart Search Filtering
  - One-Click Checkout
  - Track Streaming (not "Track Streaming Implementation" — that names the task)

## Description

Feature description starts with a short one sentence paragraph description of the feature that summarizes its purpose and value proposition

- Structure: Feature + Action Verb + User Benefit
- Examples:
  - Smart Search Filtering allows users to quickly narrow down search results by applying multiple filters, saving time and improving the search experience.
  - One-Click Checkout enables customers to complete their purchase with a single click, reducing friction and increasing conversion rates.

Subsequent paragraph can provide additional background information and context.

Avoid implementation language, including transport protocols (HTTP, REST, gRPC, SQL, message
queues). A reader should understand the feature's purpose without knowing how the system is
built or how its components communicate.

### In scope

- Capability included in this feature
- Another capability included
- A third capability

### Out of scope

Adjacent capability deliberately excluded, with brief reason
Something that might seem implied but is not

Out of scope is as important as in scope. Without it, scope creep is
invisible until it has already happened.

## Design constraints

*(Optional — include only when the user mandated a settled HOW decision.)*

Settled architectural/mechanism decisions the user fixed that would otherwise be
stripped as transport: required protocol/transport, sync/async mandate,
technology/platform, deployment target, fixed performance budgets. This is the
home for the `spec-writing-principles.md` carve-out — it keeps the description
transport-agnostic while preserving the constraint visibly. Omit the section when
no such constraint exists.

- e.g. Must accept files via SFTP drop; processing must be synchronous (user requirement).

Requirement *substance* (file formats, field schemas, value constraints) is not a
design constraint — it lives in each use case's `## Data and contracts`.

## Stories

List of child user stories. Each links to its own spec file.

- [US-001: short title](stories/US-001-short-title.md)
- [US-002: short title](stories/US-002-short-title.md)
- [US-003: short title](stories/US-003-short-title.md)

When this spec is an interface-level contract (assembly or new submodule), write instead:

  (Implementation stories are defined in `<downstream>` — see `## Dependencies`.)

## Dependencies

Cross-repo backlog items this feature depends on. Each entry links to a
downstream repository's backlog stub. `reconcile-feature` updates the link
target, ID, and status to `— implemented` when the dep ships.

For **external repos** (resolved via `references/repos/`):
- [B-001: short title](references/repos/repo-name/docs/features/backlog/B-001-short-title.md) — pending

For **mono-repo submodules** (a submodule directory under the workspace root):
- [B-001: short title](packages/component-name/docs/features/backlog/B-001-short-title.md) — pending

Omit this section entirely when no cross-repo dependencies exist.

## Jira

<!-- Maintained by this repo's CI pipeline. Do not edit by hand. -->

The Jira issue for this feature is created and kept in sync by this repo's CI
pipeline (component / assembly / release). On merge it creates the Jira issue
(type **Story**, which is the parent of this feature's story issues), writes
the issue link into this section, and updates the Jira status as the feature
ships. No manual ticket creation is needed; do not author or edit the link by
hand - the pipeline owns this section.

## Origin

Free-form provenance describing how this feature came to exist. Populated by
the `refine-feature` bootstrap clause and edited freely thereafter.

Examples:

- `Defined on 2026-05-18 from user input "users want to filter results by multiple criteria at once".`
- `Promoted from backlog stub B-014 on 2026-05-18. Stub origin: Surfaced during define-feature on 2026-05-12 from input description "...".`
- `Derived on 2026-05-18 from upstream spec 'repo-x/docs/features/implemented/F-014-bulk-edit/feature.md'.`

Upstream spec paths must use `repo-name/path` format — where `repo-name` is the
repository name extracted from the remote URL, not a local filesystem path.

Origin is metadata, not part of the durable behavior spec. Keep it short
and factual. For backlog-promoted features, preserve the stub's original
`## Origin` text verbatim under a "Stub origin:" prefix so the chain back
to the seed input (or upstream `derive-feature` spec) survives promotion.

Pre-existing features that lack this section need not be backfilled —
absence is allowed. If you do backfill, mark uncertain details as
`(reconstructed)`.

## Open questions

- `Q-1`: feature-level ambiguity blocking approval, with target resolution
- `Q-2`: another open item

Feature-level questions cover scope, naming, or cross-story concerns
that don't sit cleanly inside one story or use case. Story-level and
use-case-level questions belong in those files' `## Open questions`
sections.

## References

*(Optional — populate during reconciliation with links to documents produced
during design and implementation, such as design docs, plans, DDRs, and
implementation notes.)*

- [Document title](path/to/document.md)

Only link documents within the same repository (relative paths). Omit this
section entirely when no relevant documents exist.
