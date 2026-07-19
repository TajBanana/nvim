---
name: release-feature-repo
type: skill
tags: [git, infrastructure]
description: Symmetric counterpart of acquire-feature-repo. Releases the per-repo lock and symlink and prunes the feature worktree. With no <repo>, acts on every repo the feature holds. Prompts before discarding uncommitted/unpushed work.
argument-hint: "<F-XXX-slug> [<repo>]"
version: 2.0.0
compatibility: [copilot, claude]
---

## Overview

Cleanly releases a feature's worktree(s): drops the per-repo lock and the
`references/repos/<repo>` symlink, then prunes the worktree on disk. Verifies
that each per-repo lock actually holds the named feature; refuses with a clear
error if not.

## How to invoke

Use the Bash tool:

    skillforge-repos release-feature-repo <F-XXX-slug> <repo>   # one repo
    skillforge-repos release-feature-repo <F-XXX-slug>          # every repo held

## Behavior

The worktree is **always** pruned (`git worktree remove`) after dropping the
lock and symlink. If a worktree has uncommitted or unpushed changes, the command
prompts *"Pruning will lose them. Continue? [y/N]"* and aborts that repo on `n`.
So:

- **Push first**, and the prune runs cleanly with no prompt.
- **Confirm the prompt** to deliberately drop unwanted changes.

The shared cache and any read-only worktrees are never touched.

## Deriving repos

When `<repo>` is omitted, the command scans the feature-repo locks and releases
every repo the feature currently holds. Each repo is pruned under its own guard,
so a clean repo is removed even if another still has unpushed work (which prompts
independently). This is the normal acceptance teardown: after a feature is
validated and pushed, `release-feature-repo <F-XXX-slug>` cleans up all of its
worktrees in one call.

## Common mistakes

| Mistake | What to do instead |
|---------|--------------------|
| Releasing before pushing accepted work | Push first; otherwise the prune prompt warns and you risk dropping commits. |
| Removing the lock or symlink manually | Use this skill so the prune semantics stay consistent. |
