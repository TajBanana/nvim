---
name: implement-feature
type: skill
tags: [implementation, orchestration]
description: Use when an accepted feature spec (`docs/features/proposed/F-XXX-*/feature.md`), accepted change spec (`changes/YYYY-MM-DD-*/feature-change.md`), or accepted tech-task (`docs/tech-tasks/proposed/T-XXX-*.md`) is ready to be turned into shipped code, or when the user wants to implement or build an already-accepted feature or tech-task by title.
argument-hint: "[feature title, or path to feature.md / feature-change.md, or path to a tech-task T-XXX-*.md]"
version: 1.9.0
compatibility: [copilot, claude]
---

## Overview

Turns an **accepted** feature spec or change spec into shipped code. This skill
fills the `[ implementation ]` box in the feature-spec lifecycle — the step
between `verify-feature-deps` and `reconcile-feature` that no other skill covers.

It is an **orchestrator**: it starts the `superpowers` workflow at
`superpowers:brainstorming` and lets that workflow carry the work through design,
planning, test-first implementation, and verification. It does **not** reimplement
or re-order those steps. What this skill adds is what the workflow does
not cover: resolving the input into the feature-spec layout, capturing significant
architectural decisions as DDRs, and handing off to `reconcile-feature` at the end.

Scope is **one repo per invocation**. Cross-repo dependencies are *checked*, not
implemented here.

Part of the feature-spec lifecycle: see
`../refine-feature/references/lifecycle.md` for the full workflow map.

## When to use

- A feature spec under `docs/features/proposed/F-XXX-*/` has been refined and
  accepted, and the user wants to build it.
- A change spec (`feature-change.md` inside
  `docs/features/proposed/F-XXX-*/changes/YYYY-MM-DD-*/`) has been accepted and
  the user wants to implement the delta.
- A tech-task under `docs/tech-tasks/proposed/T-XXX-*/` (a single
  `T-XXX-<slug>.md` file) has been accepted and the user wants to build it.

When NOT to use (redirect instead):

| Situation | Redirect |
| --------- | -------- |
| No spec exists for the title | `refine-feature` |
| Input is a backlog stub (`B-XXX-*.md`) | `refine-feature` (promote it first) |
| Folder under `proposed/` is still being drafted / not yet accepted | `refine-feature` |
| Feature is in `implemented/` with no pending change | ask the user, then `change-feature` |
| Implementation has already landed; spec needs syncing/promotion | `reconcile-feature` |
| Tech-task is still being drafted / not yet accepted | `refine-tech-task` |
| No tech-task exists for the title | `refine-tech-task` |

## Procedure

The phases run in order. Phase 0 gates are hard — do not skip ahead.

### Phase 0 — Preflight

1. **Required-skill availability check (hard stop).** Confirm
   `superpowers:brainstorming` is available — it is this skill's entry point into
   the `superpowers` workflow. If it is missing, tell the user to install the
   `superpowers` plugin and **STOP**; do not hand-roll a substitute. Only
   `brainstorming` is checked here: the rest of the workflow (planning,
   implementation, verification) is owned by the superpowers workflow itself, so
   this skill does not enumerate or gate on those individually and stays correct
   if that workflow changes.

2. **Branch management.** Apply the `branch-management` rule — never implement
   on `main`.

3. **Directory check.** If `docs/feature/` (singular) exists instead of
   `docs/features/`, follow the same rename-or-continue handling as
   `verify-feature-deps`' pre-flight directory check before proceeding.

4. **Resolve the input.** The user provides a feature title or a path as
   `$ARGUMENT`. If omitted, infer from session context; if ambiguous, ask.
   - **Title** → locate the spec folder under `docs/features/proposed/F-XXX-*/`.
   - **`feature.md`** → implement the full feature.
   - **`feature-change.md`** → implement the delta; read the implemented base
     spec under `docs/features/implemented/F-XXX-*/` and the delta files as the
     _to_ state.
   - **Tech-task title or `docs/tech-tasks/proposed/T-XXX-*.md`** → implement
     the tech-task. There are no stories/use-cases; the `## Intended Approach`,
     `## Design constraints`, `## Acceptance criteria`, and `## Affected features`
     sections are the requirements input.
   Apply the redirect table above if the input lands in a redirect state.

5. **Dependency check.** If the spec has a `## Dependencies` section with
   entries, run `verify-feature-deps` against it. Surface any `pending` /
   `sync needed` deps prominently; the user decides whether to proceed or stop.

