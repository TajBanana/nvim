# Naming & numbering conventions

Shared across the feature-spec skills (`refine-feature`,
`implement-feature`, `reconcile-feature`, `change-feature`). (`derive-feature`
was retired.) The feature-spec
skills are install-together, so the relative path
`../refine-feature/references/conventions.md` resolves at runtime from
sibling skills, and `references/conventions.md` from `refine-feature`
itself.

## Slug rule (lowercase-kebab-case)

To slug a title (for `F-XXX-<slug>` folder names, `B-XXX-<slug>.md` backlog
filenames, `T-XXX-<slug>.md` tech-task filenames, or `US-XXX-<slug>` /
`UC-XXX-<slug>` story/use-case filenames):

1. **Strip removable punctuation:** delete apostrophes (`'` and `’`),
   straight and curly quotes (`"` `“` `”`), backticks, periods, commas,
   colons, semicolons, parentheses, brackets, and slashes.
2. **Lowercase** the remaining string.
3. **Replace remaining whitespace and punctuation** (anything outside
   `[a-z0-9]`) with `-`.
4. **Collapse runs** of `-` and strip leading/trailing `-`.

Examples:

- `Smart Search Filtering` → `smart-search-filtering`
- `User's Profile` → `users-profile`  *(apostrophe stripped, not hyphenated)*
- `One-Click Checkout` → `one-click-checkout`
- `"Saved" Filter Sets` → `saved-filter-sets`
- `Order #1 / Refund Flow` → `order-1-refund-flow`

## Filename slug immutability

Once a feature folder, backlog stub, tech-task file, story, or use case file is created,
its filename slug is **immutable**. If the title later changes (during
refinement, a change spec, or reconcile), update the H1 inside the file
but leave the filename slug as originally derived.

The H1 is the source of truth for display; the filename slug is an opaque
identifier suffix that exists only to make file listings scannable.
Treating slugs as immutable avoids three classes of churn:

