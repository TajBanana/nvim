---
name: verify-feature-deps
type: skill
tags: [documentation, specs]
description: Use before implementing a feature spec to check that all cross-repo backlog dependencies listed in `## Dependencies` have shipped in their downstream repos. Read-only — never writes files.
argument-hint: "[feature title or path to docs/features/proposed/F-XXX-*/]"
version: 1.2.2
compatibility: [copilot, claude]
---

## Overview

Read-only pre-implementation check. Reads the `## Dependencies` section of a
feature's `feature.md`, resolves each downstream repo, and reports whether
each dep has shipped (i.e. exists under `docs/features/implemented/` in the
downstream repo). Never writes to any file.

Part of the feature-spec lifecycle: see
`../refine-feature/references/lifecycle.md` for the full workflow map.

## When to use

- The user is about to begin implementing a feature spec and wants to confirm
  that all cross-repo dependencies have shipped.
- Any time the user wants a dep status snapshot without triggering a reconcile.

## Procedure

**Pre-flight directory check.** If `docs/feature/` (singular) exists instead of `docs/features/`, stop and recommend renaming before proceeding. If the user agrees: run `git mv docs/feature docs/features` (or plain `mv` + `git add docs/features` if untracked — verify with `git ls-files --error-unmatch docs/feature 2>/dev/null`). Commit immediately via the `git-commit` skill with message `docs: rename docs/feature to docs/features`, then continue using `docs/features/`. If the user declines, continue using `docs/feature/` as-is.

The user provides a feature title or path as `$ARGUMENT`. If omitted, infer
from session context; if ambiguous, ask.

1. **Read `## Dependencies`** from the feature's `feature.md`. If the section
   is absent or has no entries, report: "No cross-repo dependencies — clear to
   proceed." Exit.

2. **For each entry**, acquire a per-feature checkout of the downstream repo by
   calling `acquire-feature-repo <F-XXX-slug> <repo>` (via the Bash tool, running
   `skillforge-repos acquire-feature-repo <F-XXX-slug> <repo>`), then
   read dep state through the resulting `references/repos/<repo>/...` link. See
   the `repo-resolution` rule. Then:
   - **`— pending` entries**: search `docs/features/implemented/` in the
     downstream repo for a feature promoted from the referenced `B-XXX` stub.
     Match by finding a `## Promoted` section in
     `docs/features/backlog/promoted/B-XXX-*.md` that links to an implemented
     folder, or any `## Origin` in an implemented feature file that references
     the `B-XXX` ID.
     - **Promoted and implemented**: report as `implemented — sync needed`
       (the parent `## Dependencies` still shows `— pending`; suggest running
       `reconcile-feature` to update it).
     - **Not yet implemented**: report as `pending`. Warn the user that the
       dep has not shipped.
   - **`— implemented` entries**: confirm the linked path resolves to an
     existing file under `docs/features/implemented/` in the downstream repo.
     Report as `clear`. If the path is missing, report as `broken link` and
     ask the user to investigate.

3. **Summary report**:

   ```
   Dependency status for F-XXX <feature-title>:

   ✓ clear         [F-007: Payments Webhook Support] — implemented and synced
   ⚠ sync needed   [B-003: Auth Token Refresh] — implemented in downstream but parent still shows pending; run reconcile-feature
   ✗ pending       [B-012: Notification Templates] — not yet implemented in notifications-service
   ```

   Warn prominently if any deps are `pending`. The user decides whether to
   proceed with implementation anyway.

## Common mistakes

| Mistake                                             | Correct behavior                                                                                 |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Writing or updating any file                        | `verify-feature-deps` is strictly read-only — never edit `feature.md` or any downstream file     |
| Updating `— pending` to `— implemented` directly    | Dep status updates are `reconcile-feature`'s responsibility; only report here                    |
| Blocking implementation when deps are pending       | Warn and summarise; the user decides whether to proceed                                          |
| Cloning repos directly instead of using the resolver | Always call `acquire-feature-repo <F-XXX-slug> <repo>`; see the `repo-resolution` rule |
