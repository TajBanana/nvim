---
name: resolve-artifact-source
type: skill
tags: [git, infrastructure, artifacts]
description: Given typed artifact coordinates (container | maven | npm | pypi), return a read-only worktree path of the source repo at the matching version. Internal artifacts only; consults references/repos.yaml.
argument-hint: "--type <container|maven|npm|pypi> --coord <coord> [--ref <override>]"
version: 1.0.2
compatibility: [copilot, claude]
---

## Overview

Looks up the producing repo for an artifact in the registry's `artifacts` list
(exact match on `type`, glob on `coordinate`). Derives the git ref from the
coordinate's version, applying the universal `v`-prefixed-with-fallback
convention. Delegates to `resolve-repo-worktree --ref` for the actual checkout.

## When to use

- Any skill that has artifact coordinates and needs the source.

## How to invoke

Use the Bash tool:

    skillforge-repos resolve-artifact-source --type <type> --coord <coord> [--ref <override>]

Coord forms:

| Type | Coord |
|---|---|
| `container` | `<registry-path>:<tag>` |
| `maven` | `<group>:<artifact>:<version>` |
| `npm` | `<package>@<version>` |
| `pypi` | `<package>==<version>` |

The command prints the worktree path on stdout. If no entry matches in
`references/repos.yaml`, the command exits non-zero with instructions to add
the mapping.

## Common mistakes

| Mistake | What to do instead |
|---------|--------------------|
| Using this for external (third-party) artifacts | Out of scope. |
| Hard-coding the repo name and calling `resolve-repo-worktree` directly | If you have coordinates, this skill is the right layer. |
| Editing files in a returned read-only worktree | Read-only worktrees are detached — edits don't persist meaningfully. |
