---
name: resolve-repo-worktree
type: skill
tags: [git, infrastructure]
description: Use to create or attach a git worktree for a dependent or reference repository. Modes are --branch (for feature work) or --ref (for read-only access at a specific tag/commit). Lock-unaware; callers that need feature scoping should use acquire-feature-repo instead.
argument-hint: "<repo> --branch <name> [--base <ref>] --at <path>  |  <repo> --ref <ref> [--at <path>] [--force-refresh]"
version: 1.0.8
compatibility: [copilot, claude]
---

## Overview

Creates or attaches a git worktree from the shared bare cache at
`${SKILLFORGE_HOME}/references/repos/<repo>.git/`. Initializes the cache on
first use. If `<repo>` is not yet in `references/repos.yaml`, supply its git URL
with `--url <git-url>` and the resolver registers it (there is no interactive
prompt or stdin input).

See the `repo-resolution` rule for the full model
(directory layout, registry schema, public contract).

## When to use

- Read-only consumers (`architecture-context`, `resolve-artifact-source`) that
  need source at a specific ref.
- Internal use by `acquire-feature-repo`.

Do **not** use directly from feature-mode consumer skills. They should call
`acquire-feature-repo` so locks and symlinks are managed correctly.

## How to invoke

Use the Bash tool to run:

    skillforge-repos resolve-repo-worktree <args>

The command prints the worktree path on stdout. Capture and use it as the
working directory for subsequent reads.

### Branch mode

    skillforge-repos resolve-repo-worktree \
      <repo> --branch <branch-name> [--base <base-ref>] [--url <git-url>] --at <path>

`--base` defaults to `origin/<default-branch>`. If the branch already exists,
the worktree attaches to it instead of recreating.

**Cache freshness:** branch mode always fetches from the remote. For a **new**
worktree the bare-cache branch ref is fast-forwarded before creation. For an
**existing** worktree the worktree itself is fast-forwarded via `merge --ff-only`.
If the worktree has local commits ahead of or diverged from the remote, the
fast-forward is skipped and a **warning is printed to stderr** — the worktree is
left as-is, but treat this as a signal that the worktree is not at the remote tip
and verify its base before proceeding.

### Ref mode

    skillforge-repos resolve-repo-worktree \
      <repo> --ref <tag-or-commit-or-branch> [--at <path>] [--url <git-url>] [--force-refresh]

Path defaults to
`${SKILLFORGE_WORKTREE_DIR}/read-only-worktrees/<repo>/<sanitized-ref>`. Use
`--force-refresh` to recreate a corrupted worktree.

### Registering a URL

Pass `--url <git-url>` when `<repo>` is not yet in `references/repos.yaml`; the
resolver records it before cloning. If `<repo>` is already registered with a
different URL, the command errors rather than overwriting it — reconcile the
registry (or use `attach-remote` for a `<pending>` sub-component).

## Common mistakes

| Mistake | What to do instead |
|---------|--------------------|
| Calling this from `refine-feature` / etc. directly | Call `acquire-feature-repo <feature-slug> <repo>` instead. |
| Editing files in a `--ref` worktree | Ref worktrees are detached and read-only by convention. Use `--branch` if you need to write. |
| Hard-coding the worktree path in another skill | Use the path the command prints; do not compute it yourself. |
