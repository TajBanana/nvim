# Independent reviewer subagent

The finding-generation phase (framework steps 2–4 — detect stack, run the nine
categories, tag findings, reconcile carry-forward) is **read-only analysis**. Run it
in a **fresh, independent subagent** rather than inline, so the review is not done by
the same context that wrote the branch. When a review runs in the session that
implemented the branch, an inline reviewer is judging its own work with full memory
of every decision and rationalization — the opposite of an independent review. A
fresh subagent sees only the diff and the review instructions, so it evaluates the
work product, not your thought process.

## When to dispatch

**Prefer dispatching; fall back to inline.** If your harness can dispatch a fresh
subagent (e.g. a `Task`/`Agent` tool), do so by default. If it cannot, run steps 2–4
inline yourself — the review still happens, just without the independence benefit.
(Same graceful-degradation contract as the HTML-vs-markdown reporting choice in
`decision-framework.md`.)

The subagent performs **only** finding-generation (steps 2–4) and returns its
findings. The **orchestrator keeps** steps 1 and 5–12: the pre-flight, the
user-decision gate (Fix now / Add to backlog / Already tracked / Opt out, by ID),
all fixes, the
mechanical re-gate after fixes, finalize, the report, and the git note. The subagent
never talks to the user and never mutates the branch.

## Dispatch configuration

- **Subagent type:** a general-purpose agent with full tool access, so it can Read
  the skill files, run the repo's own gates, and invoke any other installed skill
  relevant to the detected stack.
- **Read-only:** the reviewer must not modify tracked files, the index, `HEAD`, or
  branch state. It may run the repo's test / lint / type-check / quality gates (they
  do not change tracked source). If it needs to inspect another revision, it uses a
  throwaway worktree (`git worktree add`) — never `git checkout` on the live tree.
- **Model:** **ask the user which model to run the reviewer with — once per session.**
  If a reviewer model was already chosen earlier in this session (by this skill or by
  `post-coding-task-review` — they share one choice), reuse it silently rather than
  re-asking. Otherwise ask, offering the session's current model as the **default**
  alongside any more capable one your harness exposes for review judgment. Use the
  current model when you cannot ask (non-interactive run) or the user has no
  preference. Pass the chosen model **explicitly** on dispatch. (Do not hardcode a
  model name — this skill runs on harnesses with different model line-ups.)

## Keep it independent — what to withhold

The whole point is fresh eyes, so the dispatch prompt must contain **only** what the
reviewer needs, **never the session's history**:

