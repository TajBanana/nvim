---
name: refine-feature
type: skill
tags: [documentation, specs]
description: Use when authoring a not-yet-shipped feature spec — starting a brand-new one from a free-form description or by promoting a backlog stub at `docs/features/backlog/B-XXX-*.md`, or iterating on an existing spec under `docs/features/proposed/F-XXX-*/` (drafting stories and use cases, refining title or description, or bootstrapping an empty folder).
argument-hint: "[free-form feature description, path to docs/features/backlog/B-XXX-*.md, or feature title / path to docs/features/proposed/F-XXX-*/]"
version: 1.43.0
compatibility: [copilot, claude]
---

## Overview

Authors and refines a not-yet-shipped feature spec (`feature.md` +
`stories/` + `use-cases/`) under `docs/features/proposed/F-XXX-feature-title/`.

From a free-form description or a backlog stub it creates the proposed
folder, assigns the `F-XXX` ID and slug, and seeds `## Origin`
(see `references/creating-and-promoting.md`); from there — or when handed
an existing folder — it bootstraps the spec from the seed and drives the
user through title / description refinement, story coverage, and use-case
coverage.

Part of the feature-spec lifecycle: see
`references/lifecycle.md` for the full workflow map and redirect rules.

## When to use

- The user describes a brand-new feature in free-form text and there is
  no existing spec or stub for it → this skill creates the proposed
  folder and drafts the spec.
- The user points at a backlog stub (`docs/features/backlog/B-XXX-*.md`)
  and wants to promote it into a full feature spec.
- The user wants to draft or iterate on a feature spec under
  `docs/features/proposed/F-XXX-feature-title/` — adding, renaming, or
  refining stories or use cases.
- An empty `docs/features/proposed/F-XXX-*/` needs bootstrapping.

When NOT to use (redirect instead):

- Feature lives under `docs/features/implemented/` (it has shipped) →
  use `change-feature` to produce a change spec; `reconcile-feature`
  later applies it.
- Feature folder under `docs/features/proposed/F-XXX-feature-title/`
  contains only a `changes/` subdirectory (no `feature.md`) — this is
  the staging tree `change-feature` creates. Redirect to `change-feature`.
- Current repo is an **assembly** and the requirement is entirely
  service-level work in a single service → seed a backlog stub in that
  service and prompt the user to switch to a child-rooted agent (see the
  "Self-contained service requirement" path in
  `references/preflight-checks.md`).
- Current repo is a **submodule-based mono-repo** and the requirement lives
  wholly in one existing submodule → acquire its worktree and author the spec
  there (see the "Self-contained submodule requirement" path in
  `references/preflight-checks.md`).

## Procedure

**Pre-flight checks.** Before any other file operation, run the pre-flight checks in `references/preflight-checks.md`.

**Routing — does a target spec folder already exist?** Resolve `$ARGUMENT`
first:

- A **free-form description** with no matching feature, or a **backlog
  stub path** (`docs/features/backlog/B-XXX-*.md`) → run the
  **create / promote front-end** in `references/creating-and-promoting.md`
  (existing-match check, backlog dedupe on promotion, title derivation,
  multi-feature split, `F-XXX` ID + slug, folder creation, seed `## Origin`).
  When promoting a `B-XXX` stub, re-review its classification per
  `references/classification.md` — do not trust the stored `type:` blindly
  (stubs may be misfiled or understanding may have shifted). Confirm the
  classification with the user before routing: a `tech` stub (or any stub
  found under `docs/tech-tasks/backlog/`) → redirect to `refine-tech-task`.
  Then continue into the bootstrap step below with the seeded material.
- An **existing `docs/features/proposed/F-XXX-*/` folder** → skip the
  front-end. If `feature.md` is missing, bootstrap (below); otherwise
  refine in place.
- An **implemented spec** or a **`changes/`-only staging tree** → redirect
  per "When NOT to use" above; do not proceed here.

If `$ARGUMENT` is empty, ask the user for a description, a backlog stub
path, or a feature title / proposed-folder path.

**Classification gate.** Before drafting, apply `references/classification.md`
to `$ARGUMENT` (auto-classify, then confirm with the user):

- **Pure technical** (no user-, operator-, or developer-facing capability
  change) → redirect to `refine-tech-task`; do not draft a feature spec here.
