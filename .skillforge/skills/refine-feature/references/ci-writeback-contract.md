# SDD CI writeback contract

How an SDD spec repo's CI persists generated data back into committed specs: Jira
issue keys into the `## Jira` section, plus any mirror or registry updates. Shared
by every component, assembly, and release repo (and the epics-index repo) in the
SDD model, so they all behave the same.

This is the **CI side**. The **authoring side** is the pipeline-managed `## Jira`
convention (see "`## Jira` is pipeline-managed" in `conventions.md`, and the epic
equivalent in `../refine-epic/references/epic-conventions.md`): the skills seed a
blank `## Jira` placeholder and never write a key; the CI fills it following the
rules below.

## Why a writeback MR (not a direct push)

`main` is the default branch and is **protected**: nobody pushes to it directly -
not a developer, and not a CI job. Every change reaches `main` only through a
merge request, which the Developer and Maintainer roles may merge (approval is
optional in practice). So CI cannot commit a Jira key, a mirror update, or a
registry update straight to `main`. It opens an MR and has it merged by the CI
service account (the bot).

These repos also follow the two-pipeline `devtools-gitlab-includes` convention:
the **default-branch pipeline only cuts the release tag**; the mutating work runs
in the **release-tag pipeline**.

## The contract

1. **Writebacks reach `main` only via a bot-merged MR, never a direct push.** Any
   persistence into committed files - the `## Jira` issue link/key, mirror data,
   registry data - is committed on a short-lived branch, opened as an MR, and
   merged by the CI service account. No job pushes to `main`.

2. **Mutating jobs run in the release-tag pipeline.** The Jira `*_apply` jobs and
   the publish jobs run only when `$CI_COMMIT_TAG` is set (the release-tag
   pipeline). The default-branch pipeline cuts the release tag and does nothing
   mutating. A `*_plan` job may run on the MR pipeline to preview, but only
   `*_apply` writes.

3. **Writeback MR commits use a non-release-bumping type.** Commits on the
   writeback MR use a `chore` or `ci` Conventional-Commits type - never `feat`,
   `fix`, or `BREAKING CHANGE` - so the auto-release job does not cut a spurious
   release tag for the writeback itself (which would loop tag -> apply ->
   writeback).

4. **The last job does a CODEOWNERS-gated auto-merge.** The final job decides how
   the writeback MR merges, based on whether any `CODEOWNERS` owner matches the
   changed paths:
   - **No owner matches** -> set `merge_when_pipeline_succeeds=true` and let the
     bot auto-merge.
   - **An owner matches** -> do not auto-merge; post a note tagging the owning
     role/team and leave the MR for a human to merge.

5. **The dup-title guard adopts on conflict.** When creating a Jira issue, if one
   with the same title already exists (a conflict), recover and adopt the existing
   Jira key rather than hard-failing the job. The writeback records the adopted
   key, so a re-run does not create a duplicate issue.

6. **Parent links are reconciled idempotently on every run.** Parent relations -
   the epic link (a feature or tech-task issue placed under its epic) and the
   user-story -> feature parent link - are reconciled to the desired state on
   every run, not set once at creation. Re-running converges to the same state; it
   never duplicates or drifts.

## How a Jira key lands (the flow)

1. A spec-authoring MR merges to `main`; its `## Jira` is the blank managed
   placeholder.
2. The default-branch pipeline cuts a release tag.
3. The release-tag pipeline runs the Jira `*_apply` job: it creates or adopts the
   Jira issue (rule 5), reconciles parent links (rule 6), then persists the issue
   key into the spec's `## Jira` by opening a `chore`/`ci` writeback MR (rule 3)
   that the bot merges CODEOWNERS-gated (rule 4) - never a direct push (rule 1).
4. On a backlog promotion the promoted spec still carries the blank placeholder;
   the CI carries the existing key forward from the promoted stub. Authoring never
   writes the key.

## Status: shared CI template Not Yet Built

Extracting this contract into a shared `devtools-gitlab-includes` CI template is
**deferred (Not Yet Built)**. Until that template exists, each component,
assembly, and release repo implements the contract **inline** in its own
`.gitlab-ci.yml` and scripts, following this document so every repo behaves
identically.
