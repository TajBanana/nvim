---
name: reconcile-tech-task
type: skill
tags: [documentation, specs]
description: Use after a tech-task's implementation has shipped and the spec needs to catch up — when there is implementation drift to resolve, open questions to gate, or dependencies to confirm before promotion.
argument-hint: "[tech-task title, or path to docs/tech-tasks/proposed/T-XXX-*.md]"
version: 1.2.0
compatibility: [copilot, claude]
---

## Overview

Runs **after** implementation lands. Detects drift between the proposed
`docs/tech-tasks/proposed/T-XXX-<slug>.md` and what actually shipped, gates on
open questions and pending cross-repo dependencies, then promotes the file to
`docs/tech-tasks/implemented/T-XXX-<slug>.md`.

Implementation planning is intentionally **not** part of this skill — it runs
after implementation, not before. Use `implement-tech-task` (or `implement-feature`
directly) to design, plan, and build the tech-task first.

Part of the feature-spec lifecycle: see
`../refine-feature/references/lifecycle.md` for the full workflow map.

## When to use

- A tech-task under `docs/tech-tasks/proposed/T-XXX-*.md` has been implemented
  and the user wants to reconcile the spec with what shipped and promote it.
- Implementation drift is known from the session and needs to be recorded before
  the spec becomes the durable as-built record.

When NOT to use (redirect instead):

| Situation | Redirect |
| --------- | -------- |
| Tech-task has not been implemented yet | `implement-tech-task` |
| Tech-task is still being drafted / not yet accepted | `refine-tech-task` |
| No tech-task exists for the title | `refine-tech-task` |

## 1. Resolve the working item

The user may pass a path or tech-task title as `$ARGUMENT`, or omit it.

- If `$ARGUMENT` is given, resolve it to `docs/tech-tasks/proposed/T-XXX-<slug>.md`.
- If `$ARGUMENT` is omitted, check the current session context for a clearly-implied
  working tech-task (for example, the user just finished implementing it in this session).
  Use that if unambiguous.
- If neither argument nor session context resolves, list candidates under
  `docs/tech-tasks/proposed/` and ask the user to pick.

## 2. Pre-flight checks

- If the working tree is dirty, refuse to run. Ask the user to commit or stash first.
  The reconcile commits must contain only reconcile changes.
- Confirm the git branch is appropriate per the project's `branch-management` rule.

## 3. Drift detection

This runs before any spec edits or file moves.

1. **Establish the baseline.** The baseline is the proposed tech-task file as it
   existed when the implementation began. Drift = differences between the baseline
   spec and what actually shipped.

2. **Gather candidate drifts.**
   - **Session context first.** If the conversation already knows what shipped
     (because the implementation happened in this session), use that as the candidate
     drift list.
   - **Otherwise**, scan commits and current code in the _implementation range_ for
     deviations from the baseline. The implementation range is the commits since the
     tech-task file was first added to git. Find the creation commit with:
     `git log --diff-filter=A --format=%H -- <file> | tail -1`
     The range is that commit's children through `HEAD`. If the file is untracked
     (drafted but never committed), fall back to scanning uncommitted changes plus any
     commits the user explicitly identifies as the implementation work. Do not scan
     the entire repository history.
   - Focus on the **mutable sections**: `## Problem`, `## Goal`, `## Scope`,
     `## Intended Approach`, `## Design constraints`, `## Consequences`,
     `## Affected features`, `## Risks and mitigations`, `## Acceptance criteria`,
     `## Durable doc impact`. For `## Durable doc impact` specifically, verify the
     DDRs and `architecture.md` / tech-docs sections it names were actually
     created or updated during implementation, and that every referenced path
     exists — this section is highly drift-prone because the durable knowledge a
     tech-task drives lives on in exactly those docs.
     `## Open questions` and `## Dependencies` are handled by §3a and §4
     respectively; `## Origin` is provenance and is not edited here.

3. **Present the candidate list to the user for review and confirmation.** Each item
   shows the baseline text vs. what shipped, with a proposed edit. The user reviews,
   approves / edits / rejects items, and the skill applies the confirmed changes.
   If the candidate list is short (roughly ≤15 items), present it as a single batch.
   If it is longer, group by section and present batches sequentially — each batch
   independently approvable. If the user notes additional drifts during review that
   weren't on the list, add and confirm those too.

## 3a. Open-questions gate

After drift fixes are applied, scan `## Open questions` for unresolved `Q-N` items.

Present each item to the user and ask for one of:

- **Resolve** — delete the question; if the answer changes spec behavior, fold the
  resolution into the relevant section and add it to the drift list.
