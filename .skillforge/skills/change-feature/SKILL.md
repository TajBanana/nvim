---
name: change-feature
type: skill
tags: [documentation, specs]
description: Use when the user wants to modify a feature whose spec already lives in `docs/features/implemented/`. Produces a change spec (delta docs under `changes/YYYY-MM-DD-*/`) that `reconcile-feature` later applies onto the implemented spec.
argument-hint: "[feature title or path, change description]"
version: 1.17.1
compatibility: [copilot, claude]
---

## Overview

Produces a change spec for an already-implemented feature. Each
affected user story and use case gets a delta file under
`docs/features/proposed/F-XXX-feature-title/changes/YYYY-MM-DD-change-title/`
capturing the change-log header and the full revised content; a
top-level `feature-change.md` describes the change as a whole.
Implementation planning is intentionally **not** part of this skill —
once the change spec is confirmed, the user invokes their preferred
planning workflow with it as input.

Part of the feature-spec lifecycle: see
`../refine-feature/references/lifecycle.md` for the full workflow map
and redirect rules.

## When to use

- The feature has shipped — its spec lives under
  `docs/features/implemented/F-XXX-feature-title/` — and the user wants
  to modify, add, or remove stories / use cases.

When NOT to use (redirect instead):

- Feature is still in `docs/features/proposed/F-XXX-*/` (never shipped)
  → use `refine-feature` to edit the proposed spec directly. A change
  spec against a proposed spec adds churn without value.
- No matching feature exists for the user's input → check whether they
  meant `refine-feature` to author a brand-new feature; do not create folders
  speculatively.
- Implementation has already started (or finished) without a change
  spec → use `reconcile-feature` against the proposed change folder
  (or new-feature folder if this was actually a fresh feature) once
  the change spec exists.

## Procedure

The user should provide two arguments: the first argument is the feature path or title, and the second argument is the change description. Prompt for whichever is missing.

## 0. Pre-flight checks

Before any other file operation, run the pre-flight checks in `../refine-feature/references/preflight-checks.md`.

## 1. Locate the feature

Search `docs/features/implemented/` and `docs/features/proposed/` for a feature matching the user's input. If ambiguous, ask.

- If the feature is in `docs/features/proposed/` (never shipped), do not use this skill — direct the user to `refine-feature` to edit the proposed spec directly.
- If no feature matches the user's description, surface this and ask whether the user meant `refine-feature` to author a brand-new feature, before creating any folder.

## 2. Derive a change title

Derive a short kebab-case noun phrase change title (e.g. `add-saved-filters`, `widen-filter-persistence`). Confirm with the user; allow alternatives.

## 3. Create the change folder

Create `docs/features/proposed/F-XXX-feature-title/changes/YYYY-MM-DD-change-title/` using today's date per the date-stamp rule in `../refine-feature/references/conventions.md`.

If `docs/features/proposed/F-XXX-feature-title/` does not yet exist (because the feature lives only in `docs/features/implemented/F-XXX-feature-title/` and this is the first change against it), create only the bare staging tree — the `proposed/F-XXX-feature-title/` folder containing only the `changes/` subdirectory. Do **not** copy `feature.md`, `stories/`, or `use-cases/` from `implemented/`. The proposed folder is a staging area for pending changes only; `reconcile-feature` recognizes a proposed folder containing only `changes/` as exactly this state.

If `docs/features/proposed/F-XXX-feature-title/` already exists (a previous change is already in flight), do not recreate or modify it — the staging tree is already correct. Create only the new `changes/YYYY-MM-DD-change-title/` subfolder inside the existing staging tree. Before finalising the date slug, list the existing change folder names under `changes/` to avoid a collision (same date, similar title). If a collision exists, append a `-2` suffix or propose an alternative slug to the user.

## 4. Draft `feature-change.md` (provisional)

Copy `references/feature-change.md` into the change folder as `feature-change.md`,
then replace the guidance prose under each heading with real content — the same
verbatim-copy-then-fill pattern `refine-feature` uses for `feature.md`. State
explicitly to the user that the affected lists are a starting point and will be
revised as drafting proceeds.

