# Decision framework

Apply this uniformly to **every** finding from every review category. A finding
is any issue surfaced during the review — a missing metric, an unhandled error, a
misplaced domain rule, a stale doc, a coverage gap, a lint failure.

## Fields on every finding

- **ID** — a short, unique reference for the finding: the criticality initial
  (`C`/`H`/`M`/`L`) plus a per-criticality counter assigned in report order —
  `C1`, `C2`, `H1`, `H2`, `M1`, `L1`, … Assign it once when compiling the report;
  it does not change as decisions are made (criticality is fixed per finding). Use
  it to refer to the finding in the report, the inline summary, and the decision.
- **Description** — one short sentence naming the issue and where it is.
- **Criticality** — the level from the **decidable tests below**, **clamped** to the
  finding's defect-class **severity band** (see Defect-class taxonomy) and its **evidence
  tier**, then resolved by the **tie-break**. Evaluate the tests top-down; first match
  wins.

  **Evidence tier** (label every finding — it sets the severity ceiling; it never requires
  staging a live reproduction, only citing what you already have):
  - **`observed`** — the failure falls out of a gate the reviewer already runs once, or a
    cheap read-only command run in place (e.g. observing `npm` drop `--max-warnings`).
  - **`static-certain`** — an **unconditionally-reached** code path that must misbehave by
    inspection (provable by reading, no execution).
  - **`argued`** — "could fail if trigger X"; neither observed nor statically certain, or
    needs a new caller / edge / input.

  **Severity ceiling by evidence tier** (applies uniformly to every finding, per
  the note at the top of this document — not mode-specific):
  - **Critical** — `observed` or `static-certain`, unconditionally reached, **and** a
    user-facing runtime failure / data loss / security exposure / outage. A tooling / CI /
    process gap is **never** Critical however strong the evidence (route it via
    `ci-tooling-config`). Cite the gate line or the unconditional-path code trace.
  - **High** — `static-certain` but needs a concrete trigger (caller / edge / input), with
    the specific incorrect behavior named. If the concern is only "structurally messy /
    fragile in general / adds friction," it is Medium.
  - **Medium** — an `argued` trigger, or a real structural weakness with no demonstrated
    failure. The explicit default for "bad but not demonstrably breaking".
  - **Low** — a stylistic or minor structural nitpick with no meaningful failure mode.

  **Clamp:** the class band contributes only its **upper** caps — a class marked **never
  High** or **never Critical** cannot exceed that cap regardless of the tests above. The
  **evidence tier is the binding upper bound**; the band never raises a level *up* to a
  floor that would override the evidence ceiling (e.g. an `argued` finding stays Medium
  even in a High-banded class).

  **Tie-break (mechanical):** a finding whose justification **hedges between two levels** —
  contains any of `arguable`, `borderline`, `could be`, `may be`, `might be`, `possibly`,
  `High or Medium`, `Medium or High` (or the equivalent for any adjacent pair) — resolves
  to the **lower** level. Hedged uncertainty is never resolved upward.

  **Severity predicate (the High claim).** `High` is not asserted directly — it is
  **earned by filling a three-slot predicate**. Any finding you would rate High must state:
  - **Trigger:** the concrete caller / edge / input / state that causes the failure — or `none`.
  - **Failure:** the specific incorrect behavior that results — or `none`.
  - **Reach:** its evidence tier — `observed` | `static-certain` | `argued` (this slot **is**
    the evidence-tier label above; it adds no new concept).

  The level is **derived, not chosen**: **High** iff **Trigger ≠ `none`** *and*
  **Failure ≠ `none`** *and* **Reach ∈ {`observed`, `static-certain`}**. If any slot is
  `none`, empty, or hedged (a vague slot reads as `none` — see the tie-break), the
  failure-mode claim does not hold and the finding is **Medium** (or lower, per its class
  band and the tests above). A finding already fixed at Critical by the ceiling, or sitting
  at Low/Medium with no High claim, needs no predicate. Write the filled predicate as the
  finding's Criticality justification so the derivation is visible and reproducible.

  Two anchors calibrate the High/Medium line, as filled predicates:
  - *High:* a list handler string-concatenates `req.query.sort` into SQL (`src/api/list.ts:42`).
    **Trigger:** `sort=name;DROP TABLE` — a realistic query param. **Failure:** arbitrary SQL
    executed against the DB. **Reach:** `static-certain` given that trigger. All three filled →
    **High** (`input-validation-boundary`).
  - *Medium:* the same handler re-implements the pagination clamp already in `src/lib/paging.ts`
    (`src/api/list.ts:20`). **Trigger:** `none` — no specific input yields a wrong result today.
    **Failure:** `none` — structural duplication only. **Reach:** `argued`. A slot is `none` →
    **Medium** (`duplication-divergence`).
