---
name: refine-tech-task
type: skill
tags: [documentation, specs, tech-task]
description: Use when authoring a one-time tech-task spec for a purely technical change with no user-, operator-, or developer-facing capability change — starting from a free-form technical description, promoting a `tech` backlog stub at `docs/tech-tasks/backlog/B-XXX-*.md`, or iterating on an existing `docs/tech-tasks/proposed/T-XXX-*.md`. Redirects functional input to refine-feature.
argument-hint: "[free-form technical description, path to docs/tech-tasks/backlog/B-XXX-*.md, or tech-task title / path to docs/tech-tasks/proposed/T-XXX-*.md]"
version: 1.6.0
compatibility: [copilot, claude]
---

## Overview

Authors and refines a single-file **tech-task** spec under
`docs/tech-tasks/proposed/T-XXX-<slug>.md`, copied from the template
`references/tech-task.md`. A tech-task captures a **purely technical change** —
one with no externally-observable behavior change for any user, operator, or
developer acting as a consumer of a new capability (refactors, performance work
with identical outputs, dependency/build/CI bumps, internal cleanup,
observability plumbing).

Unlike a feature spec, a tech-task is **a single file** — there are no stories
or use cases, because there is no user-facing behavior to decompose. This skill
is correspondingly lighter than `refine-feature`.

Part of the feature-spec lifecycle: see
`../refine-feature/references/lifecycle.md` for the full workflow map and
redirect rules.

**The inversion — HOW is in scope.** `refine-feature` strips transport *form*
and settled HOW from feature input per `../refine-feature/references/spec-writing-principles.md`, because a
feature spec is about behavior, not mechanism. A tech-task inverts this:
**because the work itself IS technical, the HOW is the substance of the doc.**
Do **not** apply the strip-the-transport / strip-the-HOW rule to
`## Intended Approach` or `## Design constraints` — those sections are the core
of a tech-task and must capture the intended mechanism and any binding technical
decisions. Everything else from the spec-writing principles still holds —
especially the hard **no-drop gate**: never discard a concrete detail the user
gave without confirmation; route it or ask.

## When to use

- The user describes a brand-new purely technical change in free-form text and
  there is no existing tech-task for it → this skill creates the proposed file
  and drafts the spec.
- The user points at a `tech` backlog stub
  (`docs/tech-tasks/backlog/B-XXX-*.md`) and wants to promote it into a full
  tech-task.
- The user wants to draft or iterate on a tech-task under
  `docs/tech-tasks/proposed/T-XXX-*.md`.

When NOT to use (redirect instead):

| Situation | Redirect to |
| --------- | ----------- |
| Input describes a user-, operator-, or developer-facing capability or contract change (functional) | `refine-feature` |
| Tech-task under `docs/tech-tasks/proposed/` is accepted and ready to build | `implement-feature` |
| Current repo is an **assembly** and the requirement is entirely service-level work in a single service | Same handling as `refine-feature` — see the "Self-contained service requirement" path in `../refine-feature/references/preflight-checks.md` |
| Current repo is a **submodule mono-repo** and the requirement lives wholly in one existing submodule | Same handling as `refine-feature` — see the "Self-contained submodule requirement" path in `../refine-feature/references/preflight-checks.md` |

## Procedure

**Pre-flight checks.** Before any other file operation, run the pre-flight
checks in `../refine-feature/references/preflight-checks.md` — the
`branch-management` rule, the `docs/feature` singular-vs-plural directory check,
and repo classification (assembly / mono-repo / submodule component). Tech-tasks live under
`docs/tech-tasks/`, parallel to `docs/features/`; the same assembly and
mono-repo routing applies (see "When NOT to use" above).

**Classification gate.** Before drafting, apply
`../refine-feature/references/classification.md` to `$ARGUMENT`: auto-classify,
state the verdict and the one-sentence reason, and ask the user to confirm
before committing to this path.

- **Functional** (any user-, operator-, or developer-facing behavior or contract
  change) → **stop** and redirect to `refine-feature`. Do not draft a tech-task
  here.
- **Mixed** (functional + technical) → follow "Mixed-drafting discoveries"
  below.
