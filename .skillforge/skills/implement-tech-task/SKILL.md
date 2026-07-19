---
name: implement-tech-task
type: skill
tags: [implementation, orchestration]
description: Use when an accepted tech-task spec (docs/tech-tasks/proposed/T-XXX-*.md) is ready to be turned into shipped code. Named entry-point that redirects to implement-feature, which handles tech-tasks natively.
argument-hint: "[tech-task title, or path to docs/tech-tasks/proposed/T-XXX-*.md]"
version: 1.0.0
compatibility: [copilot, claude]
---

## Overview

Named entry-point for tech-task implementation. `implement-feature` handles tech-tasks
natively — this skill exists for naming symmetry with `refine-tech-task` and
`reconcile-tech-task` so the full tech-task lifecycle is expressible without needing to
remember that tech-tasks pass through `implement-feature`.

This skill does **not** reimplement any orchestration. It transfers control to
`implement-feature` immediately with the same argument.

After implementation completes, use `reconcile-tech-task` to bring the spec in line with
what shipped and promote it to `docs/tech-tasks/implemented/`.

Part of the feature-spec lifecycle: see
`../refine-feature/references/lifecycle.md` for the full workflow map.

## Procedure

1. Transfer control to `implement-feature` with the same `$ARGUMENT`:
   - If `$ARGUMENT` is supplied (a tech-task title or path), pass it through:
     invoke `implement-feature $ARGUMENT`.
   - If `$ARGUMENT` is omitted, invoke `implement-feature` with no argument;
     `implement-feature` will infer the working tech-task from session context or ask.
2. Follow `implement-feature` from that point forward. Do not duplicate, re-order,
   or gate any of its steps here.

If the input turns out to be a feature spec (not a tech-task), redirect the user to
`implement-feature` directly — `implement-feature` handles both, and no further
routing is needed.
