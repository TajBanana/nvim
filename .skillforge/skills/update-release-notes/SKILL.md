---
name: update-release-notes
type: skill
tags: [documentation]
description: Use when user is ready to merge branch to create a new release and asks to update release notes based on unmerged branch commits.
version: 1.7.0
compatibility: [copilot, claude]
---

## Overview

Update the repository's canonical release notes file from commits that are unique to
the current branch. Always fetch remote tags before computing the next release
version. Derive the next version from the latest semver tag plus the highest-impact
conventional commit prefix found in the branch's unmerged commits.

The canonical release-notes file is the top-level `RELEASE_NOTES.md`. Update it when
it exists; **create it** when it does not, seeding it with this release's section. Do
**not** migrate, copy, or modify release-notes content that already lives in another
document (e.g. an existing `CHANGELOG.md`) — leave that history where it is. New
releases are recorded in `RELEASE_NOTES.md`.

**Do not use when:** there are no unmerged commits on the branch, or the user has not
asked to prepare a release note.

## Procedure

Use the Bash tool for the git steps below.

1.  Refresh remote refs and tags before deriving any version information:

         git fetch --prune --tags origin

2.  Determine the default branch from `origin/HEAD`. If that ref is unavailable,
    fall back to `main`, then `master`.

3.  Compute the merge-base between `HEAD` and the remote default branch. Treat the
    unmerged commit range as:

         <merge-base>..HEAD

4.  Collect the branch-only commits with no merges. At minimum, inspect the commit
    subjects. If you need to confirm a breaking change, inspect the full commit text.

5.  Derive the latest semver tag from the fetched tags. Accept `vX.Y.Z` and `X.Y.Z`.
    Sort by semantic version, not lexicographically.

If there are no unmerged commits in the range, do not edit the release notes. Report
that there is nothing new to release.

When there **are** commits to release but the top-level `RELEASE_NOTES.md` does not
exist, create it and write this release's section into it. Do not read, pull in, or
edit release notes kept in any other file — an existing `CHANGELOG.md` or similar is
left untouched.

## Version derivation rules

Start from the latest fetched semver tag and preserve its prefix style. For example,
if the latest tag is `v1.10.0`, emit `v1.11.0` rather than `1.11.0`.

**Version source is git tags only.** Only git tags represent shipped versions. Do
not use version numbers already present in the release notes file to derive the
next version — they are not authoritative.

**Future-version sections are mistakes.** After computing the derived version
(tag + bump), scan the release notes file for any sections whose version number is
higher than the derived version. These are almost certainly errors — version numbers
written speculatively during development. Present each one to the user:

> Found section `## vX.Y.Z` which is higher than the derived next version `## vA.B.C`.
> This looks like a mistaken entry. Merge its content into `## vA.B.C` and remove
> the `## vX.Y.Z` section, or keep it as-is?

Default recommendation: merge and remove. Apply the user's choice before writing
any new content.

If the derived version matches a section already in the notes, update that section
in place rather than appending a duplicate.

Determine the bump by the highest-precedence conventional commit prefix found in the
unmerged commit subjects:

- Major: any subject with a breaking marker, such as `feat!:` or `fix(api)!:`
- Minor: any `feat:` subject when no breaking marker is present
- Patch: any recognized non-feature conventional subject, such as `fix:`, `perf:`,
  `refactor:`, `docs:`, `build:`, `ci:`, `chore:`, `style:`, or `test:`

When multiple commits are present, use the highest bump required across the range.

If any commit subject in the release range is not a recognizable conventional commit,
stop and ask the user whether to:

- normalize the commit subjects first, or
- treat the non-conventional commits as patch-level changes

If no semver tag exists yet, ask the user which initial version to seed before
editing release notes. Do not invent an initial version silently.

## Release notes content

### Release notes are not a change log

A **change log** is an exhaustive, developer-facing record of every commit, written
for someone tracing history. **Release notes** are a curated, user-facing narrative
written for someone upgrading from the previous version. They answer three questions:

- **What can I now do** that I couldn't before?
- **What changed** that might affect how I work?
- **What do I need to update** in my workflow or configuration?

