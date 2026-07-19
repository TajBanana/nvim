---
name: acquire-feature-repo
type: skill
tags: [git, infrastructure]
description: Use when a feature-mode skill needs a writable per-feature worktree of a dependent repo. Acquires the per-repo lock, creates the worktree on a feature-scoped branch, and points references/repos/<repo> at it via an atomic symlink swap. Refuses if another feature already holds the repo.
argument-hint: "<F-XXX-slug> <repo>"
version: 1.0.4
compatibility: [copilot, claude]
---

## Overview

Wraps `resolve-repo-worktree --branch` with the feature-scoped lifecycle: the
per-repo lock at `./.skillforge/feature-repo-locks/<repo>`, the
`./references/repos/<repo>` symlink, and `.gitignore` maintenance. Everything
runs under `flock .skillforge/registry.lock` so concurrent invocations don't
race.

## When to use

- Always, when a feature-mode skill (`refine-feature`,
  `change-feature`, `verify-feature-deps`, `reconcile-feature`) needs to read
  or write a dependent repo.

## How to invoke

Use the Bash tool:

    skillforge-repos acquire-feature-repo <F-XXX-slug> <repo> [--url <git-url>]

The command prints the worktree path on stdout. After it returns, the link
`./references/repos/<repo>` resolves into that worktree, so any documented
`references/repos/<repo>/...` link works.

Pass `--url <git-url>` when `<repo>` is not yet in `references/repos.yaml`; the
resolver registers it before cloning. For a brand-new local sub-component with no
remote yet, pass `--url '<pending>'`. There is no interactive prompt or stdin
input — an unregistered repo without `--url` is an error. Passing a `--url` that
conflicts with an already-registered URL is also an error (reconcile the registry,
or use `attach-remote` to wire a remote onto a `<pending>` sub-component).

## On lock conflict

A lock conflict always means another feature still holds the repo — the lock is
written only by this skill and cleared only by `release-feature-repo`. The
command exits non-zero and diagnoses the holder's worktree to tailor its advice:

- **Holder looks finished and pushed** (clean worktree) → they likely forgot to
  release it. Advice: `release-feature-repo <holder>` to release all of its
  repos, then retry.
- **Holder has uncommitted or unpushed work** → it may still be in progress.
  Advice: inspect the worktree, push or drop the changes, then
  `release-feature-repo <holder> <repo>` to free this repo, and retry.
- **Holder's worktree is gone** → a stale lock. Advice:
  `release-feature-repo <holder> <repo>` to clear it, then retry.

Surface the message to the user and let them investigate and clean up; never
attempt to force the lock.

## Common mistakes

| Mistake | What to do instead |
|---------|--------------------|
| Creating the symlink, lock file, or worktree by hand | Use this skill. |
| Ignoring a lock-conflict error and retrying | The conflict is real. Investigate the holder and release it with `release-feature-repo` before retrying. |