- **Pure technical**, confirmed → continue with this skill.

**Routing — resolve `$ARGUMENT`.**

- A **free-form technical description** with no matching tech-task → run the
  **create** path below.
- A **`tech` backlog stub path** (`docs/tech-tasks/backlog/B-XXX-*.md`) → run
  the **promote** path below.
- An **existing `docs/tech-tasks/proposed/T-XXX-*.md` file** → skip create /
  promote and refine it in place.

If `$ARGUMENT` is empty, ask the user for a technical description, a `tech`
backlog stub path, or a tech-task title / proposed-file path.

**Create / promote.**

**Multi-task split.** When the input is a free-form technical description, first
apply the H1 heuristic from `../refine-feature/references/split-detection.md`.
If the input contains sub-parts that each deliver technical value independently,
surface the split candidates and follow the outcome model. On **Split**: continue
with one task now; write the rest as `type: tech` backlog stubs in
`docs/tech-tasks/backlog/` via
`../refine-feature/references/writing-backlog-stubs.md` (Origin variant:
`Surfaced during refine-tech-task on YYYY-MM-DD from input description "<short quote or summary>".`).
Distribute each candidate's specifics to its own stub — never leave a detail
behind. On **Proceed as-is** or **Discuss**: follow the outcome model and
continue with the full description.

- **Assign the `T-XXX` ID** per `../refine-feature/references/conventions.md`:
  one above the highest `T-NNN` across `docs/tech-tasks/proposed/`,
  `docs/tech-tasks/implemented/`, and `docs/tech-tasks/rejected/`. Use the
  zero-padded `T-XXX` format. Derive `<slug>` per the slug rule in
  `conventions.md`. Confirm the chosen ID and slug with the user before creating
  the file.
- **Create** `docs/tech-tasks/proposed/T-XXX-<slug>.md` (a single file — no
  folder, no `stories/`, no `use-cases/`).
- **Seed `## Origin`** using the date-stamp rule in `conventions.md`:

  ```
  Refined via refine-tech-task on YYYY-MM-DD from <input>.
  ```

  where `<input>` is a short quote or summary of the free-form description (or
  the stub reference, for a promotion — see below). Surface the seed Origin to
  the user for confirmation along with the ID and slug.
- **`epic_ref`.** Ask the user: "Does this tech-task belong to a parent epic? If yes, provide the epic ID in `E-XXX` format (e.g. `E-001`). If no parent epic, just press Enter." Validate any supplied value: it must be the letter `E`, a hyphen, and exactly three zero-padded digits (`E-001`…`E-999`). Reject invalid inputs and re-prompt until a valid value or an explicit "no" is confirmed. If a valid `epic_ref` is supplied, the generated `T-XXX-<slug>.md` starts with `---\nepic_ref: E-NNN\n---` before `# T-XXX: Tech-Task Title`. If the user confirms no value, omit the frontmatter block — the file starts directly with `# T-XXX: Tech-Task Title`.
- **Backlog promotion (additional steps).** When the input is a `tech` stub,
  mirror `../refine-feature/references/creating-and-promoting.md`:
  - **Re-review the classification** from the stub's content — do not trust the
    stored `type:` blindly (the stub may have been misfiled). Confirm with the
    user. If it is actually functional, redirect to `refine-feature`.
  - **Existing-match check + dedupe**: before drafting, check
    `docs/tech-tasks/proposed/`, `docs/tech-tasks/implemented/`, and
    `docs/tech-tasks/backlog/` (excluding `backlog/promoted/`) for an existing
    tech-task or overlapping stub; surface matches. Sweep the tech-task backlog
    for overlapping stubs and offer fold / leave / delete per match.
  - **Seed `## Origin`** for a promotion preserves the stub's own `## Origin`
    verbatim:

    ```
    Promoted from [backlog stub B-XXX](../backlog/promoted/B-XXX-<slug>.md) on YYYY-MM-DD.

    Stub origin: <verbatim content of the stub's ## Origin section>
    ```

    (The proposed file lives at `docs/tech-tasks/proposed/`, so the link to
    `docs/tech-tasks/backlog/promoted/` uses a single `../` — target is within
    `docs/tech-tasks/`, so only one `../` — same logic as the corresponding
    bullet in "Reference formatting" below.)
  - **`## Jira` on promotion.** The proposed tech-task seeds the **blank managed
    `## Jira` placeholder** from the template (marker comment, no link) - never
    write a Jira key; the section is pipeline-managed. The stub's Jira **Task** is
    still reused (not re-created): the CI reconciles the carried key from the
    promoted stub at `docs/tech-tasks/backlog/promoted/B-XXX-<slug>.md`
    (`carried_jira_key()`), so the archive step below must `git mv` the stub there
    with its `## Jira` **intact** (it only appends `## Promoted`; do not strip
    `## Jira`).
  - **Draft first; archive only after acceptance.** Do not touch the stub before
    the user accepts the full tech-task. After acceptance, **move**
    `docs/tech-tasks/backlog/B-XXX-<slug>.md` →
    `docs/tech-tasks/backlog/promoted/B-XXX-<slug>.md` (filename unchanged;
    `mkdir -p` the dir first; `git mv` if tracked) and append a `## Promoted`
    section linking to the proposed file:

    ```markdown
    ## Promoted

    Promoted to [T-XXX <tech-task-title>](../../proposed/T-XXX-<slug>.md) on YYYY-MM-DD.
    ```

