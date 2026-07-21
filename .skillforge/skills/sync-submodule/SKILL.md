---
name: sync-submodule
type: skill
tags: [git, submodule, infrastructure]
description: Use to integrate component work back into a monorepo. Pushes a submodule component's branch to the component remote and re-pins the parent gitlink in one step, optionally rebasing onto the component's parent (default) branch first. Delegates to developer-tools' submodule-push.sh; the heavy git lifting lives there.
argument-hint: "<holder-slug> <submodule-path> [--worktree <path>] [--rebase] [--onto <ref>] [--force]"
version: 1.2.0
compatibility: [copilot, claude]
---

## Overview

The integration step of the submodule workflow. It takes the branch currently
checked out in the submodule directory (where the component work was committed),
**pushes it to the component remote, and re-pins the monorepo's gitlink** to the
pushed tip — in one command. You then commit the staged gitlink with `git-commit`.

Under the hood it delegates to developer-tools' `bin/submodule-push.sh` (resolved
via `$DEV_TOOLS_HOME`), which owns the push, the optional rebase, and the gitlink
re-pin. `DEV_TOOLS_HOME` must point at your developer-tools checkout (the standard
developer-environment setup wires this up); the command errors clearly if it is
unset.

## When to use

- After editing a component directly in its submodule directory (with `git -C`),
  to push the work and record the new commit in the monorepo.
- To bring a component branch up to date with its parent (default) branch before
  integrating — pass `--rebase` (see below).

## How to invoke

    skillforge-repos sync-submodule <holder-slug> <submodule-path>

On success the gitlink and `.gitmodules` are staged. **Commit them with the
`git-commit` skill** (`chore(submodule): bump <name> to <short-sha> (<branch>)`).
You do **not** need to push the branch first — the command pushes it for you.

## Rebasing onto the parent branch (`--rebase`)

`--rebase` rebases the component branch onto its **parent branch** (the component
remote's default branch, e.g. `main`) before pushing, then force-pushes the
rebased branch with `--force-with-lease`. Override the base with `--onto <ref>`
(which implies `--rebase`).

Because rebasing rewrites the branch and force-pushes it, **confirm with the user
before running `--rebase`**. Tell them plainly: this force-pushes `<branch>` to the
component remote with `--force-with-lease`, overwriting its history — anyone who
based work on the old tip must reset. If they decline, do the rebase manually (or
skip it) per `references/rebase-squash-recipe.md`.

### When the rebase hits conflicts

`submodule-push.sh` never auto-resolves: on a conflict it aborts the rebase
(restoring the branch, pushing nothing, leaving the gitlink untouched) and exits
non-zero. **Try to resolve the conflicts yourself** before giving up:

1. Re-create the rebase in the worktree and resolve each conflict, preserving both
   the parent-branch change and the component change — follow the conflict
   procedure in `references/rebase-squash-recipe.md` exactly.
2. After a clean resolution, integrate the rebased branch with
   `skillforge-repos sync-submodule <holder-slug> <submodule-path> --force`
   (force-pushes the already-rewritten branch and re-pins), then commit the gitlink.
3. Only surface the conflict to the user if it is genuinely ambiguous or unsafe to
   resolve — name the files and the decision.

## Required skills

- **`git-commit`** — commits the staged gitlink + `.gitmodules`.
- **`squash-commits`** _(optional)_ — squash the component branch before syncing;
  see `references/rebase-squash-recipe.md`.

## Common mistakes

| Mistake | What to do instead |
|---------|--------------------|
| Committing gitlink changes without first committing in the submodule | Commit and push in the submodule first, then run sync-submodule. |
| Force-pushing via `--rebase`/`--force` without telling the user | Confirm first — it rewrites and overwrites the remote branch history. |
| Amending the gitlink commit to also change component files | Component changes belong in the component repo, not the gitlink commit. |
| Expecting `--rebase` to auto-resolve conflicts | It aborts on conflict; resolve in the worktree, then sync with `--force`. |
