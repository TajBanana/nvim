---
name: review-branch
type: skill
tags: [code-review, quality, architecture]
description: Use when a branch is ready for merge-request review — a final, holistic review of the whole branch, run once when it is ready to merge (not after each task).
version: 1.10.0
compatibility: [copilot, claude]
---

# Review Branch

You are a senior software engineer running a single, unified review of a whole
branch when it is ready for merge-request review — run this **once**, when the
branch is ready to merge, not after every task. This one skill covers what used to
be split across separate post-task, architecture, and final-branch reviews.

Follow `references/framework.md` end-to-end — do not skip the pre-flight
clean-tree gate. In outline:

1. **Pre-flight** — require a clean working tree; if dirty, ask the user to commit
   first. If HEAD already carries a `refs/notes/skillforge/branch-reviews` note
   (this commit was already reviewed), confirm with the user before reviewing again
   and stop if they decline. **Select the review mode** — a **diff review** against
   `origin/main`, or a **whole-codebase baseline review** — auto-suggesting baseline
   on a trivial/empty diff, and capture the base (diff mode) or scope (baseline mode,
   no merge-base) accordingly. The reviewed tip is finalized after the squash step,
   so `review_sha` is captured there, not here.
2. **Detect the stack** — Gradle/Kotlin/Spring, frontend, or `generic` (for any
   other repo, incl. skill-forge itself); ask only if genuinely ambiguous (both
   Gradle and frontend markers present). Stack detection applies in both modes; in
   baseline mode the categories walk the repo tree/scope from step 1 instead of a
   diff.
3. **Run the nine categories in order** to generate findings — by default **dispatch
   a fresh, independent reviewer subagent** for this read-only phase
   (`references/reviewer-subagent.md`), falling back to running it inline if your
   harness can't spawn one. Pair each `references/categories/NN-*.md` with the detected
   `references/stacks/*.md` section:
   metrics → logging/error-handling → code review → architecture → documentation
   → test review → test verification → code quality → over-engineering.
4. **Tag every finding** using `references/decision-framework.md` (criticality,
   scope, regression risk, recommended action) — it defines a separate
   recommended-action derivation per mode (baseline drops the in-scope axis) and a
   coupling-aware grouping rule that applies to both modes.
5. **Report** the findings — an HTML page when more than three findings (and the
   harness supports it), else a full-detail markdown table, per
   `references/decision-framework.md`. Each finding carries a unique ID (criticality
   initial + counter, e.g. `H2`) for reference — **wait for the user's decisions**
   (by ID) before changing any code.
6. **Apply fixes** and route backlog items via the `add-backlog` skill, then
   **re-run the mechanical gates** (test verification and code quality /
   lint / type-check / Sonar) on the fixed tree — fixing only **new** regressions
   the fixes introduced and leaving issues already routed to Add to backlog, marked
   Already tracked, or Opt out in step 5 as decided, since a fix can introduce a
   problem the step-3 sweep ran too early to see.
7. **Finalize the branch** — run the `update-release-notes` skill to reconcile the
   release notes (it creates `RELEASE_NOTES.md` if the repo lacks one, leaving any
   history in other files untouched), then run `squash-commits` to consolidate the branch *before* the
   report and note record a commit SHA (and before any note exists), then capture
   the finalized tip as `review_sha`.
8. **Write the report** per `references/report.md` (recording `review_sha`) —
   named `branch_review_<NNN>.md` (diff mode) or `repository_baseline_<NNN>.md`
   (baseline mode), sharing one global `<NNN>` counter across both — confirm it
   with the user, and commit it via the `git-commit` skill.
9. **Write and push the git note** per `references/git-note.md` (on the report
   commit, with the `review_sha` from step 7), validated against
   `references/git-note.schema.json`.

Reference files:

- `references/framework.md` — the full ordered flow.
- `references/reviewer-subagent.md` — dispatching the independent reviewer subagent for finding-generation.
- `references/decision-framework.md` — classification, risk, reporting, decision gate.
- `references/categories/01-metrics.md` … `09-over-engineering.md` — what each category
  checks. `09` delegates to the `ponytail-review` / `ponytail-audit` skills and records a
  skip when they are not installed.
- `references/stacks/gradle-kotlin-spring.md`, `references/stacks/frontend.md` — concrete per-stack commands.
- `references/report.md` — report format and path.
- `references/git-note.md` + `references/git-note.schema.json` — the git-note contract.