**Bootstrap.** Copy `references/tech-task.md` **verbatim** into the new file,
preserving every `#`, `##`, and `###` heading at its original level and in its
original order. Then replace **only the placeholder content** under each heading
with the seeded material — do not flatten, rename, reorder, or omit any heading.
Seed material is sourced from the user's free-form description or the promoted
stub's `## Description`. Write the seed `## Origin` string verbatim into the
`## Origin` section. Drop the optional `## Design constraints`,
`## Dependencies`, and `## Open questions` sections only when they genuinely have
no content — otherwise keep and fill them. `## Durable doc impact` is a
**required** section and must always be seeded (never dropped). Keep the
`## Jira` section as the managed-placeholder comment from the template - never
author or edit a Jira link by hand; this repo's CI pipeline (component / assembly
/ release) creates the Jira issue (type **task**) and fills the section.

**Parity & blast-radius interview.** Before and during refinement, drive the questions in `references/parity-interview.md` to pin the observable behavioral baseline precisely enough that "no externally-observable change" is *verifiable*, map the blast radius, and settle how parity is proven. Route answers into `## Affected features`, `## Design constraints`, `## Acceptance criteria`, and `## Risks and mitigations` as the interview names.

**Refine.** Drive the user through each section in order, exploring project
context (files, docs, recent commits, DDRs, `architecture.md`) and asking
clarifying questions where information is ambiguous or missing. Present each
section to the user for review and feedback before finalizing:

- **Title** — a clear noun phrase naming the change.
- **`## Problem`** — what is wrong today and why the change is needed (technical
  pain, constraint, or risk).
- **`## Goal`** — the desired technical end state, in one or two sentences.
- **`## Scope`** → `### In scope` / `### Out of scope`.
- **`## Intended Approach`** — the intended technical approach. HOW is in scope
  here (the inversion). Frame it as an intention, not a binding constraint;
  the as-built review during `implement-feature` reconciles the spec to what was
  actually built.
- **`## Design constraints`** *(optional)* — strict, binding technical decisions
  implementation must honor (required protocol/transport, technology/platform,
  deployment target, fixed performance budgets). Omit when there are none.
- **`## Consequences`** → `### Positive` **and** `### Negative` — the trade-offs:
  benefits gained vs. costs, regressions risked, or complexity incurred. Both
  subsections must carry substantive entries.
