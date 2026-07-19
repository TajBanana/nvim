---
name: git-push-mr
type: skill
tags: [git, gitlab]
description: Use when the current branch is on a GitLab remote and the user explicitly asks to create or update a merge request.
version: 1.3.1
compatibility: [copilot, claude]
---

## Overview

Push the current branch to a GitLab remote and create or update a merge request
using GitLab push options. This is the standard GitLab method — no extra CLI tools
required. The push flow also propagates `refs/notes/skillforge/*` review notes
(e.g. `review-branch` results), which a branch push does not carry on its own.

Do not use `gh pr create` on GitLab remotes. Do not invoke this skill proactively;
wait until the user explicitly asks to create or update an MR.

## When to use

- The user explicitly asks to create or update a merge request
- The remote URL contains `gitlab` (GitLab hosted instance)

## Do not use when

- The user has not asked for an MR — do not create one automatically after a push
- The remote is GitHub — use `gh pr create` instead

## Procedure

1. **Confirm GitLab remote:**
   ```bash
   git remote get-url origin
   ```
   If the URL does not contain `gitlab`, stop and note that this skill is for GitLab
   only.

2. **Pre-flight: check docs and commit log quality:**

   **First — is the branch reviewed at its latest commit?** `review-branch` records
   each review as a git note (under `refs/notes/skillforge/branch-reviews`) on the
   reviewed tip. The review is current only if a note is on **HEAD**; a note on an
   earlier commit means new commits have landed since the review, so it is stale.
   Check (fetch the notes ref first if the review may have run in another clone):

   ```bash
   head=$(git rev-parse HEAD)
   base=$(git merge-base origin/main HEAD)   # resolved default branch
   noted=$(git notes --ref=refs/notes/skillforge/branch-reviews list 2>/dev/null | awk '{print $2}')
   if printf '%s\n' "$noted" | grep -qx "$head"; then
     echo "current"                                  # HEAD itself is reviewed
   else
     # read line-by-line, not `for c in $noted` — zsh (the macOS default shell) does
     # not word-split an unquoted variable, so that loop silently sees one long string
     # and never reports a stale review.
     printf '%s\n' "$noted" | while read -r c; do    # a stale review on an earlier branch commit?
       [ -n "$c" ] || continue
       git merge-base --is-ancestor "$c" HEAD 2>/dev/null \
         && ! git merge-base --is-ancestor "$c" "$base" 2>/dev/null \
         && echo "stale: $(git rev-list --count "$c"..HEAD) commit(s) since the review of $c"
     done
   fi
   ```

   - Prints `current` → the branch is reviewed at HEAD; proceed.
   - Prints `stale: N commit(s) …` → a review exists but N commits landed since it;
     suggest **re-running** `review-branch`.
   - Prints nothing → no review recorded; suggest running `review-branch`.

   In the stale or no-review cases, ask before creating the MR:
   > "The branch's latest commit is not reviewed by `review-branch` (no review note
   > on HEAD). Would you like to run `review-branch` first?"

   A completed `review-branch` run already includes `squash-commits`,
   `update-release-notes`, and a documentation check — so if a note is found (or the
   user runs it now), you can skip the finer signals below.

   **Then**, if `review-branch` was not run, scan the branch for these signals and
   ask about the relevant skill. Only raise items where you have concrete evidence
   they are needed — do not ask about every item every time.

   | Signal | Ask about |
   |--------|-----------|
   | Commit log contains WIP, fixup, checkpoint, or review-fix commits | `squash-commits` skill |
   | `RELEASE_NOTES.md` (or equivalent) appears absent or has no entry for this branch's changes | `update-release-notes` skill |
   | Technical documentation files (e.g. `docs/`, `*.md` references in changed files) look stale or missing for new functionality | `update-tech-docs` skill |

   If nothing needs attention, skip this step silently and proceed.

   If one or more signals are present, list only the relevant skills and ask:
   > "Before creating the MR, it looks like [X] may need attention. Would you like to
   > run the `<skill>` skill first?"

   Wait for the user's answer before continuing. Respect their choice — if they say
   no, proceed to the next step.

3. **Check for commits to push:**
   ```bash
   git log origin/<current-branch>..HEAD --oneline
   ```
   If the output is empty the branch is already up-to-date. Push options have no
   effect when there is nothing to push — commit any pending changes first. This
   check gates only the branch/MR push (step 4): even when the branch is already
   up-to-date, still run the notes push (step 5) — git notes travel on a separate
   refspec and may need pushing on their own (e.g. a note written or updated on an
   already-pushed commit).

4. **Push with MR options:**

   Build the description as a single-line variable using `\n` escape sequences —
   git rejects push options that contain literal newline characters:

   ```bash
   DESC="## Summary\n<1-2 sentence description>\n\n## Changes\n- <change 1>\n- <change 2>"

   git push -u origin HEAD \
     -o merge_request.create \
     -o merge_request.target=main \
     -o "merge_request.title=<title>" \
     -o "merge_request.description=${DESC}" \
     -o merge_request.remove_source_branch
   ```

   GitLab renders `\n` as line breaks in the MR description. GitLab prints the MR
   URL in the push output.

   Replace `main` with the repository's resolved default branch if different.

5. **Push review git notes:**

   Review skills such as `review-branch` record their results as git notes under
   the `refs/notes/skillforge/*` namespace. A branch push does **not** carry git
   notes, so push them explicitly so the review record reaches the remote. Run this
   **regardless of whether step 3 found commits to push** (notes may need pushing
   even when the branch is up-to-date), guarded so it is a no-op when no such notes
   exist:

   ```bash
   if [ -n "$(git for-each-ref refs/notes/skillforge/)" ]; then
     git push origin 'refs/notes/skillforge/*:refs/notes/skillforge/*'
   fi
   ```

   If the push is rejected because the remote notes ref advanced, fetch and
   reconcile with `git notes merge` before re-pushing (see the `review-branch`
   `git-note.md` procedure) — do not force-push.

## Deriving the MR title

Use the highest-impact conventional commit subject in `<merge-base>..HEAD`:

- If there is one commit, use its subject as-is.
- If there are multiple commits, use the dominant conventional type prefix
  (`feat` > `fix` > `refactor` > `chore`) and write a summary that reflects the
  combined change.

## MR description template

```
## Summary
<1-2 sentence description of what this MR does and why>

## Changes
<bulleted list of changes grouped by area>

## Planning Artifacts
<links to docs/superpowers/plans or specs if present, otherwise omit section>
```

## Existing MR behaviour

If an MR already exists for the branch, GitLab silently ignores
`-o merge_request.create` — no duplicate is created. The
`-o merge_request.title=...` and `-o merge_request.description=...` options update
the existing MR's metadata on every push. The same push command therefore both
creates and updates: always include title and description options so the MR stays
in sync with the latest commits.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Using `gh pr create` on a GitLab repo | Check remote URL first; use `git push -o` |
| Push options silently no-op | Branch is already up-to-date — ensure there are commits to push |
| Title or description splits on spaces | Always quote: `-o "merge_request.title=my title"` |
| Description contains real newlines | Use `\n` escapes in a variable: `DESC="line1\nline2"`, then `-o "merge_request.description=${DESC}"` |
| Review git notes missing on the remote | A branch push does not carry git notes, and an up-to-date branch does not exempt them — push `refs/notes/skillforge/*` explicitly (step 5) |
| Creating the MR with a missing or stale `review-branch` review | The note must be on **HEAD**, not just somewhere on the branch — a note on an earlier commit means commits landed since the review (step 2); if it's missing or stale, suggest running `review-branch` first |