- **Mixed** (functional + technical) → ask the user which artifact to author
  this run. Author the chosen one; write backlog stubs for the remaining
  part(s) with the correct `type:` in the correct backlog directory
  (`docs/features/backlog/` for feature stubs,
  `docs/tech-tasks/backlog/` for tech stubs), deduping against existing stubs
  (modify rather than duplicate). IDs come from the shared `B-XXX` counter
  (see `references/conventions.md`).
- **Functional** (any user-, operator-, or developer-facing behavior or contract
  change) → continue with this skill.

**Backlog rejection.** If, on considering a feature `B-XXX` stub for
promotion, the user decides it should not be pursued, reject it: move it to
`docs/features/backlog/rejected/B-XXX-<slug>.md` and append a `## Rejected`
section (`Rejected during refine-feature on YYYY-MM-DD. <reason>.`,
date-stamped per `references/conventions.md`). Do not delete it.

Feature specs live in one of two locations:

- `docs/features/proposed/F-XXX-feature-title/` — features that have been defined but not yet implemented and verified.
- `docs/features/implemented/F-XXX-feature-title/` — features that have shipped. These are the durable source of truth.

**Context-phase repo hydration.** While exploring project context — reading
feature docs, stories, use cases, and the codebase — acquire a per-feature
checkout of a downstream repo on demand as you encounter references to it by
calling `acquire-feature-repo <F-XXX-slug> <repo>` (via the Bash tool, running
`skillforge-repos acquire-feature-repo <F-XXX-slug> <repo>`). See
the shared model in the `repo-resolution` rule. Do not
acquire all repos up front — only resolve a repo when you actively need it.

This skill operates only on new or in-flight specs in `docs/features/proposed/`. If the requested feature is in one of the redirect states listed in "When NOT to use" above, redirect rather than proceeding here.

Directory structure under a feature folder:

- `feature.md` — the main feature specification document, following the template in `references/feature.md`.
- `stories/US-XXX-title.md` — a file for each user story, following `references/user-story.md`.
- `use-cases/UC-XXX-title.md` — a file for each use case, following `references/use-case.md`.

Move, rename the feature file and directory as necessary to ensure it follows the required structure and naming convention.

**Create / promote front-end.** When routing sent you to the front-end,
run `references/creating-and-promoting.md` end-to-end: existing-match check,
backlog dedupe (promotion only), title derivation, multi-feature split,
`F-XXX` ID + slug, folder creation, and seed `## Origin` construction. It
returns the seeded title, ID/slug, created folder, and seed Origin. Then
proceed into the bootstrap step with that seeded material. For a backlog
promotion, the front-end's **promotion cleanup** runs at the very end —
after the user accepts the full spec — not now.

**`epic_ref` — ask before writing the file.** Before copying the template, ask the user: "Does this feature belong to a parent epic? If yes, provide the epic ID in `E-XXX` format (e.g. `E-001`). If no parent epic, just press Enter." Validate any supplied value: it must be the letter `E`, a hyphen, and exactly three zero-padded digits (`E-001`…`E-999`). Reject invalid inputs and re-prompt until a valid value or an explicit "no" is confirmed. If a valid `epic_ref` is supplied, the generated `feature.md` starts with `---\nepic_ref: E-NNN\n---` before `# Feature Title`. If the user confirms no value, omit the frontmatter block entirely — the file starts directly with `# Feature Title`.

**Bootstrap when handed an empty or near-empty folder.** This skill (via the create/promote front-end) creates the feature folder but does not pre-fill the spec. If the folder exists but `feature.md` is missing, **copy `references/feature.md` verbatim** to the new `feature.md`, preserving every `#`, `##`, and `###` heading at its original level and in its original order (`# Feature Title` → `## Description` → `### In scope` → `### Out of scope` → `## Stories` → `## Jira` → `## Origin` → `## Open questions`). Then replace **only the placeholder content** under each heading with the seeded material — the title under H1, the description prose under `## Description`, in-scope bullets under `### In scope`, out-of-scope bullets under `### Out of scope`, the stories list under `## Stories` (initially empty), and the seed Origin string under `## Origin` (see next paragraph). Do not flatten, rename, reorder, or omit any heading. Seed material is sourced from whatever input was provided: the user's free-form description, the promoted backlog stub's `## Description`, or the upstream spec when the stub was promoted from a dep-originated backlog entry. Then proceed with the rest of this skill normally. Apply the same verbatim-copy-then-fill-placeholders bootstrap to `stories/US-XXX-*.md` files (using `references/user-story.md`) and `use-cases/UC-XXX-*.md` files (using `references/use-case.md`) — create the directories only when the first child file is written. Keep the `## Jira` section in `feature.md` and in every `stories/US-XXX-*.md` as the managed-placeholder comment from the template - never author or edit a Jira link by hand; this repo's CI pipeline (component / assembly / release) creates the Jira issue and fills the section. On a backlog promotion, still seed the blank template `## Jira` placeholder (never a key); the CI reconciles the carried key from the promoted stub (see `references/creating-and-promoting.md`, "Promotion and `## Jira`"). Use-case files have no `## Jira` section.