- **Defer** — keep the question as-is; the spec promotes with the question still open.
  Acceptable for non-blocking ambiguities about future enhancements.
- **Escalate** — block reconcile and request follow-up work before resuming.

Apply confirmed resolves before continuing. Deferred questions stay in the spec.

## Reference formatting

**Path anchor — applies to every link in the spec file.** All link paths written into
the tech-task file must be relative to the *directory containing that file*, not the
repository root. Method: count how many `../` steps reach the repo root from the
file's directory (call this N), then append the target's repo-root-relative path.

`docs/tech-tasks/proposed/T-XXX-slug.md` is 3 levels deep (N = 3):
- `docs/ddr/DDR-001.md` → `../../../ddr/DDR-001.md`
- `docs/features/implemented/F-001-slug/feature.md` → `../../../features/implemented/F-001-slug/feature.md`

After promotion to `docs/tech-tasks/implemented/T-XXX-slug.md`, the depth is the
same (still 3 levels), so no link rewrites are needed on the move.

## 4. Dependency status scan

If `## Dependencies` in the tech-task has `— pending` entries, scan each one before
committing:

- Acquire a per-task checkout of the downstream repo by calling
  `acquire-feature-repo <T-XXX-slug> <repo>` (via the Bash tool, running
  `skillforge-repos acquire-feature-repo <T-XXX-slug> <repo>`). The tech-task is
  the worktree holder, so its own `T-XXX` slug is the holder key — matching the
  `release-feature-repo <T-XXX-slug>` call in "Acceptance cleanup" below.
  See the `repo-resolution` rule.
- Search `docs/features/implemented/` in the downstream repo for a feature promoted
  from the referenced `B-XXX` stub. Match by finding a `## Promoted` section in
  `docs/features/backlog/promoted/B-XXX-*.md` that links to an implemented folder,
  or any `## Origin` in an implemented feature file that references the `B-XXX` ID.
- **If the dep has shipped:** rewrite the entry — all three parts together (a partial
  rewrite is an error):
  - Link target: `references/repos/<repo>/docs/features/backlog/B-XXX-<slug>.md`
    → `references/repos/<repo>/docs/features/implemented/F-XXX-<slug>/feature.md`
  - Link text: `B-XXX: <old-title>` → `F-XXX: <promoted-title>`
  - Annotation: `— pending` → `— implemented`
- **If the dep has not shipped:** leave the entry as `— pending`, surface the
  unresolved dependency to the user, and **refuse to proceed**. Reconciliation cannot
  continue until all `— pending` deps are resolved.

Include any dep rewrites in the phase-1 commit (§5).

## 5. Phase 1 commit — spec edits

Stage all confirmed drift fixes, open-question resolutions, and dependency rewrites.
Commit via the `git-commit` skill with message:

```
docs(tech-task/T-XXX): reconcile spec with implementation
```

If there are no edits (no drift, no open questions to resolve, no dep rewrites), skip
this commit and proceed directly to §6.

## 6. Phase 2 commit — promote to implemented

1. **Verify tracking.** Run `git ls-files --error-unmatch <path> 2>/dev/null`. If the
   file is git-tracked, use `git mv docs/tech-tasks/proposed/T-XXX-<slug>.md
   docs/tech-tasks/implemented/T-XXX-<slug>.md`. If untracked, use plain `mv` and then
   `git add docs/tech-tasks/implemented/T-XXX-<slug>.md`.

2. **Populate `## References`.** After the move, check session context for design docs,
   plan docs, DDRs, or other implementation artefacts created or referenced during this
   session. Only include documents within the same repository (relative paths, using the
   path anchor rule); skip documents from other repos and git-ignored files. If any
   candidates exist, add a `## References` section (or append to an existing one) in the
   promoted `docs/tech-tasks/implemented/T-XXX-<slug>.md` with links to each document,
   and stage the edit.

3. **Commit** via the `git-commit` skill with message:

   ```
   docs(tech-task/T-XXX): promote to implemented
   ```

   If no reference candidates exist, commit the move alone with the same message.

## 6a. Back-propagation to parent repos

Run immediately after the phase-2 commit.

**Entry condition.** If the tech-task's `## Origin` does not reference a `B-XXX` backlog
stub — e.g. it was defined from a free-form description — no parent repo holds a
`— pending` dep entry for this tech-task, so back-propagation is a no-op. Skip entirely.

**Identify the `B-XXX` stub.** Read the promoted tech-task's `## Origin` — the
"Promoted from backlog stub `B-XXX`" line carries the stub ID.

