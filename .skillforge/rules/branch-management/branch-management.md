**Must be completed before making any changes to any file — code, documentation,
configuration, backlog stubs, release notes, manifests, or any other file type.
There are no exceptions. "No new files" or "just a commit" does not exempt a task.**

## 1. Monorepo branch check

Run `git branch --show-current` to determine the current branch, then:

1. **If on `main`:** create a new feature branch and switch to it before touching
   any files. This applies even when:
   - the task is administrative (release notes, manifest updates, docs);
   - changes are already present in the working tree but not yet committed — move
     them to a branch first: create the branch, then commit there;
   - the user says "just commit" or "just update X" without mentioning a branch.
2. **If not on `main`:** ask the user whether to merge to `main` first or continue
   on the current branch.

## 2. Submodule check

After settling the monorepo branch, check whether any files you are about to edit
live inside a git submodule (inspect `.gitmodules` if present).

For each submodule containing files to modify: check out a feature branch inside
it, make and commit changes there, then integrate using the `sync-submodule` skill.
Read-only access to a submodule needs no branch checkout.