**Parent-feature context when bootstrapping from a backlog stub.** When the backlog stub's `## Origin` references a parent feature (e.g., `Split from F-XXX …` or `Dependency of F-XXX …`), attempt to locate that feature at the referenced path. If the path resolves, read it as additional context before drafting. If it cannot be found, ask the user: "I see this backlog references `F-XXX <title>` — where can I find that spec, or should I proceed with just the information in the backlog?" Proceed based on their answer — either load the supplied path or continue with the backlog content alone.

**Also seed `## Origin`.** The create/promote front-end (`references/creating-and-promoting.md`) constructs the seed Origin string alongside the seed description. If a seed Origin was constructed there, write it verbatim into the new `feature.md`'s `## Origin` section. If no seed Origin was supplied (the user invoked `refine-feature` directly against an empty folder), prompt the user for one and use the date-stamp rule in `references/conventions.md` for `YYYY-MM-DD`; do not silently leave the section blank. For pre-existing `feature.md` files that lack `## Origin` entirely (drafted before Round 3), leave the section absent — backfilling is optional, not required, and is the user's call.

Refine the feature title and description sections of the document according to the guidelines in the template file `references/feature.md`. Present the refinements to the user for review and feedback before finalizing.

Explore project context — check files, docs, recent commits for information relevant to the feature. Ask clarifying questions if any information is ambiguous or missing that prevents you from accurately refining the specification.

**Spec writing principles.** When drafting feature descriptions, stories, and use cases, follow the spec-writing principles in `references/spec-writing-principles.md`. Strip transport *form* from user input — HTTP methods, URL paths, SQL queries, queue topic names, etc. — and re-express as intent and data exchange. But **strip form, keep substance**: concrete requirement substance the user gave (file formats, field schemas, validation rules, value ranges, units, examples) is a requirement, not transport — preserve it in the use-case `## Data and contracts`, a story's acceptance criteria, or `## Requirement details`. **Never drop a user-provided detail without confirmation** (the hard no-drop gate in `spec-writing-principles.md`). Specify sync/async only when it has business significance. Record transport details preserved under the carve-out, and any other settled HOW decision the user mandated, in the feature's `## Design constraints` section.

**Requirements interview.** Drive the questions in `references/requirements-interview.md` to gather the functional and non-functional detail a spec needs to be behaviorally reproducible (regenerated code yields the same behavior) and test-derivable (an agent can write end-to-end tests from the spec alone). Run it **interleaved** with the drafting loop below — present each story, ask its story-level questions, confirm; then for each use case present it, run the per-use-case areas (C1–C6), and confirm — never a wall of questions upfront. Route answers into the existing sections the interview names; keep everything transport-agnostic.

A feature should have one or more user stories that collectively cover the full scope of the feature. If there are no user stories, or if the existing user stories do not fully cover the feature's scope, explore possible user stories and ask clarifying questions to define them as necessary. Use the template file `references/user-story.md` for guidance. Present each new user story or each story refinement to the user for review and feedback before finalizing.

After adding, renaming, or removing a user story, update the `## Stories` list in `feature.md` to reflect the current set. The list is the human-readable index of the feature; an outdated list silently drifts from the actual story files until `reconcile-feature` notices.

A user story should have one or more use cases that collectively cover the full scope of the story. If there are no use cases, or if the existing use cases do not fully cover the story's scope, explore possible use cases and ask clarifying questions to define them as necessary. Use the template file `references/use-case.md` for guidance. Present each new use case or each use case refinement to the user for review and feedback before finalizing.

When adding a new user story or use case, assign its ID per the rules in `references/conventions.md`. Confirm the chosen ID with the user before creating the file.

