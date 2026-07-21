# Review framework (the spine)

Follow these steps in order. Do not skip the pre-flight gate.

## 1. Pre-flight gate

Verify a clean working tree — no pending or untracked changes:

```bash
git status --porcelain
```

If there is any output, **stop** and ask the user to commit (or stash) before
proceeding, so the review has a known starting commit.

**Already reviewed?** `review-branch` records each review as a git note on the
reviewed HEAD under `refs/notes/skillforge/branch-reviews`. If HEAD already carries
one, this exact commit has been reviewed:

```bash
git notes --ref=refs/notes/skillforge/branch-reviews list 2>/dev/null \
  | awk '{print $2}' | grep -qx "$(git rev-parse HEAD)" && echo "already reviewed"
```

If it prints `already reviewed`, **confirm with the user before reviewing again** —
the recorded review already covers this commit, so a re-review is only worth it if
they want one:
> "This commit already has a recorded `review-branch` review. Review again?"

Stop here if they decline. (A note only on an earlier commit, or none at all, means
the tip is unreviewed — proceed.)

**Review mode.** `review-branch` supports two modes: a **diff review** of this
branch's changes against `origin/main`, or a **whole-codebase baseline review**.
Auto-suggest baseline with a concrete trivial-diff check:

```bash
base_sha=$(git merge-base origin/main HEAD)
changed=$(git diff --name-only "$base_sha"..HEAD)
# trivial = empty, or every changed path is documentation (*.md or under docs/) with no code/config file
code_changed=$(printf '%s\n' "$changed" | grep -vE '(\.md$|^docs/)' || true)
if [ -z "$changed" ] || [ -z "$code_changed" ]; then echo "trivial diff → suggest baseline"; fi
```

When the branch's diff vs its base is empty or trivial (no code changes — only
minor documentation edits), suggest the whole-codebase baseline review. Otherwise
default to the diff review. Record the chosen mode as `mode` (`diff` or
`baseline`).

Then capture the base/scope by mode:

**diff mode** (the reviewed tip is HEAD for now; its final identity is fixed after
the squash step, since squashing the branch's own commits does not move the
merge-base):

```bash
base_ref=origin/main
base_sha=$(git merge-base "$base_ref" HEAD)
```

**baseline mode**: there is no merge-base — the review target is the repo tree at
HEAD, scoped to the whole repo by default or a user-named path/subsystem. Ask the
user which if it isn't obviously the whole repo, and record it as `scope` (default:
whole repo). The in-scope/out-of-scope axis (`decision-framework.md`) does not
apply in this mode — every finding is a baseline finding.

**Prior ignored issues.** Locate the **single latest report in `docs/reviews/`**,
regardless of family (the max-`NNN` file, whether `branch_review_<NNN>.md` or
`repository_baseline_<NNN>.md`), per `decision-framework.md`'s carry-forward step 1,
so its **Issues Ignored** can be carried forward. This report path is an input to
finding-generation (step 3); `base_sha` is also an input there, but only in **diff
mode** — baseline mode has no merge-base. The **relevance re-check** itself —
re-verifying each ignored entry against the current tree and dropping any whose
referenced code/condition is gone — is performed at step 3, by the dispatched
reviewer (or by you, if running inline), per the "Carry forward previously-ignored
issues" steps in `decision-framework.md`. This carries forward only still-relevant
opt-outs and re-litigates none. Skip if there is no prior report.

## 2. Detect the stack

- `build.gradle` / `build.gradle.kts` / `settings.gradle` / `settings.gradle.kts`
  present (Spring dependencies where relevant) → use `stacks/gradle-kotlin-spring.md`.
- `package.json` present → use `stacks/frontend.md`.
- Neither present (e.g. a Python/Go/Rust service, or a docs/skills/config repo —
  including skill-forge itself) → use `stacks/generic.md`, which runs the categories
  stack-agnostically and discovers the repo's own test/quality gates. Do **not**
  stall here asking "which stack?" — the generic stack is the answer.
- Both present (polyglot/monorepo) → ask the user which stack section applies, or
  run the relevant one per area.

## 3. Run the review categories in order

**Prefer an independent reviewer.** Steps 2–4 are read-only finding-generation. By
default, **dispatch a fresh, independent subagent** to perform them and return tagged
findings, per `reviewer-subagent.md` — so the review is not done by the same context
that wrote the branch. Fall back to running the walk inline only if your harness
cannot dispatch a subagent. Either way, steps 5–12 stay with **you** (the
orchestrator): the subagent only *generates* findings — it never talks to the user,
decides dispositions, or mutates the branch. Hand it `base_sha` (from step 1), the
prior report path (step 1), and the return contract; do not paste your session's
implementation history into the dispatch. Resume at step 4 with its findings.