- **Scope** — introduced within this branch's changes, or pre-existing and
  outside its scope.
- **Regression risk** — how likely a fix is to introduce new bugs, given the
  blast radius (how many call sites/consumers it touches) and how well tests
  cover that area.
- **Recommended action** — Fix now / Add to backlog / Already tracked / Opt out,
  derived below. **Already tracked** is assigned by the **Backlog cross-check**
  (below), in the normalization pipeline (`reviewer-subagent.md`), before
  Coupling-aware grouping and before any `B<n>` is minted — never chosen later, at
  the report or the gate.
- **Source** — which review pass surfaced the finding: `review-branch` (a native category,
  01–08 — the **default**, assumed when unstated), `ponytail` (category 09's normal case, but
  see `categories/09-over-engineering.md`'s Source section for its class-probe exception), or
  `both`.
  On **merge**, an entry's Source is the **union** of its members' Sources — so a native
  finding and a ponytail finding that collapse into one entry (same defect-class, same
  merge-unit scope) yield `both`. The merge unit already decides "these are the same defect";
  Source adds no comparison of its own. Source is **provenance, not a decision input**: it
  never affects criticality, regression risk, or the recommended action.

## Defect-class taxonomy

Every finding is classified into **exactly one** defect-class from this closed list
(evaluate top-down; first match wins). The class supplies two mechanical inputs to the
normalization pass (`reviewer-subagent.md`): its **merge unit** (what makes two
occurrences one finding) and its **severity band** (the allowed min–max level, clamped in
the Criticality derivation above).

| Defect-class | What it is | Merge unit | Severity band |
| --- | --- | --- | --- |
| `runtime-crash-or-dataloss` | unhandled path that crashes / corrupts / loses data on a reached path | per crash site | High–Critical |
| `reactivity-stale-state` | fails to update / shows stale data (non-reactive store, stale alert, frozen clock) | per hook/store/component | Medium–High |
| `correctness-logic` | wrong output under a nameable trigger (bad math, off-by-one, minute-carry) | per function | Medium–High |
| `input-validation-boundary` | unvalidated/untrusted data crossing a trust boundary (injection, out-of-range) | per boundary | Medium–High |
| `error-handling-gap` | missing/empty catch, swallowed error, unguarded parse/fetch | per file | Low–Medium |
| `duplication-divergence` | same logic copied; drift risk or already diverged | per duplicated concept (all copies = one entry) | Low–Medium |
| `redundant-implementation` | code or a dependency reimplementing what the stdlib or platform already ships | per duplicated capability | Low–Medium — **never High** |
| `misplaced-or-fragile-integration` | domain logic in the wrong layer; reaching into another module's internals | per integration point | Medium |
| `oversized-low-cohesion` | file too large / mixes 3+ concerns | per file | Medium — **never High** |
| `performance-hotpath` | unbatched / O(n²) / per-frame work on a hot path | per file/hook | Low–Medium |
| `test-gap-or-weak-test` | untested module; tautological / assertion-free / mislabeled test | per file | Low–Medium — **never High** |
| `ci-tooling-config` | build/lint/CI/tsconfig defect (non-enforcing gate, missing include, unpinned dep) | per config concern | Medium — **never Critical** |
| `security-hardening` | missing headers, root container, permissive config with no active exploit path | per surface | Low–Medium |
| `docs-drift` | stale / missing docs | per doc | Low (Medium only if it causes failed runs, e.g. a wrong build command) |
| `style-deadcode-magic` | naming, magic numbers, dead code, nits | grouped per regression band (Low-band consolidation) | Low |

- **Merge unit → the reported finding count.** One entry per **(class × merge-unit
  scope)**: one file's defects that span several classes (e.g. `reactivity-stale-state`,
  `correctness-logic`, `performance-hotpath`, `test-gap-or-weak-test`) become one finding
  **per class present**, each enumerating its sites — not one lumped finding, not
  one-per-site. Findings of **different classes never merge**, even in the same file.