## Mid-drafting discoveries

While drafting, you may discover the feature's scope or structure is wrong. If any of the following surface, **stop drafting the current item, surface to the user, and on confirmation update state before resuming:**

- A use case belongs to a different story → move it, update both stories' `## Use cases` lists, and (if affected) the `## Stories` index in `feature.md`.
- Stories cluster into 2 or more loosely coupled groups — apply the H2 heuristic from `references/split-detection.md`. On **Split**: write a backlog stub for each split-off group (see "Writing backlog stubs" below) and narrow the current spec to what genuinely belongs; **Proceed as-is**: continue with the full scope and revisit during a future refinement; **Discuss**: open dialogue, revise the proposed split, then loop back to this check.
- The feature substantially overlaps with another feature in `docs/features/proposed/`, `docs/features/implemented/`, or `docs/features/backlog/` → surface to the user; either merge into the existing feature / promote the matching stub, or narrow the current spec to what is genuinely distinct.
- A story has no use cases that cover an acceptance criterion, or a use case is referenced by no story → surface to the user; either add the missing coverage or remove the orphan.
- A story or use case implies a **new sub-module or sub-component** that has no existing repo and no entry in the root README's `## Downstream Repositories` table → surface to the user: "This looks like it may require a new sub-component (`<name>`). Should I create it?" On confirmation, call `acquire-feature-repo <F-XXX-slug> <name>` (the resolver does `git init --bare` in the cache when the registry URL is `<pending>`). See the `repo-resolution` rule. Do not create silently.
- The current repo is an **assembly** and a story or use case implies service-level implementation → surface: "This repo is an assembly — it cannot implement this service behaviour directly. This work must be a backlog stub in the relevant service repo." Capture it in the post-acceptance dep step; do not draft it as in-scope implementation.
- The current repo is a **submodule-based mono-repo** and a story or use case implies work specific to a submodule component → surface: "This is a mono-repo — this work belongs in `<submodule-path>`. It must be a backlog stub there, not an in-scope story here." Capture it in the post-acceptance dep step; do not draft it as in-scope implementation. Cross-cutting logic already present in the root is in-scope.
- The feature creates a **new submodule component** and the abstraction-level question was not answered during pre-flight → stop before drafting the first story, ask the question from `references/preflight-checks.md`, then proceed accordingly.
- A story is drafted for an **assembly repo** and it implies service-level behaviour (not just composition or configuration) → surface: "This story requires changing service behaviour and cannot be implemented by the assembly directly. It must become a backlog stub in the relevant service repo."
- You realize mid-draft that the **entire** feature in an **assembly repo** is service-level with no assembly-level concern → stop drafting the assembly spec. Follow the "Self-contained service requirement" path in `references/preflight-checks.md`: seed a backlog stub in the service and prompt the user to switch to a child-rooted agent.
- You realize mid-draft that the **entire** feature in a **mono-repo** is self-contained in one existing submodule component with no cross-cutting root work → stop the root spec. Follow the "Self-contained submodule requirement" path in `references/preflight-checks.md`: acquire the component's worktree and author the spec there instead.
- A user-provided concrete detail (file format, field schema, value constraint, example) has **no obvious home** in the current draft → do not drop it. Route it to the use-case `## Data and contracts`, a story's acceptance criteria, or the feature's `## Design constraints` if it is a settled HOW decision. If it cannot yet be placed, record it under `## Open questions` and ask the user — never discard it silently.
- Mid-draft you realise the feature is **purely technical** — it has no user-, operator-, or developer-facing capability change → stop drafting, surface the finding to the user ("This looks like a pure tech task, not a feature — there is no user-, operator-, or developer-facing behavior change."), and redirect to `refine-tech-task`.

## Post-acceptance dependency step

Run this step only after the user has reviewed and accepted the full feature spec (all stories and use cases confirmed).

Follow the post-acceptance dependency step in `references/post-acceptance-dep-step.md` using the **feature variant**. For the Origin string, use `refine-feature` as the calling skill name.

For a backlog promotion, also run the **promotion cleanup** in
`references/creating-and-promoting.md` (archive the stub, append
`## Promoted`) after the user accepts the spec.

## Writing backlog stubs

