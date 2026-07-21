# Feature-spec review rubric

Canonical rubric for reviewing a feature spec (`feature.md` + all
`stories/US-XXX-*.md` + all `use-cases/UC-XXX-*.md`). This file is the **single
source of truth** for the feature-spec content criteria: the `review-feature`
skill reads it, and the project-local `/judge-feature-spec` test command reads its
**Content criteria** section too (instead of carrying its own copy).

The rubric has two parts:

- **Content criteria** — subjective quality of the spec's wording and coverage.
  These are judgment calls.
- **Structural criteria** — mechanical conformance to the conventions and
  templates. These are checkable by direct inspection.

Each criterion has a stable `id`. When reporting verdicts, key each pass/fail on
the `id` so results stay comparable across runs and across the skill vs. the test
command.

> **Keep this current.** After any change to a feature-spec skill or its shared
> references/templates (`../refine-feature/references/conventions.md`,
> `feature.md`, `user-story.md`, `use-case.md`), re-read the affected criterion
> here and update it in the same change. A rubric that lags the templates passes
> specs it should fail.

---

## Content criteria

### `feature_title_shape`

- **Target:** `feature.md` (H1)
- **Rule:** The H1 title must be a noun phrase in `Descriptor + Core Function`
  shape, ≤5 words, that names the **feature** (a capability or thing) — **not the
  task** of building it. Drop task/process words when they only describe the
  activity rather than the feature itself: `implementation`, `support`, `rework`,
  `build`, `MVP`, `v2`, `integration of`, `add`, `enable`.
- **Pass condition:** Title is a noun phrase, has both a descriptor and a core
  function, is ≤5 words, and names the feature rather than the work of building it.
- **Examples**
  - good:
    - `Smart Search Filtering`
    - `One-Click Checkout`
    - `URL Shortener`
    - `Track Streaming`
    - `Saved Filter Sets`
  - bad:
    - `filtering` — no descriptor
    - `Track Streaming Implementation` — names the task, not the feature
    - `User Login Flow Implementation` — task-flavored and too many words
    - `The feature that lets users save filters` — sentence, not a noun phrase

### `feature_description_pattern`

- **Target:** `feature.md` → `## Description`
- **Rule:** The first sentence of `## Description` must follow
  `<Feature name> <action verb> <user benefit>`. The first sentence must contain
  no implementation language (database, API, microservice, framework, language,
  Redux, HTTP, JSON, etc.). Subsequent sentences may add context but not
  implementation detail. (Settled HOW decisions belong in `## Design constraints`,
  not the description.)
- **Pass condition:** First sentence matches the pattern, value-prop is explicit,
  and no implementation language appears anywhere in the Description body.
- **Examples**
  - good:
    - `Smart Search Filtering allows users to quickly narrow down search results by applying multiple filters, saving time and improving the search experience.`
    - `URL Shortener allows users to submit a long URL and receive a compact short code, and to later resolve that short code back to the original URL.`
  - bad:
    - `This feature implements a filter pipeline using a Redux store and debounced selectors.` — implementation language
    - `Users can filter.` — no benefit clause

### `scope_pair_balanced`

- **Target:** `feature.md` → `### In scope` / `### Out of scope`
- **Rule:** Both `### In scope` and `### Out of scope` (nested under
  `## Description`) must be non-empty. `### Out of scope` must explicitly exclude
  at least one *adjacent* capability with a one-line reason — not just a list of
  names with no rationale.
- **Pass condition:** In scope has ≥1 bullet, Out of scope has ≥1 bullet, and ≥1
  Out-of-scope item has a reason clause attached.

### `story_acceptance_criteria_testable`

- **Target:** all `stories/US-XXX-*.md` → `## Acceptance Criteria`
- **Rule:** Each `## Acceptance Criteria` bullet across every story must be
  verb + observable outcome that a reviewer can verify by direct observation.
  Aspirational language ("users feel happy", "the experience is delightful") and
  vague language ("the system works correctly", "performance is good") both fail.
- **Pass condition:** Every acceptance-criterion bullet across all story files is
  testable.