- `git mv` for every rename, which fragments file history.
- Broken cross-document links (`feature.md`'s `## Stories` list, change
  folders' delta references) that point at the old slug.
- Stale references in older commits and PRs that no longer resolve.

Worked example: `stories/US-007-saved-filters.md` is renamed in its H1
from "Saved Filters" to "Filter Sets" by a change spec. The file stays
at `US-007-saved-filters.md`; only the H1 inside changes. A new sibling
story added in the same change keeps its freshly-derived slug, e.g.
`US-014-bulk-filter-export.md`.

Exception: if the original slug was *wrong* at creation time (typo,
wrong title chosen, slug rule misapplied), fix it before any other file
references it — but treat that as a bug fix, not a rename.

## ID assignment

All IDs are zero-padded to three digits (`F-001`, `B-014`, `US-007`,
`UC-127`).

| ID kind  | Scope                                                                                 | Next-ID rule                                                                  |
|----------|---------------------------------------------------------------------------------------|-------------------------------------------------------------------------------|
| `F-XXX`  | Features (proposed + implemented + rejected combined in one repo)                      | One above the highest `F-NNN` across `docs/features/proposed/`, `docs/features/implemented/`, and `docs/features/rejected/`. |
| `T-XXX`  | Tech-tasks (proposed + implemented + rejected combined in one repo)                    | One above the highest `T-NNN` across `docs/tech-tasks/proposed/`, `docs/tech-tasks/implemented/`, and `docs/tech-tasks/rejected/`. |
| `B-XXX`  | Backlog stubs (shared across the feature and tech-task backlogs in one repo)           | One above the highest `B-NNN` across **both** `docs/features/backlog/` and `docs/tech-tasks/backlog/`, **including their `promoted/` and `rejected/` subdirs**. Gaps allowed (a number is freed when a stub is promoted or rejected); a promoted or rejected number is never reused. |
| `US-XXX` | User stories, scoped to a single feature folder                                       | One above the highest `US-NNN` in that feature's `stories/` across both `proposed/` and `implemented/` if a staging tree exists, plus any in-flight change folders. |
| `UC-XXX` | Use cases, scoped to a single feature folder                                          | Same as `US-XXX`, but against `use-cases/`. |

Confirm the chosen ID with the user before creating the file. For features
also confirm the slug.

## Date stamps

Where these skills write a date (change folder names, `## Origin` notes),
use today's date in `YYYY-MM-DD` form matching the **local clock** — the
same date `date +%Y-%m-%d` would produce in the shell where the skill is
running. Pinning the timezone avoids midnight-UTC-vs-local discrepancies
that otherwise show up as folder names disagreeing with `git log`.

## Reference formatting in generated documents

To prevent GitLab's JIRA integration from treating spec IDs as issue links, all
generated `feature.md`, `US-XXX-*.md`, and `UC-XXX-*.md` files must follow these
two rules.

### Rule 1 — File-level references: markdown links

In `feature.md`, each bullet in `## Stories` must be a markdown link:

```markdown
- [US-001: Story Title](stories/US-001-story-slug.md)
```

In a story file, each bullet in `## Use cases` must be a markdown link:

```markdown
- [UC-001: Use Case Title](../use-cases/UC-001-use-case-slug.md) — covers `AC-1`, `AC-2`
```

The link path is relative from the containing file's location. The slug in the link
target must match the actual filename (which is immutable per "Filename slug
immutability" above).

### Rule 2 — JIRA-pattern identifiers: backtick escaping

Any identifier matching `[A-Z]+-\d+` (one or more uppercase letters, a hyphen,
one or more digits) must be wrapped in backticks, with **two exceptions** (see
below). This covers all spec IDs (`AC-N`, `BR-N`, `PRE-N`, `POST-N`, `NFR-N`,
`AF-N`, `Q-N`, `STEP-N`, `US-NNN`, `UC-NNN`, `F-NNN`, `B-NNN`) without requiring
an exhaustive enumeration — future ID types are covered automatically.

This rule applies in **both prose and headings**. Examples:

```markdown
**Validates**: `STEP-1`..`STEP-4`, `BR-1`
### `AF-1`: short descriptive name (branches from `STEP-N`)
```

**Exception A — identifiers inside a Rule 1 markdown link are NOT backticked.**
The ID in the link text of a `## Stories` or `## Use cases` bullet (Rule 1)
stays bare, because the surrounding `[...]( ... )` markdown link already stops
GitLab from JIRA-autolinking it, and adding backticks would break the link
format. Write `- [UC-001: Title](../use-cases/UC-001-slug.md)`, never
`` - [`UC-001`: Title](...) ``. (The `— covers \`AC-1\`` trailing annotation is
prose, so those AC IDs *are* backticked, as shown in Rule 1.)

**Exception B — an intentional reference to a real JIRA issue** is left bare so
the JIRA integration links it.

Identifiers without a hyphen (e.g. `S1`, `S2` validation scenario headings) do
not match the pattern and need no escaping.

## `## Jira` is pipeline-managed

`feature.md`, each `stories/US-XXX-*.md`, each tech-task `T-NNN-*.md`, and each
backlog stub `B-NNN-*.md` carry a `## Jira` section. It is **pipeline-managed**,
not author-written - the same model as a linkage-managed section. Use-case files
(`UC-XXX`) have **no** `## Jira` section: a use case is not mapped to a ticket.

The repo that holds the spec owns the section: its **CI pipeline** (a component,
assembly, or release repo) creates the Jira issue and persists the issue link into
`## Jira`, and updates the Jira status as the spec ships, following the **SDD CI
writeback contract** (`references/ci-writeback-contract.md`): the mutating job runs
in the release-tag pipeline and the key lands on `main` via a bot-merged writeback
MR, never a direct push. No manual ticket creation. The skills seed `## Jira` as the managed placeholder (the
`<!-- Maintained by this repo's CI pipeline. Do not edit by hand. -->` comment
from the template) and never author or edit the link; `change-feature` and
`reconcile-feature` never touch it either. The link the pipeline writes is an
intentional real-JIRA reference (Exception B above), so it is left bare / linked,
not backticked.

**Issue-type mapping (the pipeline contract):**

| Spec | Jira issue type | Parent / relation |
| --- | --- | --- |
| `B-NNN` backlog stub (`type: feature`) | Story | becomes the `F-NNN` issue on promotion (same issue carries forward) |
| `B-NNN` backlog stub (`type: tech`) | Task | becomes the `T-NNN` issue on promotion (same issue carries forward) |
| `F-NNN` (feature) | Story | parent of its `US-NNN` issues |
| `US-NNN` (user story) | Story | child of its feature's `F-NNN` issue (the US lives inside that feature's folder, so the parent is unambiguous) |
| `T-NNN` (tech-task) | Task | standalone |
| `UC-NNN` (use case) | none | no ticket (not mapped) |

The parent-child relation between a feature's `F-NNN` issue and its `US-NNN`
issues must be set in Jira by the pipeline.

**Carry the ticket forward on promotion.** A backlog stub is ticketed while it
sits in the backlog (Story for `type: feature`, Task for `type: tech`). When
`refine-feature` / `refine-tech-task` promote the stub, the **same Jira issue is
reused, not re-created** (a `type: feature` stub's Story becomes the feature's
Story; a `type: tech` stub's Task becomes the tech-task's Task, both
type-consistent). The carry happens **CI-side, not skill-side**: the promoted
spec still seeds the **blank managed `## Jira` placeholder** (marker comment, no
link) - the skills never write a Jira key. The CI reconciles the carried key from
the promoted stub at `docs/<tree>/backlog/promoted/B-NNN-*.md` (its
`carried_jira_key()` helper). The only promotion requirement is therefore that the
stub is archived into `backlog/promoted/` with its `## Jira` section **intact** -
that is where the CI reads the carried key.