6. **Rejection option (before building).** If, on reviewing the spec, the user
   decides it should not be built, reject it and STOP — do not run the workflow.
   - **Feature:** move `docs/features/proposed/F-XXX-*/` →
     `docs/features/rejected/F-XXX-*/` and append a `## Rejected` section to
     its `feature.md`.
   - **Tech-task:** move `docs/tech-tasks/proposed/T-XXX-*.md` →
     `docs/tech-tasks/rejected/` and append a `## Rejected` section.

   `## Rejected` shape (date-stamp per `../refine-feature/references/conventions.md`):
   `Rejected during implement-feature on YYYY-MM-DD. <reason>.`

### Phase 0.5 — Backlog Scan

Discover and summarise all backlog items across the current repo and any parent repos
before entering design. This gives `brainstorming` full forward visibility from the
first question.

1. **Discover backlog locations.** Collect all `docs/features/backlog/` directories
   to scan:

   - The current repo's own `docs/features/backlog/`.
   - **submodule mono-repo** (a root repo embedding components as git submodules): also scan the root mono-repo's `docs/features/backlog/` (detect via submodule paths in `.gitmodules`).
   - **Assembly** (a top-level repo that composes multiple service repos): also scan
     the assembly-level repo's `docs/features/backlog/`. Attempt to auto-detect the
     assembly root from the repo's configuration or conventions. If detection yields
     multiple candidates, present them to the user and ask which to use. If not
     detectable, ask the user for the location before proceeding. If the user confirms
     there is no parent, scan only the current repo and note that.
   - Skip stubs that have already been promoted: match on the slug portion after the
     ID prefix (e.g. `B-003-user-onboarding.md` matches `F-003-user-onboarding/`).
     If a matching folder exists under `docs/features/proposed/` or
     `docs/features/implemented/`, the stub is no longer backlog and need not be
     surfaced. If uncertain whether a stub is promoted, surface it rather than skip it.

