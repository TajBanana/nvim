# Split Detection

Shared across `add-backlog`, `refine-feature`, and `refine-tech-task`. Referenced
from sibling skills (install-together) as
`../refine-feature/references/split-detection.md`.

## H1 — Independent Deliverability (upfront check)

Apply before drafting begins. Ask: **"Would any sub-part deliver value to users or
operators on its own, without the other sub-parts being done?"** This includes
sequential phases where Phase 1 is useful before Phase 2 is built.

If yes for 2 or more sub-parts, flag for splitting.

## H2 — Loose Coupling Between Clusters (mid-draft check)

Apply once stories or tasks are visible. Ask: **"Do the stories or tasks cluster
into groups where items within a group depend on each other, but the groups
themselves are loosely coupled — could be shipped separately or owned by different
teams?"**

If 2 or more such clusters emerge, flag for splitting.

## Outcome Model

When either heuristic fires, name the split candidates explicitly and present
three options:

1. **Split** — proceed with one item now; the calling skill handles the rest per
   the table below.
2. **Proceed as-is** — continue with the full scope; the user can reconsider
   during refinement.
3. **Discuss** — open dialogue if the proposed split does not feel right; revise
   the candidates and loop back to this step.

### Per-skill outcome for "Split"

| Calling skill | What happens to the rest |
|---|---|
| `add-backlog` | Agent creates a task per remaining item and works through them in sequence, each receiving the full Steps 1.5–6 treatment. |
| `refine-feature` | Remaining items become `feature` backlog stubs in `docs/features/backlog/` via `references/writing-backlog-stubs.md`. |
| `refine-tech-task` | Remaining items become `type: tech` backlog stubs in `docs/tech-tasks/backlog/` via `../refine-feature/references/writing-backlog-stubs.md`. |