- **Class precedence.** When a defect matches both a specific-defect class and
  `duplication-divergence`, the specific class wins by top-down order; `duplication-divergence`
  applies only when drift risk between copies is the **sole** defect.
- **`duplication-divergence` vs `redundant-implementation`.** Both concern a capability that
  exists twice, so top-down order alone is not enough — the line is *where the other copy
  lives*. **`duplication-divergence`**: the copies are **both inside the repo** and drift
  **against each other**; remediation is to consolidate them. **`redundant-implementation`**:
  the counterpart is **outside the repo** (the standard library, the platform, an
  already-installed dependency) and does not drift with it; remediation is to delete the local
  copy and call the external thing.
- **Severity band → the ceiling.** The hard caps (**never High**, **never Critical**) are
  unconditional. Within a band, the **evidence tier** (Criticality field above) sets where a
  finding lands — e.g. an `argued` empty catch is Low, while a `static-certain` swallowed
  error on a reached path is Medium (the class cap); the tier never pushes a finding above
  its band. The clamp is applied mechanically in the normalization pipeline
  (`reviewer-subagent.md`).

## Recommended-action derivation

**Diff mode** (default — the branch is compared against a base; findings may be
in-scope or pre-existing):

- In-scope (introduced by this branch), Medium+ → **Fix now** — the branch hasn't
  merged, so address it before shipping known-bad new code.
- Out-of-scope (pre-existing), Medium+, **low** regression risk → **Fix now** —
  low blast radius makes it safe to address immediately.
- Out-of-scope, Medium+, regression risk **not low** → **Add to backlog**. Group
  related issues (same module/root cause/concern) into a single tech-task entry
  via the `add-backlog` skill. Carry each issue's criticality + justification and
  regression-risk level + justification into the entry — it must not read as
  lower-signal than the finding. Set the entry's `priority:` per the **Backlog
  priority** rule below.
- Low criticality, **low** regression risk (any scope) → **Fix now** — as with any
  low-risk issue, the low blast radius makes it safe to address immediately.
  (Recommended action only; the user-decision gate below still applies.)
- Low criticality, regression risk **not low** → present the user three options
  per issue — Fix now / Add to backlog / Opt out — defaulting to **Add to backlog**
  for anything the user doesn't otherwise decide. Group all remaining
  backlog-bound Low issues into a single `add-backlog` entry, separate from any
  Medium+ entry above and not partitioned by relatedness. For each issue folded
  into the entry, carry its description, scope, and **regression-risk level +
  justification** — a Low issue's regression risk must be stated explicitly; the
  entry must not read as lower-signal than the finding. Only create the entry if at
  least one Low issue remains at Add to backlog after Fix-now and Opt-out choices
  are applied. This Low entry's `priority:` is `low` (the **Backlog priority** rule).

**Baseline mode** (everything is pre-existing; the in-scope axis does not apply):

- **Fix now ⟺ low regression risk** (any criticality) — the only Fix-now path.
- Otherwise → **Add to backlog**, setting `priority:` per the **Backlog priority**
  rule below (1:1 from criticality); **Opt out** available (esp. Low).
- **Split** un-actionable fixes: fix the safe, in-reach part now; backlog the rest
  (its `priority` per the **Backlog priority** rule — a Critical remainder →
  `priority: critical`).
