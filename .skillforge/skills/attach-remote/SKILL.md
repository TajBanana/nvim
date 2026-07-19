---
name: attach-remote
type: skill
tags: [git, infrastructure]
description: Use when a locally-created sub-component has a `<pending>` registry URL, or when converting a `<pending>` component into a submodule once its remote exists.
argument-hint: "<F-XXX-slug> <repo> --url <git-url>  |  <subdir> --url <git-url>"
version: 1.4.0
compatibility: [copilot, claude]
---

## Overview

When a new sub-component is created locally (option (b) of the post-acceptance
dependency step — see `../refine-feature/references/post-acceptance-dep-step.md`),
its `references/repos.yaml` entry holds the placeholder URL `<pending>` and its
worktree sits on an orphan branch with no remote. Once the user has created the
real repository on their host, this skill connects the two: it registers the URL,
sets `origin` on the shared cache, and rebases the local `feature/<F-XXX-slug>`
branch onto the remote's default branch.

## When to use

- For a sub-component whose registry URL is still `<pending>` and which is
  currently held by `<F-XXX-slug>` (acquired via `acquire-feature-repo`).
- For a `<pending>` sub-component that should become a submodule once its
  remote has been created and can be wired up.
- After the user has created the remote repository and can give you its URL.

## How to invoke

Use the Bash tool:

    skillforge-repos attach-remote <F-XXX-slug> <repo> --url <git-url>

## Behaviour

1. Verifies the feature lock for `<repo>` is held by `<F-XXX-slug>` and that the
   registry URL is `<pending>` — otherwise it aborts (a repo that already has a
   real remote is not eligible).
2. Sets `origin` on the cache to `<git-url>`, fetches, and flips the registry
   entry's URL from `<pending>` to `<git-url>`.
3. **Empty remote** (no commits yet): nothing to rebase. The command prints the
   commit-and-push next steps and exits 0.
4. **Non-empty remote:** requires the worktree to be clean (commit the backlog
   stub first). It then rebases the local branch onto `origin/<default>`. The
   local orphan history and the remote share no base, so all local commits replay
   on top of the remote. On conflict it stops, leaves the worktree mid-rebase, and
   prints the `git rebase --continue` / `git rebase --abort` instructions; resolve
   the conflicts with the user, then finish the rebase.

## Submodule variant

Use this variant to turn a locally-created `<pending>` sub-component into a real
submodule once its remote exists.

**Precondition:** the sub-component was created via the dep step as a
`<pending>` local repo and now has a remote with at least one commit.

1. Wire the remote and rebase the local work onto it:
   ```
   skillforge-repos attach-remote <holder-slug> <component-name> --url <git-url>
   ```
   Push the rebased branch as the command instructs.
2. Add it to the monorepo as a submodule at the agreed path:
   ```
   git submodule add <git-url> <submodule-path>
   ```
   (For a local-path remote in tests, prefix `-c protocol.file.allow=always`.)
3. Commit the `.gitmodules` + gitlink in the monorepo via `git-commit`.

## Common mistakes

| Mistake | What to do instead |
|---------|--------------------|
| Editing `references/repos.yaml` or the cache remote by hand | Use this skill. |
| Running it before the user has created the remote | Wait until you have a real URL; a `<pending>` repo stays local until then. |
| Forcing past a rebase conflict | Resolve conflicts with the user, then `git rebase --continue`. |