When the user agrees to split off part of the current feature into the backlog, follow the shared procedure in `references/writing-backlog-stubs.md` using the `refine-feature` Origin variant (`Split from F-XXX <current-feature-title> during refine-feature on YYYY-MM-DD. <One-sentence reason for the split.>`).

After writing the stub, remove the split-off content from the current feature spec — including any user stories and use cases that move out — and update `feature.md`'s `## Stories` index. (The shared procedure flags this as a `refine-feature`-only follow-up.)

## Reference formatting

**Path anchor — applies to every link in every section.** All link paths in
generated files must be relative to the *directory containing the file*, not
the repository root. Method: count how many `../` steps reach the repo root
from the file's directory (call this N), then append the target's
repo-root-relative path. This rule governs every section — `## Stories`,
`## Use cases`, `## Dependencies`, `## Origin`, and any inline cross-reference.

Example — `feature.md` at `docs/features/proposed/F-XXX-slug/` (N = 3):
- `docs/ddr/DDR-001.md` → `../../../ddr/DDR-001.md`
- `references/repos/foo/docs/features/backlog/B-001.md` → `../../../references/repos/foo/docs/features/backlog/B-001.md`
- `docs/features/backlog/promoted/B-001.md` → `../../backlog/promoted/B-001.md` (target is within `docs/features/`, so only 2 `../`)

The section-specific examples below already follow this rule — use them as
ground truth when in doubt.

Every generated file must also follow the two rules in `references/conventions.md`
under "Reference formatting in generated documents":

1. **File-level references (`US-NNN`, `UC-NNN`)** must be written as markdown
   links. In `feature.md`'s `## Stories` use:
   `[US-001: title](stories/US-001-slug.md)`. In a story's `## Use cases` use:
   `[UC-001: title](../use-cases/UC-001-slug.md) — covers `AC-1`, `AC-2``.
   The link target slug must match the immutable filename slug for that file.

2. **JIRA-pattern identifiers** — any `[A-Z]+-\d+` identifier that is not a real
   JIRA reference must be wrapped in backticks in both prose and headings.
   Identifiers without a hyphen (e.g. `S1`, `S2`) are exempt.

These rules apply during bootstrap (copying and filling the template) and during
subsequent generation. When filling the `## Stories` placeholder links during
bootstrap, replace each placeholder entry with the real link using the assigned
ID and immutable filename slug.

## Common mistakes

### Routing

| Mistake | Correct behavior |
| ------- | ---------------- |
| Editing a feature under `docs/features/implemented/` here | Redirect to `change-feature` — implemented specs are durable and only `reconcile-feature` writes to them. |
| Drafting in a `proposed/F-XXX-*/` folder that holds only `changes/` | That is `change-feature`'s staging tree; redirect there. |
| Drafting a feature spec for purely technical input | Classify first (`references/classification.md`); redirect pure-tech input to `refine-tech-task`. |
| Trusting a stub's stored `type:` on promotion | Re-review the classification and confirm with the user before routing; a `tech` stub goes to `refine-tech-task`. |

### Create & promote

| Mistake | Correct behavior |
| ------- | ---------------- |
| Drafting a new spec when a matching feature already exists | Run the existing-match check across `proposed/`, `implemented/`, and `backlog/` first; redirect or promote as appropriate. |
| Silently overwriting a backlog stub on promotion | Promotion derives the proposed folder, drafts, then archives the stub after acceptance. Never edit the stub in place before archival. |
| Skipping the backlog dedupe sweep on promotion | After the existing-match check, sweep `backlog/` for overlapping stubs and offer fold/leave/delete per match. |
| Defining multiple features in one run | One run produces one spec. Keep one active; write the rest as backlog stubs. |
| Losing the stub's `## Origin` on promotion | The seed Origin must include the stub's existing `## Origin` verbatim under a `Stub origin:` prefix. |
| Forgetting to archive the stub after promotion, or archiving too early | Archive only after the user accepts the full spec. Leaving the stub in `backlog/` root re-surfaces it later. |
| Using a plain-text reference in the seed Origin instead of a markdown link | Use `[backlog stub B-XXX](../../backlog/promoted/B-XXX-<slug>.md)`. |
| Forgetting to append `## Promoted` to the moved stub | After moving, write `## Promoted` with a markdown link to the proposed `feature.md` before committing. |
| Passing only a short summary into bootstrap and losing the user's concrete detail | Pass the full user input; the seed Origin quote is provenance only. |