- The user-decision gate still applies.

## Backlog cross-check

**Timing.** This runs in the normalization pipeline (`reviewer-subagent.md`),
immediately after **Low-consolidate** and before **Coupling-aware grouping** /
`B<n>` assignment (below) — **not** "before creating backlog entries" at framework
step 6. By framework step 6 the report has already been shown and the user has
already decided at the gate; checking that late means a finding gets shown and
decided as if it were new, then silently discovered to be a duplicate afterward.
Applies in **both** diff and baseline modes, wherever the derivation above assigns
**Add to backlog** — `Fix now` and `Opt out` entries are never checked.

**What to check against.** For each Add-to-backlog entry (the post-merge,
post-Low-consolidate unit — the same unit a `B<n>` would attach to), read the
target repo's existing backlog stubs: `docs/features/backlog/` and
`docs/tech-tasks/backlog/`, **including** their `promoted/` and `rejected/`
subdirs. This is intentionally **broader** than the `add-backlog` skill's own
Existing-match sweep, which excludes `promoted/`/`rejected/` from its own overlap
comparison — that skill is protecting the *active* backlog from duplicates; this
check is asking "has this already been recorded anywhere" (a promoted stub is
already becoming a real spec; a rejected stub was already explicitly declined),
so a new stub would be redundant or contrary in either case, not only in the
active backlog.

**Binary, not interactive.** The reviewer subagent never talks to the user (see
`reviewer-subagent.md`), so this check has no dialogue — only a strict
**Overlap** match (using the same test the `add-backlog` skill's Existing-match
sweep uses: same intent and scope — the existing stub already covers this entry
in full) converts the entry's recommended action from `Add to backlog` to
`Already tracked (<stub path>)`. Anything weaker — a **Close match** (related but
distinct scope) or **No relation** — is *not* Already tracked; it proceeds as
`Add to backlog` as usual, and any finer-grained overlap (including Close-match
enrichment) is left to `add-backlog`'s own interactive Existing-match sweep when
the entry is actually routed there at framework step 6. Do not attempt
Close-match reasoning here — that resolution requires a user and this pass has
none.

*Example:* a `duplication-divergence` finding at `src/api/list.ts:20`
re-implements pagination clamping — same intent (consolidate the duplicated
clamp) and same scope (this exact duplication) as
`docs/tech-tasks/backlog/B-042-consolidate-pagination-clamp.md` → **Overlap** →
`Already tracked (docs/tech-tasks/backlog/B-042-consolidate-pagination-clamp.md)`,
no `B<n>` minted.

