# Rebasing or squashing a submodule component

Under git submodules there is no special vendoring/adoption machinery. Rebasing a
component branch onto its parent (mainline) branch is built into `sync-submodule`;
squashing is a normal git operation in the component's worktree.

## Rebase onto the parent branch — the one-step path

`sync-submodule --rebase` rebases the component branch onto its parent (default)
branch, force-pushes it, and re-pins the gitlink in one step:

1. **Check out a branch** in the submodule (if not already on one):

   ```
   git -C <submodule-path> checkout -b <branch>
   ```

2. **Confirm the force-push with the user.** `--rebase` rewrites the branch and
   force-pushes it (`--force-with-lease`), overwriting the remote branch history.
   Anyone based on the old tip must reset. Proceed only if they agree.

3. **Rebase + integrate:**

   ```
   skillforge-repos sync-submodule <holder-slug> <submodule-path> --rebase
   ```

   Override the rebase base with `--onto <ref>` (implies `--rebase`). On success
   the gitlink + `.gitmodules` are staged — commit them with `git-commit`.

## When the rebase conflicts — resolve it yourself

`--rebase` never auto-resolves. On a conflict the underlying `submodule-push.sh`
runs `git rebase --abort` (restoring the branch, pushing nothing, leaving the
gitlink untouched) and exits non-zero. Resolve it in the worktree, then integrate
with `--force`:

1. Re-create the rebase in the submodule directory:

   ```
   git -C <submodule-path> fetch origin <onto>      # <onto> = parent/default branch
   git -C <submodule-path> rebase origin/<onto>
   ```

2. For each conflicted hunk, resolve preserving **both** sides' intent — the
   parent-branch (mainline) change *and* the component change. Do not blindly take
   one side.

3. When the component has a fast check (build, lint, or unit tests), run it to
   validate the resolution before continuing.

4. Stage and continue: `git -C <submodule-path> add <resolved-files>` then
   `git -C <submodule-path> rebase --continue`. Repeat through every step of the rebase.

5. After a clean rebase, integrate the rewritten branch and re-pin:

   ```
   skillforge-repos sync-submodule <holder-slug> <submodule-path> --force
   ```

   Then commit the staged gitlink with `git-commit`.

6. If a conflict is genuinely ambiguous or unsafe to auto-resolve,
   `git -C <submodule-path> rebase --abort` and surface the specific files and the
   decision to the user. Bound your attempts — do not thrash.

## Squashing WIP commits

Squashing is **not** folded into `sync-submodule`. Squash in the submodule
directory, then sync normally:

1. Check out the component branch (as above).
2. Follow the `squash-commits` skill exactly, using `git -C <submodule-path>`.
3. Integrate: `skillforge-repos sync-submodule <holder-slug> <submodule-path>`
   (a squash rewrites history, so add `--force`), then commit the gitlink.

There is no vendored-history bookkeeping to heal and no force-adoption step — the
monorepo only ever carries a normal gitlink-bump commit.