### Structure & format

| Mistake | Correct behavior |
| ------- | ---------------- |
| Writing `epic_ref` with an invalid format (e.g. `E-1`, `e-001`, `F-001`) | The value must be the letter `E`, a hyphen, and exactly three zero-padded digits (`E-001`…`E-999`). Reject and re-prompt until valid or user confirms no value. |
| Skipping the `## Origin` seed during bootstrap | Bootstrap must populate `## Origin` from the caller's seed text (or prompt the user if invoked directly). Silent omission breaks the provenance chain. |
| Flattening the `feature.md` template's H-level structure during bootstrap | The template's headings must be preserved exactly: `## Description` (H2) with `### In scope` and `### Out of scope` nested as H3, then `## Stories`, `## Origin`, optionally `## Open questions` (all H2). Do **not** omit the `## Description` heading, promote `### In scope`/`### Out of scope` to H2, or reorder sections. Replace only placeholder content; preserve the skeleton. Same rule applies to `stories/US-XXX-*.md` and `use-cases/UC-XXX-*.md`. |
| Renaming a story or use-case file when its title changes | Filename slugs are immutable per `references/conventions.md`. Update the H1 inside the file; leave the filename alone. |
| Adding or removing a story without updating `feature.md`'s `## Stories` index | The index drifts silently from the actual files until `reconcile-feature` notices. Update the index in the same change. |
| Writing `US-NNN: title` or `UC-NNN: title` as plain text in list items | Use markdown links: `[US-001: title](stories/US-001-slug.md)` / `[UC-001: title](../use-cases/UC-001-slug.md)` — plain IDs are caught as errors by `validate_spec.py` |
| Writing any link path relative to the repo root instead of the file's directory | Apply the path anchor rule: count `../` steps to the repo root from the file's directory, then append the target's repo-root-relative path. Applies to every section — `## Dependencies`, `## Origin`, `## Stories`, and all cross-references. `feature.md` at `docs/features/proposed/F-XXX-slug/` needs 3 `../` to reach anything directly under `docs/` (e.g. `docs/ddr/`, `references/repos/`). |
| Writing any `[A-Z]+-\d+` identifier (e.g. `US-001`, `AC-1`, `AF-1`) without backticks in prose or heading text | Wrap in backticks everywhere including headings: `` `AC-1` ``, `` `AF-1` ``. Identifiers without a hyphen (`S1`, `S2`) are exempt. |
| Reviewing an existing story or use-case file without verifying its section headings against the template | Cross-check every H2 heading in existing `US-XXX-*.md` and `UC-XXX-*.md` files against the corresponding template (`references/user-story.md` or `references/use-case.md`) before declaring the file reviewed; a wrong heading (e.g. `## Implements` instead of `## Use cases`) silently breaks tooling that parses spec structure by heading name. |

### Content coverage

| Mistake | Correct behavior |
| ------- | ---------------- |
| Splitting a feature into stubs silently | Always present each stub for review and run the dedupe sweep before writing. |
| Drafting use cases that no story references, or stories whose acceptance criteria no use case covers | Surface to the user mid-drafting (see "Mid-drafting discoveries") and resolve before continuing. |
| Leaving dangling references in a story's `## Use cases` list (use-case IDs cited without a matching file in `use-cases/`) | Every `UC-XXX` you list under a story's `## Use cases` must have a corresponding `use-cases/UC-XXX-*.md` file written **in the same session**. Before declaring a story drafted, cross-check its `## Use cases` list against the use-case directory; draft any missing file or remove the dangling reference. The mirror also holds for `feature.md`'s `## Stories` index against `stories/`. Dangling references silently break the spec until `reconcile-feature` (or `validate_spec.py`) catches them later. |
| Drafting use cases without running the requirements interview | Run `references/requirements-interview.md` interleaved with drafting — under-specified inputs, defaults, ordering, and error identity make the spec non-reproducible and its tests underivable. |

### Cross-repo deps