**Already tracked excludes the entry from coupling and `B<n>`.** An entry marked
`Already tracked` is removed from the pool Coupling-aware grouping draws from
(below) — it is never folded into a new `B<n>` group and never mints one of its
own. If a coupled set has one member marked `Already tracked` and others not, the
matched member is **excluded** from the set; the remaining members retain their
coupling among themselves and form (or join) a `B<n>` normally. When a member is
excluded this way, the resulting `B<n>` entry's description must name the
excluded member's stub — `related: <stub path> (covers <member ID>, tracked
separately)` — so the shared-remediation context is not lost even though the two
are now recorded in different places.

**No new priority, no add-backlog routing.** An `Already tracked` entry carries
no `priority:` and is never passed to the `add-backlog` skill (framework step 6)
— it mints nothing.

## Backlog priority

**Every `Add to backlog` entry carries a `priority`**, mapped **1:1** from the entry's
**highest-criticality** member: Critical → `critical`, High → `high`, Medium → `medium`,
Low → `low`. This applies in **both** modes and to grouped/coupled entries (which take
the highest member's criticality). Pass this priority to the `add-backlog` skill
(framework step 6) so the stub's `priority:` frontmatter is written — an omitted priority
is a defect, not the default.

`Already tracked` entries (the backlog cross-check, above) are not `Add to
backlog` entries and carry no `priority`.

## Coupling-aware grouping & disposition

Applies to **both** modes (diff and baseline). Run this **before finalizing
dispositions** — after each finding has its default recommended action from the
derivation above, but before backlog entries are created and the report is
compiled. The pool this draws from **excludes** any entry the backlog
cross-check (above) already marked **Already tracked** — that entry is settled
before grouping starts; if it was the excluded member of an otherwise-coupled
set, the cross-check section above defines what the remaining members' `B<n>`
entry must note about it.

- **Tightly coupled** = one remediation addresses them / cannot be fixed
  independently.
- **Shared disposition:** the whole set is Fix now only if all members are
  low-regression and **in-reach** (fixable within this branch/repo now — not
  requiring separate cross-team/backend work); else one backlog entry (or Opt out).
- **One entry, highest priority:** a backlogged coupled set is a single
  `add-backlog` entry regardless of members' individual criticality; the entry's
  `priority` = the **Backlog priority** mapping of the **highest-criticality** member
  (Critical → `critical`, High → `high`, …); carry every member's description +
  criticality + regression-risk (with justifications).
- **Overrides** the default partitioning (Medium+ by relatedness, Low lumped);
  coupling wins.
- **Complements** the split rule (separable → split; tightly coupled → can't split).
- **Distinct entries, never merged.** Coupling operates on **already-merged entries**
  (each with its own ID from the **defect-class merge unit** (see **Reporting the
  findings** below)) and only decides that several
  **distinct** entries share **one backlog entry**. Findings of the **same defect-class
  and merge-unit scope** are already one entry via the merge unit; coupling covers the
  rest — **distinct** entries (a different class, or a different scope) whose fixes must
  happen together (e.g. one module refactor).
- **Provisional backlog-group ID.** Give each coupled/partitioned backlog group a
  provisional ID `B1`, `B2`, … (prefix `B`, so it never collides with the
  `C`/`H`/`M`/`L` finding IDs) and render it **inline in the Recommended-action
  cell** at the gate: `Add to backlog (B1)`. Only findings whose recommended action
  is `Add to backlog` carry a `B<n>`; `Fix now` / `Opt out` show a bare action, and
  `Already tracked` shows the matched stub's path instead — `Already tracked
  (<stub path>)` (see the backlog cross-check, above) — never a `B<n>`, since no
  new entry is minted for it. It is
  **provisional**: it reflects the *recommended* grouping — if the user changes a
  member's disposition at the gate, the entry shrinks; when `add-backlog` runs
  (framework step 6), each `B<n>` with ≥1 member still routed to backlog becomes
  exactly one entry. Finding IDs stay **1:1** — the `B<n>` is an annotation, never a
  merge, so the reported count is unchanged. (`B<n>` is assigned deterministically in
  the normalization pass, `reviewer-subagent.md`, so the same findings always yield
  the same groups.)

## Carry forward previously-ignored issues

Both diff and baseline reviews re-scan their full scope each time (a diff review
from the base, a baseline review across the whole repository), so a re-review
re-encounters issues that a **prior** review already surfaced and the user chose
to **Opt out** of. An opted-out issue is recorded nowhere but the report, so
without this step the settled opt-out is silently re-litigated on every
re-review. Run these steps before reporting (framework step 4):

1. **Load the latest report.** Find the single latest report in `docs/reviews/` —
   the max-`NNN` file, whether `branch_review_<NNN>` or `repository_baseline_<NNN>`,
   regardless of family — and read its **Issues Ignored** section. Each report
   re-imports the still-relevant ignored issues from its predecessor regardless of
   which mode produced it, so the latest transitively holds them all — this is why
   only the single latest file, not the latest per family, is needed. If there is no
   prior report, skip this section.
2. **Relevance re-check (explicit, required).** For each ignored entry, locate the
   code / file / condition it referenced **in the current tree** and confirm the
   problem still exists. Code may have been changed, refactored, moved, or deleted
   since the opt-out — an entry whose target is gone, or whose problem no longer
   holds, is **no longer relevant**. Do not assume; verify against the working tree.
3. **Carry forward the still-relevant entries.** Re-import each into this review's
   Issues Ignored (preserving its original **Why ignored** and naming the origin
   report — including its original ID — on the **Carried forward:** line). It is
   assigned a fresh ID in this review's per-criticality sequence (see "Reporting the
   findings" — carried-forward entries share the sequence with fresh findings, so
   IDs never collide). **Drop** the rest — do not carry them forward and do not
   re-raise them; their record persists in the older report in git history.
4. **Do not re-litigate.** A carried-forward issue keeps its settled opt-out — do
   **not** re-raise it as a fresh finding or re-open it for a new decision. If a new
   finding from the category walk matches a carried-forward entry, map it to that
   entry instead of opening a new decision. A carried-forward issue's blast radius
   growing (e.g. this branch adds a new caller) does **not** by itself reopen the
   opt-out; but a genuinely **new** problem this branch introduced — such as the new
   call site itself being unguarded — is its own in-scope finding, tagged and
   decided normally, separate from the carried-forward pre-existing issue.

Surface a one-line note when reporting (framework step 4), e.g. "N of M prior
ignored issues still relevant, carried forward", so the carry-forward is transparent
without forcing a re-decision.

**Independent of the backlog cross-check.** Carry-forward and the backlog
cross-check (above) are separate mechanisms over separate corpora — carry-forward
re-imports a prior review's **opt-outs** (recorded only in past report files); the
cross-check matches against **existing backlog stubs** (recorded in the target
repo's backlog directories). A carried-forward issue never re-enters
Recommended-action derivation (step 4 above: it "keeps its settled opt-out"), so
it is never subject to the cross-check — an opted-out issue and a backlog-tracked
issue are two different, independently-recorded dispositions and do not need
reconciling against each other. **Open question, not resolved here:** if a
backlog stub is created for an issue *after* it was opted out and carried forward
(e.g. by a separate `add-backlog` invocation outside this review), the relevance
re-check (step 2 above) does not check for that — the issue would keep being
carried forward as ignored even though it now also has a stub. Flagged for a
future revision rather than decided here.

## Reporting the findings

**Group repeated findings before assigning IDs — by the defect-class merge unit.**
Detection is exhaustive (`framework.md` step 3), so the same defect is often recorded at
many sites. Two findings are **one entry** (one ID) **iff** they share the **same
defect-class *and* the same merge-unit scope** for that class (see **Defect-class
taxonomy** — e.g. `duplication-divergence` merges per duplicated concept,
`oversized-low-cohesion` per file, `runtime-crash-or-dataloss` per crash site). Findings
of **different classes never merge**, even in the same file. A merged entry has one ID, a
description that **enumerates every affected `file:line`**, and one band-clamped severity
(the **highest** member's if sites genuinely differ). Every occurrence stays recorded
inside that entry — merging is a presentation roll-up, never a reason to drop a site. The
merge unit is the **only** thing that changes the reported finding count; broader coupling
(below) annotates entries for the backlog but **never merges** them. A merged entry's
**Source** is the **union** of its members' (see Fields above) — an entry merging a native
and a ponytail finding is `both`.

**Finding layer vs backlog layer.** That count-governing merge unit, at **High/Medium,
never collapses across scope**:
a class present in N distinct scopes (per its taxonomy merge unit — per file / per hook / per
boundary) produces **N findings**, each enumerating its own sites — e.g.
`oversized-low-cohesion` across 7 files is **7 findings, not 1**. Only same-class findings in
the **same** scope merge. All further tidying is the **backlog (`B<n>`) layer's** job:
coupling grouping puts related findings (across files and classes) into one `add-backlog`
entry **without reducing the reported finding count**. "Same file / same subsystem → one
backlog entry" is a `B<n>` grouping, never fewer findings.

**Regression-boundary merge invariant.** No merge — at any severity — combines findings
across the **low ↔ not-low** regression boundary (the boundary that decides Fix-now vs
backlog/opt-out in "Recommended-action derivation"). Findings only consolidate with others
in the same regression band, so a merged entry's members share a disposition and taking the
**highest** member's risk never sweeps a Fix-now-safe finding into the backlog.

**Low-band consolidation.** After severity is finalized, findings at **Low** merge to one
entry per **(defect-class × regression band)** — the band being binary **low vs not-low** —
overriding the per-(class × scope) merge unit that governs High/Medium. Each class
contributes at most two Low entries: a **low-regression** batch (Fix-now-safe) and a
**not-low-regression** batch (backlog-bound), each enumerating every affected `file:line`,
never merged across the boundary. A consolidated batch's **Source** is the union of its
members' — consolidation merges by (class × band), not by Source, so a batch holding both
native and ponytail members is `both`. The Low entry count is the number of distinct
(class × band) pairs present — not the number of sites — so it is insensitive to per-site
detection depth. (This generalizes the `style-deadcode-magic` "grouped" merge unit to every
class that lands at Low.) The **not-low-regression** (backlog-bound) batch is
the unit the backlog cross-check (above) checks as a whole — a match must cover
the **entire** consolidated batch to mark it `Already tracked`; a stub covering
only some of the batch's enumerated sites does not clear the Overlap bar, and
the batch proceeds to `Add to backlog` as usual.
This per-class collapse applies **only at Low** (Low findings are bulk-dispositioned).
**High and Medium keep `(class × scope)` granularity** and never collapse a class into a
single entry — do not generalize this Low rule upward.

First assign each finding its **ID** (see Fields above): order findings by
criticality (Critical → Low) and number them per-criticality — `C1, C2, …`, then
`H1, H2, …`, then `M1, …`, then `L1, …`. **Carried-forward ignored issues are numbered
into this same per-criticality sequence alongside fresh findings** — never with a
separate or retained numbering — so IDs never collide within a report (a
carried-forward Medium and a fresh Medium do not both become `M1`). A
carried-forward entry may therefore receive a different ID than it had in its origin
report; record its origin — including its original ID — on the report's
`Carried forward:` line. Finding-generation and this tagging may be
performed by a dispatched **independent reviewer subagent** (`reviewer-subagent.md`);
if so, it assigns the IDs and the orchestrator presents the returned findings at the
gate below unchanged, rather than re-deriving them. That reviewer re-derives
severity, applies the merge unit, and assigns `B<n>` in its **normalization**
sub-step (`reviewer-subagent.md`) before assigning IDs, so all three are
reproducible run to run.

Then present the findings for the decision gate as a **table** with these six columns,
in this order:

| Column | Contents |
| --- | --- |
| **ID** | the finding's ID (`C1` / `H2` / …) |
| **Finding** | the **Source badge** (below) then the one-sentence description with its `file:line` location |
| **Criticality** | the level **and its justification** (the failure mode + how it worsens over time) |
| **Scope** | in-scope (introduced by this branch) / pre-existing (baseline) |
| **Regression risk** | the level **and its justification** (blast radius × test coverage) |
| **Recommended action** | Fix now / Add to backlog / Already tracked / Opt out |

The **Finding** cell opens with a **Source badge** when the finding is not native-only:
`[ponytail]` when Source is `ponytail`, `[both]` when Source is `both`, and **no badge** when
Source is `review-branch` — e.g. `[ponytail] 27-line validator class duplicates stdlib
(src/val.ts:12-38)`. The badge is deliberately **not** a seventh column: it keeps the
six-column structure fixed, and a Source column would read `review-branch` on most rows. A
page-design skill styles the badge; it does not decide whether it is there.

The **Recommended action** cell shows the provisional backlog-group ID for
backlogged findings, e.g. `Add to backlog (B1)`; findings sharing a `B<n>` will
become one `add-backlog` entry. These groups are **provisional** — a user's
disposition change at the gate may shrink one. An entry the backlog cross-check
matched to an existing stub shows `Already tracked (<stub path>)` instead — it
carries no `B<n>`, since no new backlog entry is minted for it (the backlog
cross-check, above).

When category 09 ran, carry ponytail's closing metric as a one-line note beside the
carry-forward note (e.g. *"ponytail: net -120 lines possible (pre-merge, pre-gate estimate)"*,
or its `Lean already. Ship.` verdict). Mark it a **pre-merge, pre-gate estimate**: it is
computed before findings merge, consolidate, and route to backlog, so it will not reconcile
with what is actually cut. Omit the note entirely when category 09 was skipped.

This note belongs to the **gate report only** — the durable review report (`report.md`)
does **not** carry it. Its whole value is live: it sizes the over-engineering pass while
you are deciding what to fix. By the time the durable report is written, the findings have
merged, consolidated, and routed to the backlog, so the estimate no longer reconciles with
anything a later reader could check — a number in the permanent record that was never true
of the merged branch is worse than no number.

Choose the **rendering** by a fixed rule — the finding count — not by judgement:

- **More than three findings (4+)** *and* the agent can render a hosted HTML page
  (e.g. Claude Code's `Artifact` tool): the page renders **exactly the six-column table
  above** — one row per finding, those six columns in that order, `ID` first, rows grouped
  and color-coded by criticality. The page *is* that table, not a design derived from it.

  **The structure above is fixed by this skill; a page-design skill governs only
  appearance.** If your harness requires a design-guidance skill to render the page (e.g.
  Claude Code mandates loading `artifact-design`), load it — but its remit is **visual
  styling only**: palette, typography, spacing, and how criticality is color-coded. It does
  **not** decide the columns (their set, their order, or their names) or the table's
  structure. Concretely, its dashboard/card guidance must not replace the table: no cards,
  tiles, summary pills, or severity-stripe layouts standing in for the columns; no moving a
  column's content into a hover or expander; no dropping the **Criticality** or **Regression
  risk** justifications out of their cells into a summary. **When the two conflict, this
  skill's structure wins and the design skill styles within it.**

  **The notes ride with the table.** "Exactly the six-column table" fixes the table's
  structure; it does not license dropping the carry-forward note or the ponytail
  net-lines note. Render both beside the table on the page (they are notes, not a seventh
  column, and not rows). The net-lines note appears **nowhere else** — the durable report
  omits it — so a page that drops it loses it for good.

  Pair the page with a short inline list in the conversation, one line per finding by ID
  (e.g. `H2 — <finding> (recommended: Fix now)`), since the page is static and the
  per-issue decisions happen through discussion.
- **Three or fewer findings, *or* no HTML-rendering capability:** present the **same
  six-column table** directly in the conversation as markdown/text — this is the primary
  report, so every cell carries its full detail (the **Criticality** and **Regression
  risk** cells include their justifications), never a terse one-liner. Decisions are then
  made by ID against this table.

Either way, every finding must be referenceable by its **ID** so the user can decide
by ID at the gate below. (An empty finding set needs no page — state that the review
found nothing.)

## User decision gate

After reporting, do **not** start implementing any "Fix now" issue immediately.
Present the complete findings report first and wait for explicit user
confirmation on which "Fix now" issues to proceed with before making any code
changes. The user refers to issues by their **ID** (e.g. "Fix now H1 and M3, opt
out L2"). This applies even where Medium+ criticality auto-derives "Fix now" —
automatic derivation decides the recommended action, not whether to act without
asking.

When the user chooses **Opt out** for an issue, capture a short **rationale** for
the opt-out and record it as that finding's **Why ignored** in the report — the
report is the only durable record of an opted-out issue (it is not in the code or
the backlog), so an opt-out without a recorded reason loses why it was dropped. If
the user opts out without giving one, ask for a brief reason before finalizing.

**`Already tracked` needs no gate decision by default.** The backlog cross-check
(above) already settled it before the report was compiled — the issue already has
a durable home (the named existing stub), so it does not need Fix now / Add to
backlog / Opt out chosen at the gate. The user **may** still override it like any
other finding, most commonly "Fix now `<ID>`" to address it immediately despite
the existing stub; on such an override the report still records the matched stub
(`report.md`) so the user knows to consider closing or updating it — the override
adds a Fix-now disposition, it does not erase the match.