2. **Read and summarise all stubs.** Read every `B-XXX-*.md` found. Present a
   structured summary to the user:
   - **Relevant items** (your judgment — shared domain terms, data entities, system
     components, or user population with the feature being implemented): listed with
     ID, title, source repo, 1–2 sentence description, and a sentence on why they
     relate to the feature being implemented.
   - **Remaining items**: report the count (e.g. "12 other backlog items judged
     non-relevant") and offer to list them on request — do not dump all stubs
     unprompted.
   - If no stubs exist anywhere, note that and proceed.

3. **Carry context into brainstorming.** Pass the full summary — with relevant items
   foregrounded — when invoking `superpowers:brainstorming`, framed as "known
   upcoming work to design around, not requirements to implement now."

### Phase 1 — Design and DDRs

Invoke `superpowers:brainstorming` to produce the implementation design from the
spec. Treat the accepted `feature.md` / `feature-change.md` (with its stories and
use cases) as the requirements input — do not re-litigate _what_ to build;
brainstorm _how_ to build it.

**Tech-task: durable-doc updates are first-class.** When the input is a
tech-task, architectural documentation is a primary deliverable alongside the
code. Capture DDR(s) for significant decisions using the same rules and approval
gate described below — there is no exception for tech-tasks. In addition, at the
start of Phase 1, read the `## Durable doc impact` section of the tech-task; for
each architecture documentation area named there, run the `update-tech-docs`
skill to apply the corresponding updates to `architecture.md` (or the relevant
section) as design decisions are finalised. Do not defer these updates to after
implementation.

**Backlog-aware design.** Keep the Phase 0.5 backlog summary in view throughout the design conversation.
When evaluating design options — data models, API
shapes, abstraction boundaries, extension points — explicitly consider whether relevant
backlog items (as identified in Phase 0.5)
would be well-served or poorly served by each option. Prefer designs that
leave clean extension points for upcoming work over designs that would require rework to
accommodate it. When a tradeoff between current scope and future backlog pressure is
non-trivial, surface it explicitly in the brainstorming conversation so the user can
decide.

**Backlog link recording.** When a design decision is directly shaped by a backlog
item, record the relationship durably:
- Once the relevant DDR is approved and written to disk: update the `B-XXX-*.md` stub —
  add or update a `## Related` section noting the current feature's `F-XXX`, a
  one-sentence description of the relationship, and a link to the DDR.
- Name the backlog item in the DDR's context or consequences section before seeking
  approval for that DDR.

In order: first complete bullet 2 (name the backlog item in the draft DDR), then
seek user approval, then write the DDR to disk, then complete bullet 1 (update the
stub).

As architectural decisions surface during design, capture the **significant**
ones as DDRs. What counts as significant, and where each DDR lives, is in the
**When a decision deserves a DDR** section below.

**DDRs during brainstorming (critical).** The `superpowers:brainstorming` skill
has no awareness of DDRs. You must maintain DDR responsibility throughout the
brainstorming conversation. Each time the user approves a significant option —
a library choice, an architectural pattern, a structural decision — immediately
pause, draft the DDR, present it for approval, write it to disk on approval,
and then continue the design. Do not wait for the brainstorming spec to be
written before drafting DDRs. The spec is written after all in-scope DDRs are
approved and on disk.

**Library maintenance check (before proposing).** `superpowers:brainstorming` is
unaware of this check — it is your responsibility as the orchestrating agent, in the
same way DDR capture is. Before presenting any library or framework choice to the
user, do a web search to verify the candidate is actively maintained. Signals of an
inactive project include: no release or commit in the past 12 months, repository
archived or marked deprecated, or an unacknowledged issues backlog with no maintainer
activity. If any of these signals are present, search for popular maintained
alternatives in the same space, evaluate the top options, and propose those instead —
do not surface an unmaintained candidate to the user as a viable choice. When the
project _is_ actively maintained, note the evidence briefly (e.g. last release date)
when you present it, so the user can see the check was done.

**Approval gate.** Every new DDR and every DDR update is a gate: draft it,
present the proposed content to the user, and get **explicit approval before
writing it to disk and before continuing with the design**. Do not move past an
unapproved decision — revise per feedback and re-present until the user
approves. Present and approve one DDR at a time as each decision surfaces; do
not batch a pile of DDRs at the end or write any ahead of approval.

- **New decision** → draft from `references/ddr-template.md`; on approval, write
  it to `<ddr-dir>/DDR-NNN-<title-slug>.md` where `<ddr-dir>` is the scoped DDR
  directory (see the scope rules below). `NNN` is the next unused zero-padded
  sequential id in that directory (scan existing `<ddr-dir>/DDR-*.md`; start at
  `001`). Derive `<title-slug>` with the slug rule in
  `../refine-feature/references/conventions.md`. Create `<ddr-dir>` if absent.
- **Existing decision being revised** → draft the update (the changed sections,
  the bumped **Last modified** date, and the new **Change Log** entry) and
  present it; on approval, apply it in place. Do not create a near-duplicate DDR.

Set the **Created** / **Last modified** dates with the date-stamp rule in
`../refine-feature/references/conventions.md` (local-clock `YYYY-MM-DD`). Link
each DDR back to its feature (`F-XXX`), and reference the relevant DDR(s) from
the design doc so the decision trail is navigable.

### Phase 2 — Implementation (superpowers workflow)

From the approved design, the `superpowers` workflow carries the work forward —
planning, test-first implementation, and verification. **Defer to that workflow;
do not re-specify or re-order its steps here**, so this skill stays correct as
the workflow evolves. Let it run to completion — code written and verified —
before moving on.

**Post-task review (cross-cutting, throughout Phase 2).** `superpowers`'s
workflow has no awareness of `post-coding-task-review` — like DDR capture in
Phase 1, this is your responsibility as the orchestrating agent, not the
workflow's. Confirm whether `post-coding-task-review` is installed among your
available skills (don't assume absent). If installed, each time an individual
task's code and tests are complete — before that task is committed — invoke it
and address whatever it fixes or surfaces before moving to the workflow's next
task. If not installed, note that and proceed.

### Phase 3 — Hand off to reconcile

Once the implementation is complete and verified, direct the user to the
appropriate reconcile skill to bring the spec in line with what actually shipped.
`implement-feature` does **not** edit the durable spec or promote it itself.

- **Feature or change spec** → `reconcile-feature` (promote `proposed/` →
  `implemented/`, or apply the change deltas).
- **Tech-task** → `reconcile-tech-task` (drift detection, open-questions gate,
  dep scan, then promote `docs/tech-tasks/proposed/T-XXX-*.md` →
  `docs/tech-tasks/implemented/T-XXX-*.md`).

## When a decision deserves a DDR — and where it lives

Record a DDR when a decision is **costly to reverse, affects more than one
component, or constrains future work** — for example a storage model, a sync vs
async boundary, a public contract shape, or a cross-cutting pattern. Do **not**
create DDRs for local, easily-reversed choices (variable names, a single
function's internals, test file layout). When unsure, ask the user whether the
decision is significant rather than guessing.

**Always DDR-worthy: adding a third-party component.** Introducing a third-party
component (library, framework, service, or tool) that is **not already in use in
another sub-module or repo of the project** is always a significant decision —
record a DDR for it. A component already adopted elsewhere in the project is
not a new decision and needs no DDR. Related components introduced together for
one purpose (e.g. a library and its companion plugins, or a client plus its
type definitions) may be **grouped into a single DDR** rather than one per
package.

**Scaffolding a new sub-module or repo.** When the design introduces a new
sub-module or repo, model it on the project's existing ones: study sibling
sub-modules/repos for directory structure, frameworks/libraries, and
design/coding patterns, and follow the established precedent. If the existing
sub-modules offer **more than one viable precedent** (they diverge, or no single
convention dominates), the structure / stack / pattern choice for the new module
is a significant decision — **write a DDR** for the new module/repo recording
the chosen precedent and why. If there is a single clear precedent, just follow
it (no DDR needed).

**Where the DDR lives (scope).** A DDR lives at the scope it governs. Pick the
narrowest scope that fully contains the decision, create that scope's `docs/ddr/`
if absent, and number `NNN` sequentially per DDR directory. When unsure, ask the
user.
- **Single repo** → the repo's own `docs/ddr/`.
- **Submodule mono-repo** → root `docs/ddr/` for mono-repo-wide (cross-cutting) decisions; `<submodule-path>/docs/ddr/` for a decision scoped to one submodule component (authored in the component via a worktree, same as stubs).
- **Assembly** → the same scoping applies: the assembly's own `docs/ddr/` for
  assembly-wide decisions; a decision scoped to a single service belongs in that
  service repo's `docs/ddr/`, recorded when implementing in that service (this
  skill is one repo per invocation).

## Common mistakes

| Mistake | Correct behavior |
| ------- | ---------------- |
| Writing code before design and DDRs | Design and DDR capture (Phase 1) come before any implementation. |
| Proceeding when `superpowers:brainstorming` is missing | Phase 0, step 1 is a hard stop — tell the user to install the `superpowers` plugin and stop. |
| Implementing on `main` | Phase 0, step 2 — create or confirm a non-main branch first. |
| Re-litigating _what_ to build during design | The accepted spec is the requirements input; brainstorm _how_, not _what_. |
| Re-specifying or re-ordering the implementation steps | Defer to the superpowers workflow (Phase 2); do not hard-code planning/implementation/verification here. |
| Skipping the dependency check when `## Dependencies` exists | Run `verify-feature-deps`; surface pending deps and let the user decide. |
| Spamming DDRs for trivial choices, or skipping them for significant ones | Apply the significance threshold; ask the user when unsure. |
| Batching DDRs after the brainstorming spec is written | Draft and present each DDR immediately when the underlying decision is approved during brainstorming — not as a cleanup step after the spec. The spec is written after all in-scope DDRs are on disk. |
| Writing or finalising a DDR without user approval | Each new/updated DDR is a gate — draft, present, get explicit approval, then write it and only then continue the design (Phase 1). |
| Creating a duplicate DDR for a decision that already has one | Update the existing DDR: bump Last modified and append a Change Log entry. |
| Editing or promoting the durable spec here | That is `reconcile-feature`'s job (Phase 3 hands off). |
| Implementing across downstream repos in one invocation | One repo per invocation; switch to the downstream repo and run `implement-feature` there. |
| Handing off to reconcile before the work is verified | Verification is part of the superpowers workflow (Phase 2); ensure it completed before Phase 3. |
| Skipping Phase 0.5 when the backlog directory is empty or missing | Note that no stubs were found and proceed — the phase still ran. Never silently skip it. |
| Treating the backlog summary as requirements to implement now | Backlog items are context to design around, not scope for this invocation. |
| Updating a backlog stub without user awareness | Backlog link recording is not silent — note each stub update as it happens. |
| Asking the user for the assembly repo location without first attempting auto-detection | Auto-detect first; ask only if detection fails. |
| Treating Phase 0.5 relevant/remaining split as final | The user may identify non-relevant items as relevant; the split is your judgment, not a gate. |
| Proposing a library without checking maintenance status | Do a web search first — verify the candidate is actively maintained. If abandoned, find and propose popular alternatives before presenting to the user. |
| Handing a tech-task to `reconcile-feature` | Tech-tasks use `reconcile-tech-task`, not `reconcile-feature`. `reconcile-feature` handles multi-file feature specs only. |
| Skipping `reconcile-tech-task` and moving a tech-task to `implemented/` directly | The `implemented/` copy must match what shipped; always hand off to `reconcile-tech-task` first. |
| Deleting a rejected spec instead of recording it | Move it to the `rejected/` dir and append `## Rejected`; never delete. |
| Skipping post-task review because Phase 2's subagent code review already passed | That review confirms correctness/spec compliance only; `post-coding-task-review` checks a separate lens (logging, test quality/coverage, mechanical test run) — run both, don't treat one as covering the other. |