- **Do not** paste your implementation narrative, the reasons you made a change, or
  "what we were trying to do". The reviewer reconstructs intent per
  `guidelines/intent-sources.md` — a driving spec (the branch's superpowers or feature spec)
  above user-facing docs above code-internal signals (diff/tests).
- **Do not** pre-judge findings — never tell the reviewer to ignore something, to not
  flag an issue, or to rate a concern "at most Minor". If you think something is a
  false positive, let the reviewer raise it and adjudicate it yourself at the gate.
- **Do not** add open-ended side-quests ("check everything", "run all the tests if
  useful") without a concrete reason — hand it the defined review, nothing more.

## What the reviewer is given

Hand the subagent exactly this:

- **Repo path** and the review range: base commit `base_sha` (computed in framework
  step 1) and `HEAD`. It produces the diff itself with `git diff/log/show`
  (`git diff base_sha..HEAD`) — read-only. (This skill does not rely on any external
  diff-packaging script, since the target repo may not have one.)
- In **baseline mode** there is no diff — the reviewer is given the **repo tree at
  HEAD under `<scope>`** (whole repo, or the named path) and reviews the files in
  scope (using `git ls-files`/reads), not a diff. The mechanical gates (07–08) run
  over the repo as usual. Everything else (independence, read-only, return contract,
  optional parallelism) is unchanged.
- **The instruction to Read and follow the review-branch skill files**, from the
  skill's installed location: `framework.md` steps 2–4, all of `categories/01..09`,
  the matching `stacks/*` section for the detected stack, and `decision-framework.md`
  — **including its carry-forward steps**.
- **The latest prior report path** (if any), so the reviewer can load its Issues
  Ignored and run the carry-forward relevance re-check per `decision-framework.md`.
- **Implicit backlog directory access** — the reviewer reads the target repo's
  own `docs/features/backlog/` and `docs/tech-tasks/backlog/` (including their
  `promoted/`/`rejected/` subdirs) directly during normalization step 7's backlog
  cross-check (`decision-framework.md`); no separate hand-off is needed, since the
  reviewer already has full read access to the repo tree.
- **The return contract** below.

## Parallelizing the analysis (optional speed-up)

Steps 2–4 across nine categories can be slow run end-to-end. As the reviewer, you
**may** parallelize the read-only analysis to cut wall-clock — but only within these
guardrails, and only *you* (the fresh reviewer) do it, never the orchestrator (letting
the branch's biased author assemble the findings would defeat the independent review):

- **Fan out the analysis categories, if your harness supports it.** If you can dispatch
  subagents from within your own context, run the **pure-inspection categories 01–06**
  (metrics, logging/error-handling, code review, architecture, documentation, test
  review) as parallel, **read-only** workers. If your harness cannot nest dispatches (or
  you are unsure), run them sequentially yourself — same graceful degradation as the
  top-level dispatch; the review still happens, just serially.
- **Read the whole assigned category file before executing it, not just its
  diff-triggered parts.** Some category files bundle a mandatory,
  non-diff-triggered pre-check alongside diff-anchored checks — e.g.
  `categories/05-documentation.md`'s technical-docs pre-check (is
  `update-tech-docs` installed, and does the repo's docs match its structure)
  applies regardless of what the diff touches. A worker that only reacts to what
  it sees in the diff will silently skip these; treat every mandatory
  instruction in the file as in scope, whether or not the diff hints at it.
- **Each worker is exhaustive over its assigned scope.** A worker applies its
  category's checks to **every** in-scope location it was given (every changed
  file/hunk, or every in-scope file in baseline mode), reads each in full, and
  records **every** occurrence of a recurring defect — not one representative
  example, and never stopping at a target count. A worker's scope is its assigned
  column of the **coverage grid** (`framework.md` step 3) — every in-scope file × its
  category; the worker is done when every cell in its column is visited, not at a
  target count.
- **Run the mechanical gates once, yourself.** Categories **07 test-verification** and
  **08 code-quality** run the repo's test / lint / type-check / sonar **commands** — run
  them a single time in your own context, never as parallel copies (redundant suite/lint
  runs, and they are gates, not inspection).
- **Run category 09 once, yourself.** Category **09 over-engineering** is a single delegated
  skill invocation (`categories/09-over-engineering.md`), not a file-by-file sweep — run it a
  single time in your own context, never as parallel copies, for the same reason as the gates.
  You then classify its returned findings by substance through the Normalize pipeline below.
  If the mode's ponytail skill is not installed, record the category's **skip** as its
  disposition and continue.
- **Keep all synthesis central.** Each analysis worker is read-only, receives the diff
  range (or, in baseline mode, the repo tree/`<scope>` to review instead) + its
  assigned `categories/NN-*.md` file(s) + the detected `stacks/*` section, and
  returns **raw findings plus a per-category disposition** (its findings, or a
  specific swept-clean attestation) for each category it owns. You alone then dedup
  overlaps across categories, **drive the coverage grid to completion**
  (`framework.md` step 3: every in-scope file × applicable category is marked
  visited) before compiling. After dedup and
  driving the coverage grid to completion, **normalize before assigning
  IDs (mandatory)** — run **every** collected finding through this ordered pipeline
  (`decision-framework.md`), which re-classifies already-found findings and runs **no new
  detection**, so it is cheap:
  1. **Classify** into exactly one **defect-class** (→ Defect-class taxonomy) — yields the
     finding's merge-unit scope and severity band.
  2. **Merge** by **(class × merge-unit scope)**, **within the same regression band** —
     occurrences sharing class, scope, and regression band collapse to one entry
     enumerating every affected `file:line`; different classes never merge, and no merge
     crosses the low↔not-low regression boundary (`decision-framework.md` →
     Regression-boundary merge invariant) — and at High/Medium a class spanning several
     scopes stays **one finding per scope** (never collapsed to one class entry);
     cross-scope/cross-class grouping is the `B<n>` layer's job (step 8), not the merge's.
     An entry's **Source** is the **union** of its merged members' (`decision-framework.md`) — native + ponytail = `both`. Source never affects what merges; the merge unit alone decides that.
  3. **Evidence tier** — label each entry `observed` / `static-certain` / `argued` and
     whether the failure is user-facing-runtime / data-loss / security / outage
     (→ Criticality) — yields the evidence ceiling.
  4. **Severity** — take the level from the decidable tests, then **clamp** to the class
     band ∩ the evidence ceiling.
  5. **Tie-break** — if the justification hedges between two levels, drop to the lower.
  6. **Low-consolidate** — findings now at **Low** re-merge to one entry per
     **(class × regression band)** (`decision-framework.md` → Low-band consolidation),
     overriding the finer per-scope merge; a higher-band finding tie-broken down to Low
     folds into its (class × band) entry.
  7. **Backlog cross-check** — for every entry whose recommended action is **Add to
     backlog**, check it against the target repo's existing backlog stubs per
     `decision-framework.md`'s **Backlog cross-check** section; a strict **Overlap**
     match converts the entry's recommended action to **Already tracked (<stub
     path>)** and removes it from the pool step 8 draws from. Like the rest of this
     pipeline, this runs **no new defect detection** — it is a lookup against stubs
     that already exist in the repo, reclassifying entries steps 1–6 already
     produced.
  8. Assign the provisional **backlog-group IDs** `B<n>` to coupled/partitioned
     backlog groups (`decision-framework.md`'s Coupling-aware grouping — drawing
     only from entries still at **Add to backlog** after step 7).

  **Category-completeness backstop.** Before compiling, verify **every applicable category
  has a disposition** (findings or a specific attestation). Any **silent** category — neither
  findings nor a specific attestation — was not genuinely applied: **re-sweep that one
  category** across the full scope in a fresh, focused pass (never reusing the starved
  worker's context), then fold its result in. Repeat until every applicable category has a
  disposition (each needs at most one re-sweep). This is the per-category analog of the
  coverage grid — targeted (one category, not the whole review), never a full re-run.

  Only after this pipeline do you assign the per-criticality **IDs** (workers must **not**
  assign IDs), reconcile carry-forward, and assemble the return contract. Workers
  never talk to the orchestrator or the user.
- **Grouping the workers is your call** — one worker per category, or a few grouped — the
  guardrails above (analysis-only, gates once, synthesis central) are what matter, not a
  fixed shape. (This is worker fan-out shape; it is separate from grouping *findings* for
  the report, which follows `decision-framework.md`.)
- **Do not starve a high-effort category.** Category **06 (test-review)** gets its **own
  worker** — never grouped with a cheaper sibling (e.g. 05 documentation) that would starve
  it. When grouping, do **not** pair two high-effort analysis categories (03 code-review, 04
  architecture, 06 test-review) in one worker; each is its own worker or paired only with a
  light one. Regardless of shape, **each worker returns a per-category disposition for every
  category it owns** (see the return contract), so a dropped category is always detectable by
  the completeness backstop.

## Reviewer return contract

The subagent returns a structured findings report the orchestrator presents at the
decision gate **without re-deriving it**:

- **Every finding, as this exact fill-in template** (one labeled line per field, all
  **REQUIRED** — mirrors `decision-framework.md`'s "Fields on every finding"):

  ```
  - <ID> — <one-line description, with file:line location — a grouped finding enumerates every affected file:line>
    - Criticality: <Critical|High|Medium|Low> — <justification: the concrete failure mode if left unaddressed, and how it worsens over time>
    - Scope: <in-scope (introduced by this branch) | pre-existing / out of scope> (baseline mode: every finding is pre-existing/baseline — the in-scope axis does not apply)
    - Regression risk: <low|medium|high> — <justification: blast radius (call sites/consumers touched) × how well tests cover that area>
    - Recommended action: <Fix now | Add to backlog | Already tracked (<stub path>) | Opt out>
    - Source: <review-branch | ponytail | both> — `review-branch` for a native category (01–08); `ponytail` for category 09's normal (ponytail-delegated) findings, **except** a `redundant-implementation` finding surfaced by the per-file class-probe backstop rather than by ponytail, which is `review-branch` (see `categories/09-over-engineering.md`'s Source section); `both` where they merged
  ```

  The **Criticality** and **Regression risk** lines must each carry their
  **justification** — a bare level (e.g. `Criticality: Medium` with no reason) is an
  incomplete finding. **Before returning, self-check every finding** for all seven of: ID,
  description + location, criticality **+ justification**, scope, regression risk **+
  justification**, recommended action, source — and do not return any finding with an empty slot.
  `Already tracked` names the matched stub's repo-relative path
  (`decision-framework.md`'s Backlog cross-check) so the report and the gate can
  reference it; it carries no `B<n>`.
  Carried-forward entries use the same required fields, plus the `Carried forward:` line
  (origin report + original ID); they are not exempt from the justifications.

  For a **High** finding, the Criticality justification **is** the filled severity
  predicate (`Trigger:` / `Failure:` / `Reach:`, per `decision-framework.md`), so the
  High derivation is visible; Medium/Low justifications stay prose.
- **The carry-forward reconciliation** — which prior ignored issues are still relevant
  (carried forward, with their original reason + origin report and original ID) and
  which were dropped as resolved, plus the "N of M prior ignored issues still
  relevant" note. Carried-forward entries take IDs in the same per-criticality
  sequence as fresh findings (see `decision-framework.md`), so their IDs never
  collide with this review's fresh findings.
- **The ponytail net-lines note** — when category 09 ran, ponytail's closing `net:
  -<N> lines possible` line, or its `Lean already. Ship.` verdict, returned
  **verbatim**, beside the carry-forward note (`decision-framework.md`,
  `categories/09-over-engineering.md`). The reviewer is the only actor that invokes
  ponytail, so this is the only chance to capture it. Omit it entirely when
  category 09 was skipped.
- **The mechanical-gate results** — the test-verification and code-quality gate output
  it ran, as evidence for the corresponding findings.
- **A per-category disposition for every applicable category.** For each category the
  coverage grid marks applicable (honoring the detected stack's skips), return **either** the
  category's findings **or** a **swept-clean attestation** — the specific in-scope files/areas
  examined for that category and the concrete checks run, ending in "found none" (e.g. *"06
  test-review: examined the 14 `*.test.ts(x)` under `frontend/src` and the `e2e/` specs;
  checked each for assertion-free / tautological / mislabeled tests and untested high-risk
  modules; found none."*).
  The attestation must **name the defect-classes probed** for that category (from the
  per-file class-probe backstop, `framework.md`), not a vague "reviewed it" — e.g. *"03
  code-review: probed `reactivity-stale-state`, `correctness-logic`, `error-handling-gap`,
  `input-validation-boundary` across the 3 screens; found none"* — so "the probes ran" is
  visible in the output. This per-category enumeration is the **reporting view**: it lists
  the classes that category is the natural home for. It does **not** narrow the sweep — the
  per-file backstop still probes the **full taxonomy** on every file for detection
  (`framework.md`); a class that surfaces is reported under whichever category owns it,
  regardless of which enumeration named it.
  A category that returns **neither** findings nor a specific
  attestation is an **incomplete review** for that category. Categories the stack **skips** are
  exempt (their recorded skip is their disposition); the mechanical gates 07/08 carry their
  gate results as theirs; category 09's recorded **skip** (when the mode's ponytail skill is
  not installed) is likewise its disposition. "Zero findings" with a specific attestation is a valid, complete
  disposition — do **not** re-sweep it.

The orchestrator then resumes at framework step 4/5: report the returned findings and
wait for the user's decisions. It does **not** run the category walk again.

Classification, merging (including Low-band consolidation), severity (band-clamped,
evidence-gated, tie-broken), and `B<n>` are fixed in the Normalize pipeline above, so
re-running on an unchanged tree returns the same classes, entry count, levels, and
backlog groups.