The template (`references/feature-change.md`) defines the sections and the rules for
each: **Context**, **In scope**, **Out of scope**, optional **Cross-cutting
concerns**, **Affected stories** (Add / Change / Remove, story-level `US-NNN` only),
optional **Affected use cases** (Add / Change / Remove, use-case-level `UC-NNN`
only), and optional **Dependencies** (populated by the post-acceptance dep step §8).
Defer to the template for section content; do not restate it here.

**Scope of these sections.** `feature-change.md`'s **Context** and **Cross-cutting concerns** describe the change itself, not the feature's durable behavior. When `reconcile-feature` later archives the change folder under `docs/features/implemented/F-XXX-feature-title/changes/`, these sections stay inside the archived change record — they are not back-ported into the durable `feature.md`. Keep this in mind while drafting: anything that should outlive the change belongs in the delta files' "Full revised content" (which `reconcile-feature` does promote into the durable spec), not in `feature-change.md`.

Present the draft to the user; iterate before drafting any deltas.

**Spec writing principles.** When drafting delta content (change descriptions, story deltas, use-case deltas), follow the spec-writing principles in `../refine-feature/references/spec-writing-principles.md`. Strip transport *form* from user input — HTTP methods, URL paths, SQL queries, queue topic names, etc. — and re-express as intent and data exchange. But **strip form, keep substance**: concrete requirement substance the user gave (file formats, field schemas, validation rules, value ranges, units, examples) is a requirement, not transport — preserve it in the affected use-case `## Data and contracts` or acceptance criteria. **Never drop a user-provided detail without confirmation** (the hard no-drop gate in `spec-writing-principles.md`). Specify sync/async only when it has business significance. Record transport details preserved under the carve-out, and any other settled HOW decision the user mandated, in the affected spec's `## Design constraints`.

## 5. Iteratively draft delta files

**Before drafting a delta, read the matching file under `docs/features/implemented/F-XXX-feature-title/stories/US-XXX-*.md` or `use-cases/UC-XXX-*.md`.** That file is the _from_ state for the change. The delta's change-log header (below) describes what changes relative to it; the delta's "Full revised content" describes the _to_ state. Drafting either without first loading the current content risks producing a "revised content" that quietly contradicts shipped behavior.

For brand-new stories or use cases the change adds (no existing file matches the glob), there is no current content to read — note that explicitly in the change-log header.

Draft one delta file at a time, in dependency order (parent stories before their use cases when practical). For each, copy `references/delta.md` into the change folder as `stories/US-XXX-delta.md` or `use-cases/UC-XXX-delta.md`, then fill in its two parts:

1. **Change log header.** Lists each acceptance criterion / use case / flow step / business rule add, remove, and change. Every entry has a one-line rationale.
2. **Full revised content.** The complete story or use case as it should read after the change ships — same template structure as `../refine-feature/references/user-story.md` and `../refine-feature/references/use-case.md`. (Both skills are co-installed via the `skills` group, so this relative path resolves at runtime.) A story's `## Jira` section stays the managed placeholder from the template - never author or edit a Jira link; this repo's CI pipeline fills it. (Use cases have no `## Jira` section.)

See `references/delta.md` for the full rules on each part; defer to it rather than restating them.

Present each delta to the user; iterate on it before moving to the next.

### Mid-drafting discoveries

While drafting, the agent may discover that the provisional scope was wrong. If any of the following surface, **stop drafting the current item, surface to the user, and on confirmation update state before resuming:**