The walk itself (whether you run it or the subagent does) — pair each
`categories/NN-*.md` (what to check) with the matching section of the detected stack
file (concrete commands / rules / skips):

1. `categories/01-metrics.md`
2. `categories/02-logging-error-handling.md`
3. `categories/03-code-review.md`
4. `categories/04-architecture.md`
5. `categories/05-documentation.md`
6. `categories/06-test-review.md`
7. `categories/07-test-verification.md`
8. `categories/08-code-quality.md`
9. `categories/09-over-engineering.md`

Some category files contain more than one independently-triggered check —
including checks with no diff trigger of their own (e.g. category 05's
technical-docs pre-check runs regardless of the diff). Read each file in full
and execute every mandatory check it describes, not only the ones a glance at
the diff suggests.

**Be exhaustive, not representative.** Apply every category's checks to **every**
in-scope location — each changed file/hunk in diff mode, each in-scope file in
baseline mode — reading each in full rather than skimming. When a defect recurs
(the same anti-pattern at several sites), record **every** occurrence, not one
representative example; repeated occurrences are consolidated at *reporting* time
(`decision-framework.md`, "Group repeated findings"), never dropped during
detection. Do not stop once you have "enough" findings — a category is done when
its checks have been applied across the whole scope, not at a target count.
Run-to-run disagreement in this review comes from **under-coverage**, not
over-reporting; completeness is the goal.

**Coverage grid (deterministic stopping condition).** Do not sweep "until nothing new
appears" — that stops at a different depth each run. Instead enumerate a coverage grid
and drive it to completion:

- Enumerate the in-scope files: `git ls-files <scope>` in **baseline** mode; the
  changed files (`git diff --name-only base_sha..HEAD`) in **diff** mode.
