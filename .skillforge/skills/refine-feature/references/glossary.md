# Glossary

Shared definitions for terms used across the feature-spec skills. When a
skill uses one of these terms without further explanation, this file is the
authoritative source.

## assembly constraint

In a repo whose purpose is assembly (e.g. a helmfile or orchestration layer),
the repo cannot implement service logic directly. Any capability requiring new
or changed service behaviour must be expressed as a backlog stub in the relevant
service repo — not as an in-scope story in the assembly spec. An assembly
feature's stories describe orchestration-level behaviour only.

## mono-repo constraint

In a submodule mono-repo, work that belongs to a specific submodule must become a
backlog stub authored directly in that component directory (checked out with
`git -C`) and integrated by bumping the gitlink — it is not drafted as in-scope
content in the root. Cross-cutting logic already present in the root (e.g. an integration
contract that spans submodules) is in-scope at root.

## feature-mode skills

The skills that operate on feature specs end-to-end:
`refine-feature`, `change-feature`, `reconcile-feature`, and
`verify-feature-deps`. Contrasted with infrastructure skills
(`acquire-feature-repo`, `release-feature-repo`, `attach-remote`)
that manage the underlying repo mechanics.

## implementation range

The commit range `reconcile-feature` scans to surface drift candidates. It
starts at the commit that first added the proposed folder to git (found via
`git log --diff-filter=A --format=%H -- <folder> | tail -1`) and ends at
`HEAD`. Scanning the full repo history instead of this range is a common
mistake — it produces false positives from earlier features.

## staging tree

A `proposed/F-XXX-<slug>/` directory that contains only a `changes/`
subdirectory and no `feature.md`. Created by `change-feature` when producing
a delta spec for a feature already in `implemented/`. `reconcile-feature`
recognises this shape and enters change mode automatically. A proposed folder
that has `feature.md` is a new-feature draft, not a staging tree.

## tech-task

A one-time spec for a purely technical change (no externally-observable
behavior change for any user or operator), authored by `refine-tech-task` as
a single file under `docs/tech-tasks/proposed/T-XXX-<slug>.md`. Drives
DDR/architecture updates, is reviewed as-built, then retired to
`docs/tech-tasks/implemented/`. Not a feature spec; not a durable design
artifact. See `classification.md`.

## volumetrics

The non-functional shape of an input or data flow: peak / maximum arrival rate,
per-item and batch size, frequency or cadence, and expected growth over time.
Captured per input in a use case's `## Data and contracts → Inputs` and elicited
by the requirements interview. A tech-task's parity interview reuses the same
vocabulary to pin the load profile that must be preserved.