- **`## Affected features`** — the features whose *implementation* this change
  touches (the regression / blast-radius scope, even though no behavior
  changes). One bullet per feature as an `F-XXX` markdown link with a note on
  what part is affected. Follow the path-anchor rule (see "Reference
  formatting"). Never leave this section empty — if nothing is affected, say so
  explicitly and confirm with the user.
- **`## Risks and mitigations`** — each material risk with its impact and the
  mitigation / rollback for it.
- **`## Acceptance criteria`** — verifiable criteria. This **must** include a
  behavior-parity assertion and how it is checked (e.g. existing tests for
  affected features remain green; outputs/contracts unchanged; benchmark within
  budget).
- **`## Durable doc impact`** — which DDRs to add/update and which
  `architecture.md` / tech-docs sections to refresh. A tech-task is a one-time
  working spec; the durable knowledge lives on in the DDRs and tech docs it
  drives.

## Mixed-drafting discoveries

While classifying or drafting, you may discover the input is not purely
technical. If any of the following surface, **stop, surface to the user, and act
on confirmation:**

- The input turns out to be **functional** (a user-, operator-, or
  developer-facing behavior or contract change) → stop drafting, surface it, and
  redirect to `refine-feature`. Do not continue a tech-task.
- The input is **mixed** (functional + technical) → ask the user **which
  artifact to author this run** (tech-task or feature spec). Author the chosen
  one. Backlog the remaining part(s) with the correct `type:` and in the correct
  backlog dir per `../refine-feature/references/classification.md` and
  `../refine-feature/references/writing-backlog-stubs.md` — `type: feature` to
  `docs/features/backlog/`, `type: tech` to `docs/tech-tasks/backlog/`. Dedupe
  against existing stubs (modify rather than duplicate); IDs come from the shared
  `B-XXX` counter (`conventions.md`).
- A user-provided concrete detail (file format, field schema, value constraint,
  command, version pin, example) has **no obvious home** in the current draft →
  do not drop it. Route it to `## Intended Approach`, `## Design constraints`,
  or `## Acceptance criteria` as appropriate; if it cannot yet be placed, record
  it under `## Open questions` and ask the user. Never discard it silently.

## Backlog rejection

When a `tech` stub is considered for promotion and the user decides it should
**not** be pursued, reject it rather than deleting it — the record prevents the
same idea being re-proposed without context. Move it to the `rejected/` subdir of
the tech-task backlog and append a `## Rejected` section:

1. **Move** `docs/tech-tasks/backlog/B-XXX-<slug>.md` →
   `docs/tech-tasks/backlog/rejected/B-XXX-<slug>.md` (filename unchanged;
   `mkdir -p` the dir first; `git mv` if tracked).
2. **Append** to the moved stub:

   ```markdown
   ## Rejected

   Rejected during refine-tech-task on YYYY-MM-DD. <One-or-two-sentence reason.>
   ```

   (`YYYY-MM-DD` per the `conventions.md` date-stamp rule.)

Do **not** delete the stub. The rejected `B-XXX` number is never reused (the
shared backlog counter scans `rejected/`).

## Mid-drafting scope discoveries

While drafting, you may discover the scope is larger than initially apparent. If
the following surfaces, **stop, surface to the user, and act on confirmation:**

- Tasks cluster into 2 or more loosely coupled groups — apply the H2 heuristic
  from `../refine-feature/references/split-detection.md`. On **Split**: continue
  with one cluster; write the rest as `type: tech` backlog stubs in
  `docs/tech-tasks/backlog/` and narrow the current tech-task to what genuinely
  belongs. On **Proceed as-is**: continue with the full scope; the user can
  reconsider during a future refinement session. On **Discuss**: open dialogue,
  revise the proposed split, then loop back to this check.

## Post-acceptance dependency step

Run this step only after the user has reviewed and accepted the full tech-task.

Follow the post-acceptance dependency step in
`../refine-feature/references/post-acceptance-dep-step.md` using the **feature
variant** (or the mono-repo variant when mono-repo mode was detected during
pre-flight). For the Origin string, use `refine-tech-task` as the calling skill
name.

For a backlog promotion, also run the **promotion cleanup** described under
"Create / promote" above — archive the stub to
`docs/tech-tasks/backlog/promoted/` and append `## Promoted` — after the user
accepts the spec.

## Reference formatting

Apply the same rules `refine-feature` uses for every generated file.

**Path anchor — applies to every link in every section.** All link paths must be
relative to the *directory containing the file*. A tech-task is a flat file
directly in `docs/tech-tasks/proposed/`, so its directory is
`docs/tech-tasks/proposed/` — two `../` reach `docs/`. (That is one fewer `../`
than a feature spec, which lives in its own per-feature folder
`docs/features/proposed/F-XXX-slug/`.) Append the target's path under `docs/`:

- `docs/ddr/DDR-001.md` → `../../ddr/DDR-001.md`
- `docs/features/implemented/F-001-slug/feature.md` →
  `../../features/implemented/F-001-slug/feature.md` (so a
  `## Affected features` link needs two `../` to reach `docs/features/`)
- `docs/tech-tasks/backlog/promoted/B-001-slug.md` → `../backlog/promoted/B-001-slug.md`
  (target is within `docs/tech-tasks/`, so only one `../`)

Every generated file must also follow the two rules in
`../refine-feature/references/conventions.md` under "Reference formatting in
generated documents":

1. **File-level references** (`F-NNN` links in `## Affected features`, `B-NNN`
   promotion/dependency links) must be written as markdown links — e.g.
   `[F-001: title](../../features/implemented/F-001-slug/feature.md)`. The
   link target slug must match the immutable filename slug for that file.
2. **JIRA-pattern identifiers** — any `[A-Z]+-\d+` identifier (e.g. `T-002`,
   `B-007`) that is not a real JIRA reference and is not already inside a
   markdown link must be wrapped in backticks, in both prose and headings.
   Identifiers without a hyphen are exempt.

## Common mistakes

| Mistake | Correct behavior |
| ------- | ---------------- |
| Writing `epic_ref` with an invalid format (e.g. `E-1`, `e-001`, `F-001`) | The value must be the letter `E`, a hyphen, and exactly three zero-padded digits (`E-001`…`E-999`). Reject and re-prompt until valid or user confirms no value. |
| Drafting stories or use cases | A tech-task is a single file with no stories or use cases. There is no user-facing behavior to decompose. |
| Stripping the HOW from `## Intended Approach` | The inversion: HOW is the substance of a tech-task. Do not apply `../refine-feature/references/spec-writing-principles.md`'s strip-the-transport / strip-the-HOW rule to `## Intended Approach` or `## Design constraints`. |
| Omitting the behavior-parity assertion from `## Acceptance criteria` | A tech-task must prove no externally-observable behavior changed — include the parity check (tests green, outputs/contracts unchanged, benchmark) and how it is verified. |
| Leaving `## Affected features` empty | Identify the regression / blast-radius scope as `F-XXX` markdown links with a note on what part is touched. If nothing is affected, state so explicitly and confirm. |
| Filling only `### Positive` under `## Consequences` | Both `### Positive` and `### Negative` must carry substantive entries — every change has costs or risks. |
| Trusting a stub's stored `type:` on promotion | Re-derive the classification from the stub's content per `classification.md` and confirm before routing. A misfiled stub may actually be functional → `refine-feature`. |
| Deleting a rejected stub | Move it to `docs/tech-tasks/backlog/rejected/` and append `## Rejected` with a reason. The record prevents re-proposal without context; the number is never reused. |
| Drafting a feature spec for functional input here | Classification gate first — functional input redirects to `refine-feature`; never draft a tech-task for a behavior change. |
| Drafting submodule component / service work as in-scope in an assembly or mono-repo | Route it to a backlog stub in the relevant repo via the post-acceptance dep step, exactly as `refine-feature` does. The assembly / mono-repo cannot implement service-level work directly. |
| Writing a link path relative to the repo root instead of the file's directory | Apply the path-anchor rule: count `../` steps to the repo root (N = 3 for a file at `docs/tech-tasks/proposed/`), then append the target's repo-root-relative path. |
| Archiving or rejecting the stub before the user accepts | Touch the stub only after acceptance (promotion → `promoted/`) or after the explicit reject decision (→ `rejected/`). |
| Asserting behavior parity without pinning the observable baseline | Run `references/parity-interview.md` — parity is only verifiable once the exact outputs, ordering, error identity, and load profile that must stay unchanged are written down. |