| Mistake | Correct behavior |
| ------- | ---------------- |
| Running the post-acceptance dep step before the user accepts the spec | The dep step must wait until the user has reviewed and accepted all stories and use cases |
| Writing the backlog stub on the downstream repo's main branch | Always ensure a non-main branch first; confirm with user if a non-main branch already exists |
| Creating a `## Dependencies` section with no entries | Only write the section when at least one dep entry is confirmed |
| Acquiring repos eagerly during context exploration | Call `acquire-feature-repo` on demand only — when a downstream repo is actively needed for context |
| Silently proceeding when a parent feature referenced in a backlog stub's `## Origin` cannot be found | Ask the user: "I see this backlog references `F-XXX <title>` — where can I find that spec, or should I proceed with just the information in the backlog?" Proceed based on their answer. |
| Silently creating a new sub-component without asking | Always surface the candidate to the user with the prompt "Should I create the new sub-component `<name>`?" and wait for confirmation before creating anything. |
| Trying to `git clone` a new sub-component | New sub-components have no remote yet — call `acquire-feature-repo <F-XXX-slug> <name>` (the resolver does `git init --bare` in the cache when the registry URL is `<pending>`), not a clone. See the `repo-resolution` rule. |
| Committing the backlog stub inside `references/repos/<name>/` for a new sub-component | `references/repos/<name>/` is an independent git repo the user must set up. Only commit in the parent repo. |

### Requirement fidelity

| Mistake | Correct behavior |
| ------- | ---------------- |
| Dropping a user-provided file format, field schema, or value constraint as "implementation detail" | That is requirement *substance*, not transport. Preserve it in the use-case `## Data and contracts`, a story's acceptance criteria, or `## Requirement details`. |
| Condensing a backlog stub to a short paragraph and losing the user's concrete specifics | Stubs are lossless. Put the what/why in `## Description` and every concrete specific in `## Requirement details`; settled HOW decisions in `## Design constraints`. |
| Discarding a user-provided detail without asking | Hard no-drop gate: ask "is X a hard requirement, or may I choose an alternative?" Drop only on confirmation. Re-expressing transport form is not a drop. |
| Putting a user-mandated transport/protocol/sync decision into intent prose or dropping it | Record settled HOW decisions in the feature/stub `## Design constraints` section. |

### Assembly & spec content

| Mistake | Correct behavior |
| ------- | ---------------- |
| Drafting assembly features as if the assembly implements services | If the current repo is an assembly, service-level work must be a backlog stub in the relevant service repo — not an in-scope story that the assembly implements directly. |
| Writing HTTP methods, endpoint paths, SQL queries, or protocol-specific terms in specs for a new service | Re-express as intent and data exchange per `references/spec-writing-principles.md`. Preserve transport details only when the carve-out applies. |
| Drafting a service-level story in an assembly spec because the feature description mentions it | Classify stories before drafting: assembly-level (deployment, config, routing) are in scope; service-level are not — route to dep step. |
| Leaving `## Stories` empty in an assembly spec with no explanation | If all implementation is in service repos, write a delegation note in `## Stories` and ensure `## Dependencies` lists each service stub. |
| Authoring a service's full feature spec from the assembly session when the requirement is self-contained in that one service | An assembly's services are separate repos. Seed a backlog stub in the service and prompt the user to switch to a child-rooted agent; do not draft the service spec yourself. |

### Mono-repo & spec content

| Mistake | Correct behavior |
| ------- | ---------------- |
| Drafting submodule-specific work as in-scope stories in a mono-repo | Route to backlog stub in `<submodule-path>/docs/features/backlog/` via the post-acceptance dep step |
| Treating all root-level work as out-of-scope in a mono-repo | Cross-cutting logic already owned by the root is in-scope |
| Drafting detailed implementation stories and use cases at the root level for a feature whose delivery vehicle is a new submodule component | Root-level specs for new submodule components describe integration contracts only; implementation stories go into the component's own feature spec via the post-acceptance dep step. |
| Writing `## Stories` as empty or `(none)` with no explanation when implementation is delegated | Include a brief note in `## Stories` explaining the delegation and referring to `## Dependencies`. |
| Creating a root-level spec plus a stub when the whole feature is self-contained in one existing submodule component | Check out a branch in the component (`git -C <submodule-path> checkout -b <branch>`), author the spec under `<submodule-path>/docs/features/`, push there, then bump the gitlink (`sync-submodule`). No root spec, no dependency entry, no stub. |
| Treating a repo as a plain repo when it has no `.gitmodules`, or treating it as a mono-repo when it is itself a submodule of some parent | A repo with no `.gitmodules` (or that is itself a submodule of a parent) is authored normally under its own `docs/features/`; do not route to a subdirectory. |