Do not transcribe commit subjects 1:1 into release notes. The commit log is your raw
material, not your output.

### Write for the upgrading user

Before writing each bullet, ask: *"Would a user coming from the previous version care
about this?"* If the answer is no — the commit is internal wiring, plumbing, or a
quality tweak invisible to users — omit it or fold it into the parent capability it
supports.

**Synthesize multiple commits into the user-visible capability they collectively
deliver.** When several commits (a new file, a symlink, a description tweak) together
ship one new feature, write one entry describing that feature — not three entries
listing each implementation step.

**Anti-pattern — commit transcription (wrong):**

```
- Add update-release-notes skill as a repository symlink   ← internal wiring, no user value
- Adjust update-release-notes skill description            ← internal tweak, no user value
- Improve skill clarity and CSO compliance                 ← internal quality, no user value
```

**Correct — capability synthesis:**

```
- New `update-release-notes` skill: generates a versioned release notes entry from
  your branch's commits, deriving the semver bump from conventional commit prefixes
  automatically. Invoke with `/update-release-notes`.
```

All three commits above were implementation steps toward one user-visible capability.
They collapse to a single entry describing what the user can now do.

### Maintenance section: write for the contributing developer

The **Maintenance** section has a different audience: the developer who was working
on or contributing to the previous version. They want to know about changes that
affect how they build, test, or extend the project — dependency updates, CI pipeline
changes, build tooling, or refactors that shift internal structure.

Apply the same synthesis rule, but ask: *"Would a developer picking up this codebase
from the previous version care about this?"* Internal bookkeeping with no impact on
the development workflow (a symlink added for wiring, a description tweak) still
doesn't belong.

### Collecting and organizing entries

Create or update one section for the derived release version and today's date.
If that version section already exists, update it in place instead of appending a
duplicate section.

Use only the unmerged branch commits in the computed range. Do not include merge
commits. Group related commits when they deliver one coherent capability.

Unless the repository already has a stronger house style, render the release notes
section from this template and replace every placeholder before finishing:

```md
## {{RELEASE_VERSION}} - {{RELEASE_DATE}}

### Breaking Changes

- {{breaking_change_summary}}

### Features

- {{feature_summary}}

### Fixes

- {{fix_summary}}

### Documentation

- {{documentation_summary}}

### Maintenance

- {{maintenance_summary}}
```

Template rules:

- Replace `{{RELEASE_VERSION}}` with the derived semver for this branch.
- Replace `{{RELEASE_DATE}}` with today's date in `YYYY-MM-DD` format.
- Keep only sections that have at least one concrete entry; omit the rest.
- Replace each placeholder bullet with one or more real bullets. Never leave
  template markers in the final file.

Section placement guide:

| Section          | Include                                                                                                       | Exclude                                                            |
| ---------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| Breaking Changes | Consumer-action items: removed behavior, incompatible API changes, changed defaults, data/contract migrations | Ordinary enhancements, backward-compatible fixes                   |
| Features         | Net-new user-facing capabilities or meaningful expansions of existing behavior                                | Internal refactors, dependency bumps, pure documentation edits     |
| Fixes            | Bug fixes, regressions, reliability corrections, behavior repairs                                             | Planned enhancements, non-behavioral maintenance                   |
| Documentation    | Doc updates that materially improve setup, usage, troubleshooting, or reference accuracy                      | Code-only changes with no documentation update                     |
| Maintenance      | CI, build, tooling, dependency updates, refactors with no user-visible behavior change                        | User-visible features, bug fixes, standalone documentation changes |

Keep the notes factual and user-facing. Group related commits when that improves
readability, but do not hide materially distinct changes.

## Validation

After updating the release notes:

1. Re-check that every entry comes from the unmerged commit range.
2. Re-check that the computed version matches the highest conventional-commit bump.
3. Review the diff for the release-notes file before declaring the task complete.
4. For each bullet in Features / Fixes / Documentation / Breaking Changes, ask:
   *"Would a user upgrading from the previous version care about this?"*
   For Maintenance bullets, ask: *"Would a developer contributing to or building on
   this project care about this?"* Remove or fold any bullet that answers "no".
