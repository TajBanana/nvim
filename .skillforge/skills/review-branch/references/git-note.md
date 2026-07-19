# Git note procedure

Records the completed review as a machine-readable JSON note on the **final HEAD**
(the finalized report commit — the framework runs `squash-commits` before this
step, so history is already consolidated), then pushes the notes ref to the
remote.

## Ref

`refs/notes/skillforge/branch-reviews`

## Payload

Validate the payload against `git-note.schema.json` before writing. `review` is
always `branch_review`. The shape depends on `mode`:

**Diff mode** — `coverage: CUMULATIVE_FROM_BASE`, with `base_ref`/`base_sha`:

```json
{
  "review": "branch_review",
  "review_sha": "<finalized branch tip captured after the squash step>",
  "coverage": "CUMULATIVE_FROM_BASE",
  "report": "docs/reviews/branch_review_<NNN>.md",
  "base_ref": "origin/main",
  "base_sha": "<merge-base of origin/main and the reviewed HEAD>"
}
```

**Baseline mode** — `coverage: REPOSITORY_BASELINE`, **omitting** `base_ref` and
`base_sha` entirely (not left empty — absent):

```json
{
  "review": "branch_review",
  "review_sha": "<finalized branch tip captured after the squash step>",
  "coverage": "REPOSITORY_BASELINE",
  "report": "docs/reviews/repository_baseline_<NNN>.md"
}
```

- `review_sha` is the finalized branch tip captured after the squash step (the
  reviewed-and-fixed state that will merge), **not** the report commit that is
  added on top of it.
- `report` is the relative path written in the report step — `branch_review_<NNN>.md`
  for diff mode, `repository_baseline_<NNN>.md` for baseline mode.
- `coverage` is `CUMULATIVE_FROM_BASE` for diff-mode runs (with `base_ref`/`base_sha`
  required) or `REPOSITORY_BASELINE` for baseline-mode runs (which **must omit**
  `base_ref`/`base_sha` — the schema's `allOf` forbids them together with this
  coverage value).

## Write and push

After the report is committed and the branch history is finalized (the
framework's `squash-commits` step), write the note to the final HEAD.

**If the branch has no upstream yet** (this is its first push) and the user
wants to push/ship it now, do not push the note in isolation — use the
`git-push-mr` skill instead (per `framework.md` step 12): it pushes the
branch, creates or updates the merge request, and pushes
`refs/notes/skillforge/*` together in one pass, so the commands below are
unnecessary in that case.

**If the branch already has an upstream** (only the note needs pushing), use
the branch's upstream remote (default `origin`) directly:

```bash
git notes --ref=refs/notes/skillforge/branch-reviews add -F <note.json> HEAD
git push <remote> refs/notes/skillforge/branch-reviews
```

If the target repo has never seen this notes ref, the first push creates it. If
the push is rejected because the remote ref advanced, fetch the remote notes and
reconcile with a notes merge (which handles a diverged notes ref, unlike a plain
fetch), then push again:

```bash
git fetch <remote> refs/notes/skillforge/branch-reviews
git notes --ref=refs/notes/skillforge/branch-reviews merge FETCH_HEAD
git push <remote> refs/notes/skillforge/branch-reviews
```