**Discover parent repos** that hold a `## Dependencies` reference to that `B-XXX` stub:

1. **Path-based discovery first.** Inspect this repo's filesystem path. If it matches
   `*/references/repos/<repo-name>/`, the directory two levels up is a parent repo
   candidate — use it directly.
2. **`references/repos/` scan second.** Check whether any repos under this repo's own
   `references/repos/` are parent repos (covers transitive chains).
3. **If no parent repo is found,** ask the user for the local path of the parent repo.

**For each parent repo located:**

1. Search all `## Dependencies` sections across the parent repo's `docs/features/` tree
   for an entry whose link target contains the `B-XXX` ID identified above.
2. For each match, apply the same three-part rewrite as §4 — link target, link text
   (`B-XXX` → `F-XXX` with promoted title), and annotation (`— pending` →
   `— implemented`). Never do a partial rewrite.
3. Confirm the target branch with the user (must be non-main), then commit the update
   in the parent repo via the `git-commit` skill with message:
   ```
   docs(tech-task/T-XXX): update dep status for <downstream-repo-name>/T-XXX
   ```

## Acceptance cleanup

After marking a tech-task implemented, do not release any feature worktrees
automatically — the reconcile commits are still local and unpushed, and releasing
now would discard work the user has not yet validated. Hand off to the user instead:

> Tech-task `<T-XXX-slug>` accepted. Before tearing down its worktrees:
> 1. Validate the reconcile changes.
> 2. Push the changes to remote.
> 3. Once pushed, invoke the `release-feature-repo` skill with just the tech-task
>    slug — `release-feature-repo <T-XXX-slug>` releases and prunes every repo
>    the tech-task holds.

`reconcile-tech-task` does not run `release-feature-repo` itself.

## Common mistakes

### Routing & pre-flight

| Mistake | Correct behavior |
| ------- | ---------------- |
| Running on a dirty working tree | Refuse to run. Ask the user to commit or stash first. The reconcile commits must contain only reconcile changes. |
| Handing a tech-task to `reconcile-feature` | Tech-tasks are single files; use `reconcile-tech-task`. `reconcile-feature` handles multi-file feature specs only. |

### Drift detection

| Mistake | Correct behavior |
| ------- | ---------------- |
| Scanning the entire repo history for drift | Scan only the **implementation range** — commits since the file was first added to git (`git log --diff-filter=A --format=%H -- <file> \| tail -1`), through `HEAD`. |
| Skipping drift detection when session context has the answer | Session context is the preferred source; present the known drifts as the candidate list for user confirmation. |
| Leaving `## Durable doc impact` out of the drift scan | It is a mutable section (§3.2). Verify the DDRs and `architecture.md` / tech-docs it names were actually created/updated and that the referenced paths exist; reconcile the section to the docs that really shipped. |

### Promotion

| Mistake | Correct behavior |
| ------- | ---------------- |
| Assuming `git mv` always works | Verify tracking with `git ls-files --error-unmatch <path> 2>/dev/null` first; fall back to plain `mv` + `git add` when untracked. |
| Skipping the `## References` population step (§6 step 2) | After the move, always check session context for in-repo artefacts before committing. If any exist, add them to `## References` in the same commit. |
| Writing any link path relative to the repo root instead of the file's directory | Apply the path anchor rule: count `../` steps to the repo root from the file's directory, then append the target's repo-root-relative path. |
| Skipping Phase 1 commit when there are no edits | Correct — if there is no drift, no open-question resolutions, and no dep rewrites, skip Phase 1 and go directly to Phase 2. |

### Open-questions gate

| Mistake | Correct behavior |
| ------- | ---------------- |
| Promoting without processing `## Open questions` | The gate (§3a) must classify every `Q-N` before the phase-2 commit. |
| Deleting deferred questions | Deferred questions stay in the spec — only resolved questions are removed. |

### Cross-repo deps

| Mistake | Correct behavior |
| ------- | ---------------- |
| Letting a `— pending` dep warn instead of hard-blocking | If any dep is `— pending` after the scan, refuse to proceed — do not offer the user a choice to continue. |
| Updating only the annotation or only the link target during a dep rewrite | All three parts must be rewritten together: link target, link text (ID + title), and annotation. |
| Committing dep rewrites in a separate commit from other phase-1 edits | Dep rewrites from §4 are included in the phase-1 commit (§5) — not a separate commit. |
| Running back-propagation (§6a) when the tech-task has no backlog-stub origin | If `## Origin` contains no `B-XXX` reference, skip §6a entirely — there is no stub ID to search for in parent repos. |
