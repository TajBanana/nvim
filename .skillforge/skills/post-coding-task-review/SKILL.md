---
name: post-coding-task-review
type: skill
tags: [code-review, quality, testing]
description: Use after completing an individual coding task (not a whole branch) — a lightweight review of just that task's own changes covering logging/error-handling, code review, test review, and test verification, with fixes applied immediately. Not a substitute for review-branch's once-per-branch holistic review.
argument-hint: "[task description, if not obvious from context]"
version: 1.1.0
compatibility: [copilot, claude]
---

# Post Coding Task Review

You are reviewing **one coding task's own changes** — not the whole branch. This
is a lightweight, per-task gate: run it after an individual unit of coding work
(a task from an implementation plan, a single fix, one iteration of a loop) is
code-complete and its tests pass, before that task is committed. It is not a
substitute for `review-branch`, which remains the once-per-branch, holistic
review run at merge time — this skill only covers four of its nine categories,
scoped to this task's own diff.

Follow `references/framework.md` end-to-end. In outline:

1. **Pre-flight** — capture the task's own request/intent (from context or the
   `$ARGUMENT`) and the working-tree diff (tracked + untracked) at the point of
   invocation, before this task's commit. If the diff is empty, note that and
   stop.
2. **Detect the stack** — same rule as `review-branch`
   (`../review-branch/references/framework.md` step 2): Gradle/Kotlin/Spring,
   frontend, or `generic`.
3. **Dispatch an independent reviewer subagent** (`references/subagent.md`) over
   four of `review-branch`'s categories — logging/error-handling, code review,
   test review, test verification — paired with the matching
   `../review-branch/references/stacks/*.md` section:
   `../review-branch/references/categories/02-logging-error-handling.md`,
   `03-code-review.md`, `06-test-review.md`, `07-test-verification.md`. Falls
   back to running them inline if your harness can't dispatch a subagent.
4. **Apply fixes immediately** — no backlog, no report, no Fix now / Add to
   backlog / Opt out gate. Two exceptions pause for a quick confirmation instead
   of auto-applying: category 03's own large/complex-file refactor-plan clause,
   and any fix that would reach outside the task's own diff/intent.
5. **Re-verify** — re-run category 07 once on the fixed tree; iterate until
   clean. Only new regressions the fixes introduced block completion.
6. **Summarize inline** — what was checked, what was auto-fixed, what (if
   anything) is pending confirmation. No file is written, no git note is made.

Do not copy the reused category or stack files into this skill's own
`references/` directory — read them from `review-branch`'s installed location,
by the relative paths above.

Reference files:

- `references/framework.md` — the full ordered flow.
- `references/subagent.md` — dispatching the independent reviewer subagent.
- Reused unmodified from `review-branch` (relative path, same install-together
  group): `../review-branch/references/categories/02-logging-error-handling.md`,
  `03-code-review.md`, `06-test-review.md`, `07-test-verification.md`, and
  `../review-branch/references/stacks/gradle-kotlin-spring.md` / `frontend.md` /
  `generic.md`.
