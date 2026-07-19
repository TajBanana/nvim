# Review framework (task-scoped)

Follow these steps in order.

## 1. Pre-flight

Capture two things before touching any code:

- **The task's own request/intent** — the specific instruction, plan step, or
  request that was just implemented. Take this from `$ARGUMENT` if given,
  otherwise from the current conversation/plan context. This is what "in scope"
  is judged against in step 4 — not a bare git diff boundary.
- **The diff** — the working tree at the point of invocation, before this
  task's own commit:

  ```bash
  git status --porcelain
  git diff
  git diff --stat
  ```

  Include untracked new files (`git status --porcelain` lines starting `??`) in
  the reviewed set — a task that only adds new files still has an empty
  `git diff` otherwise.

**Empty diff.** If there is nothing staged, unstaged, or untracked, the task
made no code change (e.g. a pure planning or spec-only step). Note that and
stop — there is nothing to review.

This is not a durable, once-per-commit gate like `review-branch` — there is no
clean-tree precondition, no "already reviewed" git-note check, and no
merge-base. Every invocation reviews whatever is currently uncommitted.

## 2. Detect the stack

Identical rule to `review-branch`'s stack detection
(`../review-branch/references/framework.md` step 2):

- `build.gradle(.kts)` / `settings.gradle(.kts)` present →
  `../review-branch/references/stacks/gradle-kotlin-spring.md`.
- `package.json` present → `../review-branch/references/stacks/frontend.md`.
- Neither → `../review-branch/references/stacks/generic.md`.
- Both (polyglot) → ask the user which applies, or run the relevant one per
  area.

## 3. Dispatch the independent reviewer subagent

Read-only finding-generation, delegated to a fresh subagent per
`references/subagent.md` — the reviewer is not the same context that wrote the
task's code. Hand it: the task's request/intent (step 1), the diff (step 1),
the detected stack file (step 2), and these four category files paired with
the matching stack section:

1. `../review-branch/references/categories/02-logging-error-handling.md`
2. `../review-branch/references/categories/03-code-review.md`
3. `../review-branch/references/categories/06-test-review.md`
4. `../review-branch/references/categories/07-test-verification.md`

**Fallback.** If your harness cannot dispatch a subagent, run these four
categories yourself, inline, in the same order — the review still happens,
just without the independence benefit (same graceful degradation as
`review-branch`'s `reviewer-subagent.md`).

The subagent (or you, running inline) returns findings per
`references/subagent.md`'s contract. It never mutates the tree.

## 4. Apply fixes

For each returned finding, **auto-apply the fix immediately** — there is no
Fix now / Add to backlog / Opt out gate here; nothing gets backlogged.

Two exceptions pause for a quick confirmation instead:

- **Category 03's own refactor-plan clause.** For a large/complex file, that
  category already calls for proposing a specific refactor plan and asking for
  confirmation before executing it. Honor that as written — do not auto-apply
  a structural refactor.
- **Out-of-task-scope fixes.** If a finding's correct fix would touch code
  outside what the task's own request/intent covers (step 1) — e.g. a
  pre-existing gap in a function the task merely calls but didn't change — do
  not auto-apply it. Surface it and ask, rather than silently expanding the
  task's blast radius.

Everything else — missing/incorrect logs, error-handling gaps, weak or missing
test coverage, trivial/tautological tests, failing tests — gets fixed without
asking.

## 5. Re-verify

After applying fixes, re-run category 07
(`../review-branch/references/categories/07-test-verification.md`) once
against the fixed tree, using the detected stack's test commands. If a fix
introduced a new failure, fix it and re-run again — iterate until clean. Do
not re-litigate failures that were already known and outside this task's scope
(step 4's out-of-scope rule still applies here too).

## 6. Summarize inline

Report, in the conversation, using exactly these three literal labels, each on
its own line — always all three, even when a group is empty (write "none"
rather than omitting the label):

```
Checked: <which of the four categories ran, and against which stack>
Fixed: <one line per finding that was auto-applied, or "none">
Pending confirmation: <one line per finding withheld under step 4's two
  exceptions, with the proposed fix, or "none">
```

This exact three-label shape is required, not just the substance — a
dogfood run of this skill found the summary drifting into unlabeled prose
(a run-on sentence, or the labels dropped entirely) when only the substance
was specified. Keep each group's content on its own line(s) under its label;
do not collapse all three into a single sentence.

No file is written to disk and no git note is created — this is an ephemeral,
in-conversation gate. `review-branch`'s end-of-branch report remains the
durable record for the branch as a whole.
