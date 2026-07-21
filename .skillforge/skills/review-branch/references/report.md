# Review report

After all fixes and backlog entries are applied, write a durable report so the
review outcome is queryable later.

## Path

- **Diff mode:** `docs/reviews/branch_review_<NNN>.md`.
- **Baseline mode:** `docs/reviews/repository_baseline_<NNN>.md`.

`<NNN>` is a **single global**, zero-padded counter shared across both filename
families — not per-branch and not per-mode. Derive the next number by scanning
**all** existing reports in `docs/reviews/`, extracting each file's trailing
`_<NNN>` (tolerating the legacy per-branch `branch_review_<slug>_<NNN>` form),
and taking max + 1:

```bash
mkdir -p docs/reviews
last=$(ls docs/reviews/*_[0-9][0-9][0-9].md 2>/dev/null \
  | sed -E 's#.*_([0-9]{3})\.md$#\1#' | sort -n | tail -1)
next=$(printf '%03d' $(( 10#${last:-0} + 1 )))
# diff:     report="docs/reviews/branch_review_${next}.md"
# baseline: report="docs/reviews/repository_baseline_${next}.md"
```

Branch identity no longer lives in the filename — it lives in the header
(`## <date> - <branch> [<review_sha>]`, see Format below).

## Format

```md
## {{review_date}} - {{branch_reviewed}} [{{review_sha}}]

### Issues Fixed

- {{issue_id}} ({{issue_criticality}}, regression: {{regression_risk}}): {{issue_summary}}

### Issues Added to Backlog

- {{backlog_group}} ({{priority}}): {{one-line summary of the entry}} — members: {{id, id, …}}
  - {{issue_id}} ({{issue_criticality}}, regression: {{regression_risk}}): {{issue_summary}}

### Issues Already Tracked

- {{issue_id}} ({{issue_criticality}}, regression: {{regression_risk}}): {{issue_summary}} — already tracked: {{stub_path}}

### Issues Ignored

- {{issue_id}} ({{issue_criticality}}, regression: {{regression_risk}})
  - **Issue:** {{what the issue is and where — full description, not a one-liner}}
  - **Criticality:** {{issue_criticality}} — {{justification: the failure mode and how it worsens over time}}
  - **Scope:** {{in-scope (introduced by this branch) | pre-existing / out of scope}}
  - **Regression risk:** {{regression_risk}} — {{justification: blast radius × test coverage}}
  - **Why ignored:** {{the user's rationale for opting out}}
  - **Carried forward:** {{omit this line if first ignored in this review; else `from <origin_report_filename>` (was <origin_id> there) — the origin filename is whichever family produced it, `branch_review_<NNN>.md` or `repository_baseline_<NNN>.md`}}
```

- `{{review_date}}` — the review date (`YYYY-MM-DD`).
- `{{branch_reviewed}}` — the un-slugified branch name.
- `{{review_sha}}` — the finalized branch tip captured after the squash step.
- **No ponytail net-lines note.** Ponytail's `net: -<N> lines possible` metric belongs to
  the gate report only (`decision-framework.md`) and is deliberately absent here: it is
  computed before findings merge, consolidate, and route to the backlog, so it never
  reconciles with what the branch actually cut. Do not add it back.
- `{{issue_id}}` — the finding's ID from the review (criticality initial + a
  per-criticality counter, e.g. `H2`), so the durable report cross-references the
  same IDs used during the review.
- Findings whose **Source** (`decision-framework.md`) is `ponytail` or `both` keep their
  `[ponytail]` / `[both]` badge at the front of the `{{issue_summary}}` in whichever section
  they land, so the durable report shows which pass surfaced each finding. Native-only
  findings carry no badge.
- `{{regression_risk}}` — the finding's regression-risk level from
  `decision-framework.md` (e.g. `low`/`medium`/`high`). **Record it on every
  issue**, whatever the criticality — a later reader auditing the report should see
  the risk a fix carried without re-deriving it.
- **Issues Fixed** is one line each: `- <ID> (<Criticality>, regression: <risk>):
  <one-line summary>`. Its full detail lives elsewhere — in the commit/code — so a
  one-liner suffices. If the user overrode an **Already tracked** default to Fix
  now (`decision-framework.md`'s User decision gate), append `— already tracked:
  <stub path> (consider closing/updating it)` to the line, so the fixed-here /
  tracked-elsewhere overlap stays visible.
- **Issues Added to Backlog** is one line per backlog group, `{{backlog_group}}
  ({{priority}}): {{one-line summary of the entry}} — members: {{id, id, …}}`, with
  one indented sub-line per member finding. `{{backlog_group}}` is the entry's `B<n>`
  from the review; its member finding IDs are listed so the durable report shows
  which findings fused into each `add-backlog` entry, mirroring what the gate showed.
  A single-finding backlog entry still gets a `B<n>`.
- **Issues Already Tracked** is one line each: `- <ID> (<Criticality>, regression:
  <risk>): <one-line summary> — already tracked: <stub path>`. `{{stub_path}}` is
  the repo-relative path to the existing stub the backlog cross-check
  (`decision-framework.md`) matched — its full detail lives in that stub, not
  here, mirroring why **Issues Fixed** stays a one-liner. This section is
  populated entirely by the cross-check's `Already tracked` disposition, assigned
  during finding-generation before the report is compiled — the user does not
  choose it at the gate, only overrides it (see **Issues Fixed** above).
- **Issues Ignored uses the full-detail block above** (Issue / Criticality / Scope /
  Regression risk / Why ignored / Carried forward). An opted-out issue is recorded
  **nowhere else** — not in the code, not in the backlog — so the report is its only
  durable trace: it must carry enough detail to reconstruct the finding and the
  reason it was dropped **without** the original review conversation. **Why ignored**
  is the rationale captured at the decision gate (`decision-framework.md`).
- The Ignored section lists **both** issues newly opted out in this review **and**
  still-relevant issues **carried forward** from the latest prior report per
  `decision-framework.md` (each with a **Carried forward:** line naming its origin
  report and its original ID there). Carried-forward entries are numbered into this
  review's per-criticality ID sequence alongside fresh findings, so an entry's ID
  here may differ from its origin ID and IDs never collide within a report. Issues
  whose target code was resolved since the prior review are dropped, not listed.
- Include every finding under exactly one of the four sections, matching the user's
  decisions. If a section has no items, keep the heading and write `- None`.

## Confirm before committing

Show the drafted report to the user and get confirmation of its contents before
committing it (framework steps 10–11).