- The coverage obligation is the grid **files × applicable categories** — every
  in-scope file paired with every category the detected stack does **not** skip (e.g.
  `stacks/frontend.md` skips 01-metrics). Each mandatory
  non-file-anchored check (e.g. category 05's technical-docs pre-check) is its own
  grid cell. The once-run mechanical gates (categories 07 and 08) and the once-run
  delegated skill invocation (category 09) are each a single non-file-anchored cell,
  not one cell per file.
- The sweep is **complete when every cell is explicitly marked visited** — a
  mechanical stop, not a judgment of "did I miss anything". Track the grid as a
  checklist of cells and do not compile findings while any cell is unvisited.

A review is complete only when every `(file × applicable category)` cell is marked
visited **and** every applicable **category** has a disposition — findings or a
specific swept-clean attestation (`reviewer-subagent.md`); a category with neither
is re-swept per the completeness backstop. "Every file read" can no longer coexist
with "a category never applied."

This raises recall to a floor that **regenerates from the repo each run** — no static
list of checks is authored or maintained. Exhaustiveness within a cell is unchanged:
record **every** occurrence of a recurring defect; consolidation happens at merge
time (`decision-framework.md`, the defect-class merge unit).

**Per-file class-probe backstop (recall floor within a file).** Reading a file "in full"
is not the same as *hunting* its failure modes — a state-lifecycle bug (a value set in one
handler and never reset in another) survives a top-to-bottom read. So after the **open, exploratory read** of
each in-scope file — which comes **first** and produces its own
findings — run a **class-probe backstop**: for **every** defect-class in the taxonomy
(`decision-framework.md`), ask "does this file exhibit it?", recording a `file:line` +
evidence for a hit, or a fast "no" for a class plainly irrelevant to the file. The probes
are a **backstop, not the primary lens** — they run *after* the open read and only catch
*known* archetypes it missed; they never replace open discovery (probing first would anchor
you on the list). Two guardrails keep the probe list a **floor, not a ceiling**:

- **Mandatory `other` probe.** End each file's probes with: "beyond the listed classes, is
  there any issue a senior reviewer would flag? If it fits no class, report it, tag it
  `other`, and propose a class name." Searching the unknown is itself required.
- **A minimum, not the definition of done.** These probes are a floor — a file may have
  issues in no listed class, and you must still report them.

The probe is **per file**; when a file is read by more than one category worker, a
duplicated class hit collapses at dedup (`reviewer-subagent.md`). No class-to-category
partition is maintained — the probe set regenerates straight from the taxonomy each run.

Collect findings as you go, tagging each with the fields defined in
`decision-framework.md`.

## 4. Report

Present all findings per `decision-framework.md` (an HTML page when more than three
findings and the harness supports it, else a full-detail markdown table). The Issues
Ignored set is this review's new opt-outs **plus** the
still-relevant issues carried forward from the latest prior report (step 1); add the
one-line "N of M prior ignored issues still relevant, carried forward" note so the
carry-forward is transparent. The report format choice is the same in both modes;
what differs is the recommended-action derivation behind each finding (diff vs
baseline, `decision-framework.md`) — in baseline mode every finding is pre-existing,
so no finding carries the in-scope/pre-existing distinction.

## 5. User decision

For each finding, resolve Fix now / Add to backlog / Already tracked / Opt out
using the derivation defaults in `decision-framework.md`. **Already tracked** is
assigned earlier, during finding-generation (step 3) — it needs no decision here
by default; the user may still override it with "Fix now `<ID>`"
(`decision-framework.md`'s User decision gate). Wait for explicit confirmation on
"Fix now" issues before changing code. When the user opts out of an issue, capture
a short rationale and record it as the finding's **Why ignored** (per
`decision-framework.md`).

## 6. Apply fixes and backlog entries

Apply confirmed fixes. Route backlog items through the `add-backlog` skill,
grouped as `decision-framework.md` specifies — this routes only entries whose
recommended action is **Add to backlog**. Entries the backlog cross-check already
matched to an existing stub (**Already tracked**, `decision-framework.md`) are
never routed here: that cross-check runs earlier, during finding-generation
(step 3, `reviewer-subagent.md`'s normalization pipeline), not at this step.
**Pass each entry's `priority`** (per `decision-framework.md`'s **Backlog
priority** rule — 1:1 from the entry's highest-criticality finding) so the
created stub's `priority:` frontmatter is written.

**Re-verify the mechanical gates after fixing.** A fix applied here can introduce
a test failure or a fresh lint / type-check / formatter / SonarQube issue that the
category walk (step 3) never saw — it ran before these fixes existed. So whenever
any fix is applied in this step, re-run the mechanical gates on the resulting
tree — test verification (`categories/07-test-verification.md`) and code quality
(`categories/08-code-quality.md`). Act only on problems the fixes **newly
introduced**: fix those and re-run until they are clean. **Leave issues already
decided in step 5 as decided** — anything the user routed to Add to backlog,
marked Already tracked, or Opt out must not be re-flagged, re-fixed, or counted as
a gate failure here (doing so would undo the user's decision and could stall the
re-run). Only new regressions block continuing.

## 7. Finalize the branch

First, run the `update-release-notes` skill to capture the branch's changes in the
release notes. Run it on every branch: if the repo has no `RELEASE_NOTES.md`, that
skill now **creates** it for this release (any release notes kept in other files,
such as an existing `CHANGELOG.md`, are left untouched).

Then run the `squash-commits` skill (or prompt the user to) to consolidate the
branch's work, fix, and release-note commits **now** — before the report and note
record a commit SHA, and before any note exists (once a note exists,
`squash-commits` will not rewrite it or anything before it). Doing this first keeps
the `review_sha` in the report and note pointing at a commit that still exists
after squashing.

## 8. Capture the reviewed SHA

```bash
review_sha=$(git rev-parse HEAD)
```

This finalized branch tip is stable and reachable; it goes in the report header
and the git note's `review_sha`. Unchanged by mode — both diff and baseline reviews
capture `review_sha` the same way.

## 9. Write the report

Write the review report per `report.md` (the header records `review_sha`). The
report filename depends on mode — `docs/reviews/branch_review_<NNN>.md` (diff) or
`docs/reviews/repository_baseline_<NNN>.md` (baseline), sharing one global `<NNN>`
counter — see `report.md`. The accompanying git note's `coverage` field follows the
same mode (`CUMULATIVE_FROM_BASE` vs `REPOSITORY_BASELINE`, step 12) — see
`git-note.md`. The Issues Ignored section records each opted-out issue in full detail
and includes the still-relevant issues carried forward from the latest prior report
(step 1), each with its **Carried forward:** origin.

## 10. Confirm the report

Show the drafted report to the user and confirm its contents before committing.

## 11. Commit the report

Commit the report via the `git-commit` skill. After this, HEAD is the report
commit.

## 12. Write and push the git note

Attach the JSON note to the report commit (final HEAD) and push it, per
`git-note.md` (validate against `git-note.schema.json` first). The note's
`review_sha` is the value captured in step 8.

**If the branch itself still needs pushing** (no upstream yet, or unpushed
commits) to push the note meaningfully, do not hand-roll the branch push —
this still only applies once the user has asked to push or ship the branch,
per `git-push-mr`'s own "do not invoke proactively" rule. When they have, use
the `git-push-mr` skill for it: it pushes the branch, creates or updates the
GitLab merge request with a real title and description (not a hand-rolled
`git push -o merge_request.create` command, which silently defaults the
description from the first commit if `-o merge_request.description` is
omitted), and pushes `refs/notes/skillforge/*` — including this note — in the
same pass, per `git-note.md`. Only fall back to the bare `git notes ... push`
commands in `git-note.md` when the branch already has an upstream (nothing
else needs pushing, only the note).
