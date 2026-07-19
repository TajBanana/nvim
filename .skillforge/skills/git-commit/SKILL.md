---
name: git-commit
type: skill
tags: [git]
description: Use when committing changes to git, including when changes may live inside a git submodule and must be routed to the owning repository.
version: 1.0.8
compatibility: [copilot, claude]
---

Before creating or amending any commit, complete this pre-flight checklist:

1. Determine which repository owns the changes (see "Which repository owns the
   change?" below). Changes inside a git submodule must be committed inside that
   submodule, not from the monorepo root.
2. Convert the rules in this skill into an explicit checklist for the current commit.
3. Draft the exact commit subject and body against that checklist
4. Verify the draft against that checklist before invoking `git commit`.

# Which repository owns the change?

A git submodule is a **separate repository** nested in the parent. A `git commit`
run from the monorepo root cannot record edits inside a submodule — the parent
only tracks the submodule as a single gitlink (a pinned commit), so the
component's file edits are invisible to the parent index. Before committing,
find out whether any changes live inside a submodule.

**Do not trust the parent `git status` for this:**

- The parent root's `git status` shows a dirty submodule only as a summary line
  (`modified: <path> (modified content)`), never the individual files — and that
  line can be suppressed by `submodule.<name>.ignore` or `diff.ignoreSubmodules`.
- `git submodule status` compares each submodule's committed HEAD against the
  pinned commit, so it does **not** reflect uncommitted working-tree edits.

Discover submodule changes deterministically by descending into each submodule:

1. Enumerate submodule paths: `git config -f .gitmodules --get-regexp '\.path$'`.
   If there is no `.gitmodules`, there are no submodules — proceed normally.
2. Inspect each submodule's own working tree:
   `git -C <submodule-path> status --porcelain` (or, across all at once,
   `git submodule foreach --recursive 'git status --porcelain'`).
3. Any submodule with output owns changes that must be committed inside it;
   the remaining changes belong to the parent repo.

See "Committing changes inside a submodule" below for how to commit them.

# Commit message rules

1. Format: Use the Conventional Commits specification (e.g., feat:, fix:, refactor:, docs:, style:, chore:).
2. Subject Line:
   - Limit to 100 characters.
   - Use the imperative mood (e.g., 'Add feature' instead of 'Added feature').
   - Do not end with a period.
3. Body (The 'Why'):
   - Separate the subject from the body with a blank line.
   - Focus on the 'What' and 'Why', not the 'How'.
   - Use bullet points to list specific changes.
   - Reference any related issue numbers or tickets (e.g., 'Fixes TICKET-1234').
   - ONLY when following the 'using-superpowers' workflow: include the task number or spec filename in every commit message (e.g., feat: implement logic for [plan-xyz.md:Task 2]).
   - ONLY when NOT following the 'using-superpowers' workflow: include a list of the specific user prompts that led to these changes at the end of the message for traceability.
     - The traceability list must contain only direct user-authored prompts that materially led to the committed changes. Do not include system prompts, tool notices, reminders, runtime warnings, or workflow task like committing and pushing changes.
     - The purpose of the traceability list is to provide additional information about the intent behind the changes. DO NOT include it if it does not add meaningful context to the commit message.
   - ** WRAP ALL BODY LINES AT 90 CHARACTERS. Including the contents of the tracebility list. **
   - ALWAYS use real newlines for formatting. Never include literal \n strings in the body.
   - When invoking `git commit` from the shell, provide the message with real
     multiline input such as repeated `-m` flags or `git commit -F -` with a
     heredoc. Do not rely on escaped newline sequences inside a single quoted
     or double-quoted `-m` string.

# Committing changes inside a submodule

When the pre-flight discovery finds changes inside a submodule, commit them in
the submodule, not from the monorepo root.

- **Commit in the repo that owns the change.** A submodule is its own repo, so
  run the commit inside it: `git -C <submodule-path> add <files>` then
  `git -C <submodule-path> commit`. This is the same mechanic whether the changes
  are in a submodule directory or in a writable worktree of that submodule —
  this skill does not care how the edits got there. The Conventional Commits
  message rules above apply unchanged: it is a normal component commit
  (`feat:`/`fix:`/etc.), **not** a `chore(submodule): bump` commit.
- **One commit per repository.** If a change set spans the parent repo and one or
  more submodules, make a separate commit in each owning repo. Do not try to
  cover a submodule's file edits and the parent in a single commit.
- **Do not touch the gitlink or push here.** This skill only records the
  component commit. Pushing the branch to the component remote and re-pinning the
  parent's gitlink is the job of the `sync-submodule` skill, run afterward. Do
  not `git add <submodule-path>` in the parent to stage a gitlink bump as part of
  this commit.
- **A submodule commit may land on a detached HEAD.** A submodule directory is
  often checked out at the pinned commit with no branch, so the new commit is
  only reachable until something re-checks-out that submodule (e.g. a
  `git submodule update` or a parent branch switch). Integrate it with
  `sync-submodule` before that happens, or the commit can be lost. (A submodule
  worktree is already on a branch, so this does not apply there.)
