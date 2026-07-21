# Independent reviewer subagent (task-scoped)

Finding-generation (framework step 3: run the four categories against
the diff the calling session already captured and the stack it already
detected) is read-only analysis. Dispatch it to a **fresh, independent
subagent** by default, so the reviewer is not the same context that just wrote
the task's code — same rationale as `review-branch`'s
`../review-branch/references/reviewer-subagent.md`, adapted here for a single
task's diff instead of a whole branch.

## When to dispatch

**Prefer dispatching; fall back to inline.** If your harness can dispatch a
fresh subagent (e.g. a `Task`/`Agent` tool), do so by default. If it cannot,
run the four categories inline yourself — the review still happens, just
without the independence benefit.

The subagent performs **only** finding-generation. The calling session keeps
everything else: applying fixes (step 4), the two confirmation carve-outs, the
re-verify pass (step 5), and the inline summary (step 6). The subagent never
talks to the user and never mutates the tree.

## Dispatch configuration

- **Subagent type:** a general-purpose agent with full tool access, so it can
  read the category and stack files and run the repo's own test commands.
- **Read-only:** the reviewer must not modify tracked files, the index, or
  `HEAD`. It may run the repo's test commands (they do not change tracked
  source). If it needs to inspect another revision, it uses a throwaway
  worktree (`git worktree add`) — never `git checkout` on the live tree.
- **Model:** follow the **Model** bullet of `../review-branch/references/reviewer-subagent.md`'s
  Dispatch configuration unmodified — ask once per session, default to the calling
  session's current model. The two skills **share one choice**: a reviewer model
  already picked in this session by either skill is reused silently rather than
  re-asked. That sharing matters most here, since this skill runs after every task and
  re-asking each time would be noise.

## What to withhold

Same independence guardrails as `review-branch`'s reviewer dispatch:

- **Do not** paste the implementation narrative, the reasons for the change, or
  "what we were trying to do" beyond the task's own stated request/intent — the
  reviewer reconstructs everything else from the diff itself.
- **Do not** pre-judge findings — never tell the reviewer to ignore something
  or rate a concern lower than it would otherwise be. Let it raise findings;
  the calling session applies the fix policy afterward.

## What the reviewer is given

- **The task's own request/intent** (framework step 1) — what the task was
  supposed to accomplish. This is the yardstick for "in scope" the reviewer
  uses when proposing a fix.
- **The diff** — the working-tree changes (tracked + untracked) the calling
  session captured at framework step 1, handed to the reviewer verbatim.
- **The four category files, each paired with the matching stack section**:
  `../review-branch/references/categories/02-logging-error-handling.md`,
  `03-code-review.md`, `06-test-review.md`, `07-test-verification.md`, and the
  detected `../review-branch/references/stacks/*.md` file. Each category file
  ends with a line like "Record findings per `../decision-framework.md`" —
  ignore it; there is no decision-framework here, use the return contract
  below instead.
- **The return contract below.**

## Return contract

For each finding, this exact fill-in template — every field required:

```
- <one-line description, with file:line location>
  - Criticality: <Critical|High|Medium|Low> — <brief justification: the concrete
    failure mode if left unaddressed>
  - Proposed fix: <the concrete change — a diff-able description, or "propose a
    refactor plan" if it trips category 03's large/complex-file clause>
```

No ID scheme, no Scope or Regression-risk fields — nothing here is backlogged
or graded by blast radius, so those axes (which exist in `review-branch`'s
`decision-framework.md` to support backlog grouping) don't apply. Criticality
is carried through only as context for the calling session's inline summary
(framework step 6) — it does not change whether a fix auto-applies; that's
governed entirely by the two carve-outs in framework step 4.

Before returning, self-check every finding for both required fields — a
finding missing its justification or proposed fix is incomplete.

The calling session resumes at framework step 4 with these findings — it does
not re-run the category walk.