- A previously-unlisted story or use case in the **same feature** must also change → update `feature-change.md` and draft the additional delta.
- A use case referenced by an **unaffected story** would break under the revised behavior → either widen the change to cover that story, or revise the delta to keep the use case backwards-compatible. Record the decision in the use case's change log.
- The work belongs in a **different existing feature** → start a separate `change-feature` invocation for that feature, or record it as a follow-up if the user prefers not to bundle.
- The work doesn't fit any existing feature and warrants a **new feature** → hand off to `refine-feature`. Narrow the current change spec to what genuinely belongs in the original feature, or abandon it if nothing remains.
- A story or use case implies a **new sub-module or sub-component** that has no existing repo and no entry in the root README's `## Downstream Repositories` table → surface to the user: "This looks like it may require a new sub-component (`<name>`). Should I create it?" On confirmation, call `acquire-feature-repo <F-XXX-slug> <name>` (the resolver does `git init --bare` in the cache when the registry URL is `<pending>`). See the `repo-resolution` rule. Do not create silently.
- The current repo is an **assembly** and a delta implies service-level implementation → surface: "This repo is an assembly — it cannot implement this service behaviour directly. This work must be a backlog stub in the relevant service repo." Capture it in the post-acceptance dep step; do not draft it as in-scope delta content.
- The current repo is a **submodule mono-repo** and a delta implies work specific to a submodule → surface: "This is a mono-repo — this work belongs in `<submodule-path>`. It must be a backlog stub there, not in-scope delta content here." Capture it in the post-acceptance dep step; do not draft it as in-scope delta content. Cross-cutting logic already present in the root is in-scope.

When updating `feature-change.md` mid-drafting, also revise any already-drafted delta whose target state shifts as a result.

### Shared use case handling

Before drafting a use case delta, scan the feature for other stories that reference the same use case:

- If a referenced story is **also** in the affected list → produce one delta use case, reference it from both story deltas, and note the sharing in `feature-change.md`.
- If a referenced story is **not** affected → flag prominently in the use case's change log (for example: "Note: UC-007 is also used by US-002 which is not part of this change — confirm the revised behavior is acceptable there") and ask the user to confirm before proceeding.

### New ID assignment

When the change adds new stories or use cases, read the feature's existing IDs (across both the implemented spec under `docs/features/implemented/F-XXX-feature-title/` and any in-flight changes under `docs/features/proposed/F-XXX-feature-title/changes/`) and propose the next sequential ID, zero-padded to three digits (e.g. `US-014`, `UC-007`) — matching the convention documented in `refine-feature`. Confirm with the user; allow manual override. New deltas use the assigned IDs so the `reconcile-feature` skill can apply them as a straight file copy.

## 6. Final consistency pass

Before the final review, re-read `feature-change.md` against the delta files and verify:

- Every `US-NNN` in `## Affected stories` has a matching `stories/US-NNN-delta.md`.
- Every `stories/US-NNN-delta.md` is listed in `## Affected stories`.
- Every `UC-NNN` in `## Affected use cases` has a matching `use-cases/UC-NNN-delta.md`.
- Every `use-cases/UC-NNN-delta.md` is listed in `## Affected use cases`. If the change produced any use-case deltas, the `## Affected use cases` section must exist.
- Every use case referenced by a story delta exists (as a delta in this change, or in the original feature spec).
- Every change-log rationale matches the current draft content.

Fix drift inline.

## 7. Final review

Show the user the full change folder tree, summarize what was added, removed, or changed since the provisional draft, and ask for confirmation. Stop here. The user invokes their planning workflow of choice with the change spec as input.

**Heads-up about the reconcile-time gate.** Any unresolved `Q-N` items in the delta files' "Full revised content" will be surfaced by `reconcile-feature`'s open-questions gate when the change is reconciled (see `reconcile-feature` step 4a). Leaving non-blocking questions open here is fine — the gate offers resolve / defer / escalate per item at reconcile time — but blocking questions are easier to fix now than at reconcile.

## 8. Post-acceptance dependency step

Run after the user has accepted the full change spec in §7.

Follow the post-acceptance dependency step in `../refine-feature/references/post-acceptance-dep-step.md` using the **change variant**.

## Common mistakes

### Routing

| Mistake | Correct behavior |
| ------- | ---------------- |
| Producing a change spec against a feature still in `docs/features/proposed/` | Redirect to `refine-feature` — edit the proposed spec directly. A change spec against a not-yet-shipped feature adds churn without value. |
| Creating folders speculatively when no matching feature exists | If no feature in `implemented/` or `proposed/` matches the input, surface that to the user and ask whether they meant `refine-feature` before creating anything. |

### Structure & content

