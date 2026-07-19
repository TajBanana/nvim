# Writing backlog stubs (shared procedure)

Used by `refine-feature`. The calling skill owns the **Origin text variant**
for its surfacing context; everything else below is identical across callers.

Note: `add-backlog` has its own self-contained sweep and stub-writing procedure
(SKILL.md Steps 2–6) and does not delegate to this shared reference.

Stubs live at `docs/features/backlog/B-XXX-<title-slug>.md` and follow the
template in `backlog-stub.md` (sibling reference in this directory).

## Procedure

For each stub the user agreed to write:

1. **Pick the `B-XXX` ID and slug.** Assign per the rules in
   `conventions.md` (sibling reference). Confirm both with the user
   before writing the file.

1a. **`epic_ref`.** Ask the user: "Does this backlog item belong to a parent epic? If yes, provide the epic ID in `E-XXX` format (e.g. `E-001`). If no parent epic, just press Enter." Validate any supplied value: it must be the letter `E`, a hyphen, and exactly three zero-padded digits (`E-001`…`E-999`). Reject invalid inputs and re-prompt until a valid value or an explicit "no" is confirmed. Record the outcome for Step 2.

2. **Fill the stub losslessly.** Move **all** of the user's input relevant
   to this candidate into the stub — no detail is dropped on the way to the
   backlog. Set the frontmatter `type:` field per the classification; if an
   `epic_ref` was confirmed in Step 1a, also set `epic_ref:` in the frontmatter
   (omit the line when no value was confirmed — the `type:` field is still
   required). If a priority was supplied, set `priority:` to `critical | high | medium | low`;
   omit the line otherwise. Then fill the content sections:
   - `## Description`: a short what/why summary of the candidate.
   - `## Requirement details`: every concrete specific the user gave (file
     formats, field names/types, validation rules, value ranges, units,
     examples, sample payloads). Re-express only transport **form** per
     `spec-writing-principles.md` — keep all substance. Do not condense.
   - `## Design constraints`: any settled HOW decision the user mandated.

   When splitting off from an existing feature, carry the relevant stories /
   use cases' content into these sections rather than summarizing it away. If
   any input is unclear, clarify it with the user and record the clarified
   wording. **Drop nothing** unless the user confirms it is not a requirement
   (hard gate — see `spec-writing-principles.md` "Confirm before dropping").
   `refine-feature` will refine, not recover, on promotion —
   so fidelity must be captured here.

3. **Fill `## Origin`.** Use the variant the calling skill defines (see
   "Origin variants" below). Use the date-stamp rule in `conventions.md`
   for `YYYY-MM-DD`.

4. **Sweep `docs/features/backlog/` for near-duplicates *before* writing.**
   Compare the stub's `## Description` against every existing stub's
   `## Description`. If a candidate overlap is found, surface both
   descriptions side-by-side to the user and ask which of:

   - **Proceed and write the new stub** — the overlap is incidental.
   - **Skip** — the existing stub already covers this candidate; do not
     write a new stub.
   - **Update the existing stub's `## Origin`** — append an additional
     surfacing line (e.g. `Also surfaced during refine-feature on
     YYYY-MM-DD from F-XXX <feature-title>.`) so the existing stub
     records both surfacings.

   Apply the confirmed action before moving to the next stub. Do not
   silently write a duplicate.

5. **Present the (final) stub to the user for review** before writing.
   The user may edit ID, slug, description, or origin text. Apply
   confirmed edits and write the file.

## Origin variants per calling skill

Each calling skill supplies the seed `## Origin` text below. Everything
above stays the same.

| Calling skill                                   | Seed `## Origin` text                                                                                                                                      |
|-------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `refine-feature` (multi-feature free-form input) | `Surfaced during refine-feature on YYYY-MM-DD from input description "<short quote or summary>".`                                                          |
| `refine-feature` (mid-drafting split-off)       | `Split from F-XXX <current-feature-title> during refine-feature on YYYY-MM-DD. <One-sentence reason for the split.>`                                       |
| `refine-feature` (cross-repo dep) | `Dependency of F-XXX <parent-feature-title> in <parent-repo-name>, surfaced during refine-feature on YYYY-MM-DD.` |
| `change-feature` (cross-repo dep) | `Dependency of change <YYYY-MM-DD-change-title> on F-XXX <parent-feature-title> in <parent-repo-name>, surfaced during change-feature on YYYY-MM-DD.` |

## Durability

Stubs are durable. Once written, they live in `docs/features/backlog/`
until one of:

- A future `refine-feature` invocation promotes them with the stub path
  as input. Promotion deletes the stub file (the stub's content is now
  represented by the new `proposed/F-XXX-*/` spec, and the stub's
  `## Origin` is preserved verbatim in the promoted feature's
  `## Origin` under a `Stub origin:` prefix). On promotion, the stub's
  `## Requirement details` feed the use-case `## Data and contracts`
  (Inputs/Outputs) and `## Design constraints` carry into the feature's
  `## Design constraints` — so no captured detail is lost in the move.
- The user deletes them as stale.

## After writing (caller-specific)

- **`refine-feature` only**: after writing the stub, remove the
  split-off content from the current feature spec — including any user
  stories and use cases that move out — and update `feature.md`'s
  `## Stories` index.
- **create/promote path**: nothing more to do; the stub is durable as-is.