- **Examples**
  - good:
    - `Given a valid long URL, when the user submits it, then the service returns a short code matching [a-z0-9]{6,8}.`
    - `Saving a filter set with an empty name surfaces a validation error in red text below the input.`
  - bad:
    - `Users should be able to easily find their filter sets.` — vague; what does "easily" mean?
    - `The system works correctly under load.` — not observable

### `use_case_main_flow_concrete`

- **Target:** all `use-cases/UC-XXX-*.md` → `## Main flow`
- **Rule:** Each use case's `## Main flow` must be numbered actor-step
  interactions in third person, present tense. Steps must name the actor (user,
  system, service) and the action. Abstract prose ("the system processes the
  request") or implementation steps ("the request is routed to the controller")
  both fail.
- **Pass condition:** Every Main flow across all use-case files is concrete
  actor-step.

### `use_case_coverage_complete`

- **Target:** cross-reference (`feature.md` + stories + use-cases)
- **Rule:** Every `AC-N` bullet in every story's `## Acceptance Criteria` must be
  exercised by at least one use case's `## Main flow` or `## Alternate flows` —
  either explicitly cited (e.g. the story's `## Use cases` list maps
  `UC-X — covers AC-1, AC-2`) or implicitly covered by the use case's step pattern.
- **Pass condition:** No acceptance criterion is orphaned (no use case exercises
  it).

### `use_case_inputs_specified`

- **Target:** all `use-cases/UC-XXX-*.md` → `## Data and contracts → Inputs`
- **Rule:** Every input a use case declares must carry both its **schema**
  (fields/types, required vs optional with defaults, format/precision/units,
  validation rules and ranges) and its **volumetrics** (max/peak rate, per-item
  and batch size, frequency) — omitting a dimension only where it genuinely does
  not apply. A use case additionally fails if it leaves a determinism-critical
  dimension unspecified where the behavior depends on it: defaults for optional
  inputs, rounding/precision/units on computed outputs, sort/order of multi-item
  outputs, exact error identity on failure paths, or timezone/clock for
  time-dependent rules.
- **Pass condition:** Every declared input across all use-case files specifies
  schema and volumetrics, and no determinism-critical dimension the behavior
  relies on is left unspecified.
- **Examples**
  - good:
    - `upload batch: Schema — NDJSON, one order per line, amount in integer cents, required; Source — partner system; Volume — ≤ 200 msg/s peak, ≤ 5 MB/batch; Ordering — deduped by orderId; Malformed — line rejected, batch continues.`
  - bad:
    - `order data: object, from client` — no volumetrics, no validation rules, no malformed-input behavior; two implementations would diverge.

### `use_case_nfr_measurable`

- **Target:** all `use-cases/UC-XXX-*.md` → `## Non-functional requirements`
- **Rule:** Each `## Non-functional requirements` bullet must be measurable — a
  concrete threshold with units (e.g. "p95 latency < 300ms", "sustains 200
  msg/s") — and the use case must show how it is validated: at least one
  `## Validation scenarios` entry whose `Validates:` line cites the NFR, and a
  named production metric that observes it in the running system. Vague NFRs
  ("fast", "scalable", "highly available") fail, as do measurable NFRs missing a
  validating scenario or a production metric.
- **Pass condition:** Every NFR across all use-case files is measurable and has
  both a validating scenario and a production metric. A use case that declares no
  NFRs passes vacuously.
- **Examples**
  - good:
    - `p95 read latency < 300ms sustained at 200 req/s; validated by scenario S6 (Validates: NFR-1); production metric: read_latency_p95_ms.`
  - bad:
    - `The system should be fast and scale well.` — no threshold, no validating scenario, no production metric.

### `origin_provenance_truthful`

- **Target:** `feature.md` → `## Origin`
- **Rule:** `## Origin` text must match one of the calling-skill variants
  documented in the feature-spec skills:
  - `Defined on YYYY-MM-DD from user input "<quote>".` (`refine-feature`
    free-form path)
  - `Promoted from backlog stub B-XXX on YYYY-MM-DD. Stub origin: <verbatim>`
    (`refine-feature` backlog-promotion path)
  - `Derived on YYYY-MM-DD from upstream spec '<path>'.` (`derive-feature` path —
    retained while the upstream-derived Origin form is still referenced across the
    feature-spec skills)
  - `Split from F-XXX <title> during refine-feature on YYYY-MM-DD. <reason>`
    (`refine-feature` split-off path)
- **Pass condition:** Origin text matches one variant with a valid `YYYY-MM-DD`
  date and the variant-specific fields populated.

### `id_refs_formatted_for_gitlab`

- **Target:** `feature.md` + stories + use-cases
- **Rule:** File-level ID references must be written as markdown links, not plain
  text:
  - In `feature.md`'s `## Stories`, every `US-NNN` entry must use the form
    `[US-NNN: title](stories/US-NNN-slug.md)`.
  - In each story's `## Use cases`, every `UC-NNN` entry must use the form
    `[UC-NNN: title](../use-cases/UC-NNN-slug.md)`.
  Any identifier matching `[A-Z]+-\d+` (one or more uppercase letters, a hyphen,
  one or more digits) must be wrapped in backticks — in both prose and headings —
  unless it is inside a markdown link's text (Exception A) or an intentional JIRA
  issue reference (Exception B). Identifiers without a hyphen (e.g. `S1`, `S2`)
  are exempt. See `../refine-feature/references/conventions.md` →
  "Reference formatting in generated documents" for the full rule and both
  exceptions.
- **Pass condition:** All `US-NNN` entries in `## Stories` are markdown links; all
  `UC-NNN` entries in `## Use cases` are markdown links; all `[A-Z]+-\d+`
  identifiers in prose and headings are backtick-wrapped (unless they fall under
  Exception A or B).
- **Examples**
  - good:
    - `- [US-001: Create a filter set](stories/US-001-create-filter-set.md)`
    - `- [UC-001: Save state](../use-cases/UC-001-save-current-filter-state.md) — covers `AC-1``
    - `**Validates**: `STEP-1`..`STEP-4`, `BR-1``
    - `### `AF-1`: payment declined (branches from `STEP-3`)`
  - bad:
    - `- US-001: Create a filter set` — plain text, would JIRA-autolink
    - `- UC-001: Save state — covers AC-1` — plain text + bare `AC-1`
    - `### AF-1: payment declined` — bare `AF-1` in a heading

---

## Structural criteria

These mirror the mechanical rules the conventions and templates already define.
**Reference, don't restate** — when judging, read the cited source for the
authoritative wording. (In this repo these also back the `validate_spec.py` rule
list; in an installed repo only the conventions/templates ship, so this section is
the user's only structural check.)

### `feature_md_required_sections`

- **Target:** `feature.md`
- **Rule:** The required headings from `../refine-feature/references/feature.md`
  are present, at their original levels and order: `# <Feature Title>`,
  `## Description` with `### In scope` and `### Out of scope` nested, `## Stories`,
  `## Origin`. Optional sections (`## Design constraints`, `## Dependencies`,
  `## Open questions`, `## References`) are not required, but if present must use the heading exactly.
- **Pass condition:** All required headings present at the correct level and order;
  none flattened, renamed, reordered, or omitted.

### `story_required_sections` / `use_case_required_sections`

- **Target:** each `stories/US-XXX-*.md` / `use-cases/UC-XXX-*.md`
- **Rule:** Story files carry the headings from
  `../refine-feature/references/user-story.md` (`## Story`,
  `## Acceptance Criteria`, `## Use cases`). Use-case files carry the headings
  from `../refine-feature/references/use-case.md` (`## Summary`, `## Actors`,
  `## Preconditions`, `## Postconditions`, `## Main flow`, etc.).
- **Pass condition:** Each story/use-case file has its template's required headings.

### `jira_section_managed`

- **Target:** `feature.md` `## Jira`; each `stories/US-XXX-*.md` `## Jira`; each
  tech-task `T-NNN-*.md` `## Jira` (use-case files have **no** `## Jira`)
- **Rule:** `## Jira` is pipeline-managed (see
  `../refine-feature/references/conventions.md`, "`## Jira` is pipeline-managed").
  This repo's CI pipeline creates the Jira issue and writes the link on merge; the
  section must not be hand-authored.
- **Pass condition:** Every `## Jira` section that is present carries the
  `<!-- Maintained by this repo's CI pipeline. Do not edit by hand. -->` comment
  and contains **no** hand-written Jira issue link. An empty / placeholder
  `## Jira` is correct at authoring and review time - do **not** fail it for a
  missing link (parallel to how a linkage-managed section is left for its
  pipeline).

### `stories_index_matches_files`

- **Target:** `feature.md` → `## Stories` vs. `stories/`
- **Rule:** Every `US-NNN` entry in `## Stories` resolves to an existing
  `stories/US-NNN-*.md`, and every file under `stories/` is listed in `## Stories`.
- **Pass condition:** The index and the directory are in exact correspondence (no
  dangling entries, no unlisted files).

### `use_case_files_referenced`

- **Target:** story `## Use cases` vs. `use-cases/`
- **Rule:** Every `UC-NNN` cited in any story's `## Use cases` resolves to an
  existing `use-cases/UC-NNN-*.md`, and every file under `use-cases/` is referenced
  by at least one story's `## Use cases`.
- **Pass condition:** No dangling use-case reference and no orphaned use-case file.

### `id_format`

- **Target:** all IDs in folder/file names and headings
- **Rule:** `F-XXX`, `B-XXX`, `US-XXX`, `UC-XXX` IDs are zero-padded to three
  digits per `../refine-feature/references/conventions.md` → "ID assignment".
- **Pass condition:** Every spec ID is zero-padded to three digits.

### `origin_present`

- **Target:** `feature.md` → `## Origin`
- **Rule:** `## Origin` is present and non-empty. (Provenance *truthfulness* —
  whether the text matches a known variant — is the content criterion
  `origin_provenance_truthful`; this structural check only confirms the section
  exists and is populated.) Pre-existing features drafted before the Origin
  requirement may legitimately lack the section — treat absence as a warning, not
  a hard fail, and note it.

### `epic_ref_format`

- **Target:** `feature.md` frontmatter (if present)
- **Rule:** If a YAML frontmatter block (`---`…`---`) is present and contains an
  `epic_ref:` key, its value must match `E-` followed by exactly three zero-padded
  digits (`E-001`…`E-999`). The frontmatter block itself is optional — its complete
  absence is valid.
- **Pass condition:** No frontmatter, or frontmatter without `epic_ref:`, or
  `epic_ref:` value matching `E-\d{3}` exactly.

### `priority_format`

- **Target:** `feature.md` frontmatter (if present)
- **Rule:** If a YAML frontmatter block is present and contains a `priority:`
  key, its value must be exactly one of `critical | high | medium | low`. The block and the
  key are optional.
- **Pass condition:** No frontmatter, or frontmatter without `priority:`, or
  `priority:` value one of `critical | high | medium | low`.

### `filename_slug_immutable` *(git-dependent — best-effort)*

- **Target:** story / use-case / feature folder filenames
- **Rule:** A file's slug must equal the slug it had when first added (per
  `../refine-feature/references/conventions.md` → "Filename slug immutability").
- **Pass condition:** No file has been `git mv`'d to a new slug after the H1 title
  changed. Skip silently when git history is unavailable or the file is untracked.

---

## Verdict shape

When reporting, return one row per criterion keyed on its `id`:

```
<criterion_id>: pass | fail
reason: <≤2 sentences; cite specific text from the spec where helpful>
```

After all rows, a single summary line: `summary: X/Y criteria pass`.

The `review-feature` skill renders these rows as a table for the user and then
offers to fix the failures. The `/judge-feature-spec` test command consumes the
**Content criteria** rows in this exact shape (its `response_format` and version
metadata live in `tests/feature-workflow/rubrics/feature-spec.yaml`).