| Mistake | Correct behavior |
| ------- | ---------------- |
| Copying `feature.md`, `stories/`, or `use-cases/` from `implemented/` into the new `proposed/` staging tree | The staging tree under `docs/features/proposed/F-XXX-feature-title/` for an already-shipped feature contains only the `changes/` subdirectory. `reconcile-feature` recognizes that shape. Do not duplicate. |
| Drafting a delta without reading the current implemented file first | The implemented file is the **from-state**. Without it, the delta's "Full revised content" can silently contradict shipped behavior. Read the existing `US-XXX-*.md` / `UC-XXX-*.md` by ID-prefix glob before drafting. |
| Folding durable behavior into `feature-change.md` | `feature-change.md`'s Context / Cross-cutting concerns stay inside the archived change record. Anything that should outlive the change belongs in the delta files' "Full revised content" (which `reconcile-feature` promotes into the durable spec). |
| Drafting a use-case delta without flagging shared-story impact | Before drafting, scan the feature for other stories that reference the same use case. If a referenced story is **not** in the affected list, flag in the change log and ask the user to confirm before proceeding. |
| Assigning new `US-XXX` / `UC-XXX` IDs that collide with in-flight changes | Read existing IDs across both `docs/features/implemented/F-XXX-feature-title/` and any in-flight `docs/features/proposed/F-XXX-feature-title/changes/` folders before proposing the next sequential ID. |
| Letting `Affected stories` or `Affected use cases` drift from the delta files | The final consistency pass (§6) is mandatory. `## Affected stories` lists only `US-NNN` story deltas; `## Affected use cases` lists only `UC-NNN` use-case deltas. Every delta file must appear in its respective section; every listed ID must have a delta file. Fix drift inline. |
| Leaving blocking `Q-N` items in delta "Full revised content" | The reconcile-time open-questions gate (§4a in `reconcile-feature`) catches them, but blocking questions are easier to resolve here than at reconcile. Non-blocking questions are fine to defer. |

### Cross-repo deps

| Mistake | Correct behavior |
| ------- | ---------------- |
| Running the post-acceptance dep step before the user accepts the change spec | The dep step (§8) must wait until the user has confirmed the full change spec in §7 |
| Writing the change stub on the downstream repo's main branch | Always ensure a non-main branch first; confirm with user if a non-main branch already exists |
| Creating a `## Dependencies` section in `feature-change.md` with no entries | Only write the section when at least one dep entry is confirmed |
| Cloning repos eagerly before the user confirms a downstream dep is needed | Clone on demand only — after the user confirms the dep in step 1 |
| Silently creating a new sub-component without asking | Always surface the candidate to the user for confirmation before creating anything. |
| Trying to `git clone` a new sub-component | New sub-components have no remote yet — call `acquire-feature-repo <F-XXX-slug> <name>` (the resolver does `git init --bare` in the cache when the registry URL is `<pending>`), not a clone. See the `repo-resolution` rule. |
| Committing the backlog stub inside `references/repos/<name>/` for a new sub-component | `references/repos/<name>/` is an independent git repo the user must set up. Only commit in the parent repo. |

### Assembly & spec content

| Mistake | Correct behavior |
| ------- | ---------------- |
| Drafting assembly deltas as if the assembly implements services | If the current repo is an assembly, service-level work must be a backlog stub in the relevant service repo — not in-scope delta content the assembly implements directly. |
| Writing HTTP methods, endpoint paths, SQL queries, or protocol-specific terms in change deltas for a new service | Re-express as intent and data exchange per `../refine-feature/references/spec-writing-principles.md`. Preserve transport details only when the carve-out applies. |
| Dropping a user-provided file format, schema, or constraint from a delta as "implementation detail" | That is requirement substance, not transport. Preserve it in the affected use-case `## Data and contracts` or acceptance criteria; never drop a stated detail without confirming it is not a requirement. |

### Mono-repo & spec content

| Mistake | Correct behavior |
| ------- | ---------------- |
| Drafting submodule-specific deltas as in-scope content in a mono-repo | Route to backlog stub in `<submodule-path>/docs/features/backlog/` via the post-acceptance dep step |
| Treating all root-level work as out-of-scope in a mono-repo | Cross-cutting logic already owned by the root is in-scope |
