---
name: squash-commits
type: skill
tags: [git]
description: Use when a branch contains WIP, checkpoint, fixup, review-addressing, or superseded commits that should be consolidated into reviewable units before opening a PR or merging.
version: 1.8.0
compatibility: [copilot, claude]
---

## Overview

Review the current branch's commit history, including commits that have already been
pushed to its remote upstream, and use an interactive rebase to squash commits that
belong together. Reword the resulting commit messages so each squashed commit describes
one coherent change.

This skill rewrites history. Use it only on the current branch, never on the
repository's resolved default branch, and never on shared history that the user has
not agreed to rewrite.

## When to use

- The branch contains many small checkpoint commits that should become a smaller set of
  reviewable commits.
- Multiple commits clearly belong to one change and the final commit message should
  describe the grouped result rather than the intermediate steps.
- The user wants to clean up branch history before merge or before opening a PR.

## Do not use when

- The branch history is already clean and each commit is independently reviewable.
- The branch has merge commits that must be preserved as-is.
- The branch is shared and the user has not agreed to a history rewrite.

## Preconditions

Before rebasing, verify all of the following:

1. The current branch is not the repository's resolved default branch.
2. The worktree is clean, or the user has explicitly agreed to stash or commit pending
   changes first.
3. The branch's upstream is known, if one exists.
4. The branch's intended merge target is known.
5. The user understands that rewriting already-pushed commits requires a force push.
6. Any commit in the rebase range that carries a branch-review git note is
   identified. List note-bearing commits with:

       git notes --ref=refs/notes/skillforge/branch-reviews list | awk '{print $2}'

   Intersect that set with the `<merge-base>..HEAD` range. These commits, and
   every commit before them, are **frozen** — see the review-note rule under
   "Commit grouping rules".

If the worktree is dirty, stop and ask the user whether to commit, stash, or abort.
Do not begin the rebase with uncommitted changes unless the user explicitly requests it.

## Procedure

Three constraints apply that are not obvious from standard git knowledge:

1. **Fetch before computing the merge base.** Run `git fetch --prune origin` first so
   remote ref decisions are not based on a stale local view.

2. **Compute the range from the merge base, not the upstream ref.** Use
   `<merge-base>..HEAD` against the intended merge target, not the branch's push
   upstream. These are often the same but are not always the same — do not assume.

3. **Edit the rebase todo file non-interactively.** Agents cannot use an interactive
   terminal UI. Automate the todo list by editing the rebase todo file directly from
   the shell.

If grouping is ambiguous, stop and ask the user instead of guessing.

## Commit grouping rules

Use these rules when deciding what to squash:

- Squash checkpoint, WIP, typo-fix, follow-up, and review-addressing commits into the
  commit they refine.
- Squash implementation-detail commits together when they only make sense as one user-
  visible or reviewer-visible change.
- Keep commits separate when they represent distinct features, fixes, refactors, or
  documentation updates that would be easier to review independently.
- Prefer a few well-scoped commits over one giant commit.
- **Never rewrite a commit that carries a branch-review git note**
  (`refs/notes/skillforge/branch-reviews`), or any commit before it. These notes
  are keyed to a commit SHA and record a completed review; rebasing re-SHAs every
  commit from the first rewritten one onward, so squashing, rewording, or
  reordering a note-bearing commit — or rewriting anything before it — orphans the
  note. Only squash commits strictly after the last note-bearing commit. If the
  desired grouping would require rewriting at or before one, stop and ask the user
  rather than silently dropping the note. (The `review-branch` skill squashes
  before it writes its note, so this rule does not impede a review's own cleanup.)

## Rewording rules

After squashing, rewrite the commit subject and body so they describe the final grouped
change rather than the intermediate history.

Follow the conventions in the repository's `git-commit` skill when rewriting any
squashed commit. At minimum, the rewritten message must use a Conventional Commits
subject and include any required body content or traceability context from that skill.

- Use a clear, imperative subject.
- Summarize the resulting behavior or intent, not the fact that commits were squashed.
- Remove references to temporary checkpoints such as "fix review", "wip", or "part 2".
- Preserve important context that a reviewer needs, including scope and rationale.
- Include plan and task references from all squashed commits into the body of
  the resulting commit. Plan/task references (e.g., `[2026-05-29-plan.md:Task 3]`)
  are traceability, not temporary checkpoints — do not strip them. They can be embedded
  in the body and need not only be listed at the end.

## Force-push rules

After the rebase, compare the rewritten branch against its upstream remote branch when
an upstream exists.

- If no upstream branch exists yet, no force push is needed. Confirm the target remote
  with the user and suggest a first push that sets upstream tracking.
- If no rewritten commit has been pushed before, a normal push is sufficient.
- If any rewritten commit already exists on the upstream remote branch, warn the user
  that a force push is required before pushing.
- When a force push is required, prefer:

      git push --force-with-lease

  Do not recommend plain `--force` unless the user explicitly asks for it.

When warning about a force push, explain all of the following:

- collaborators with the old history will need to rebase, reset, or re-clone before
  continuing work
- branch protection rules may reject the push
- open PR review context may shift because old commit SHAs disappear
- a stale local view of the remote can make even `--force-with-lease` fail until refs
  are fetched again

If the branch appears to be shared by other contributors and the rewrite risk is high,
pause and ask the user to confirm before suggesting the final push command.

## Validation

After the rebase completes:

1. Review the new oldest-first commit list for the branch-only range.
2. Confirm each remaining commit is coherent and that unrelated changes were not folded
   together.
3. Confirm rewritten commit messages match the squashed result and follow the
   `git-commit` skill's conventions.
4. If an upstream branch exists, check whether it now diverges and whether a force push
   is required.
5. If no upstream branch exists, confirm the first-push command instead.
6. Summarize the rewrite for the user, including the final commit list and the correct
   push command.
7. Confirm no note-bearing commit was rewritten: every SHA listed by
   `git notes --ref=refs/notes/skillforge/branch-reviews list` that belonged to
   this branch's range must still exist and be reachable from HEAD
   (`git merge-base --is-ancestor <sha> HEAD`). If any is missing, the rebase
   orphaned a review note — stop and restore before pushing.
