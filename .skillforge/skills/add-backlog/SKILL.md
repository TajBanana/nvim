---
name: add-backlog
type: skill
tags: [documentation, backlog]
description: Use when the user wants to log a feature idea or requirement to the backlog without starting a full spec — takes a free-form description, sweeps for duplicates, and confirms before writing a new `B-XXX` stub or updating an existing one.
argument-hint: "[free-form feature description]"
version: 1.4.1
compatibility: [copilot, claude]
---

## Overview

Captures a feature idea or tech task from a free-form description, classifies
it, and writes a backlog stub at `docs/features/backlog/B-XXX-<slug>.md` (for
features) or `docs/tech-tasks/backlog/B-XXX-<slug>.md` (for tech tasks).
Before writing, it sweeps for near-duplicate stubs and lets the user choose
how to handle any overlap.

Part of the feature-spec lifecycle: see
`../refine-feature/references/lifecycle.md` for the full workflow map.

## When to use

- The user has a feature idea they want to log for later without starting a
  full spec now.
- The user wants to quickly capture a requirement with enough fidelity that
  a future `refine-feature` invocation can promote it without losing detail.

When NOT to use (redirect instead):

| Situation | Redirect |
| --------- | -------- |
| Description is detailed enough to start a spec now | `refine-feature` (accepts free-form descriptions directly) |
| An existing backlog stub needs to be promoted into a full spec | `refine-feature` with the stub path as `$ARGUMENT` |
| A shipped feature needs a change | `change-feature` |

## Procedure

### Step 1 — Resolve the description

If `$ARGUMENT` is provided, use it as the feature description. If omitted,
ask the user to describe the feature.

### Step 1.2 — Split check

Apply the H1 heuristic from `../refine-feature/references/split-detection.md`.
If the description contains sub-parts that each deliver value independently,
surface the split candidates and follow the outcome model in
`../refine-feature/references/split-detection.md`.

On **Split**: create a task for each backlog item. Ask the user which item to
start with. Work through the items in sequence — each receives the full
Steps 1.5–6 treatment before moving to the next.

On **Proceed as-is** or **Discuss**: follow the outcome model and continue with
the original description into Step 1.5.

### Step 1.5 — Classify

Apply `../refine-feature/references/classification.md` (auto-classify, then
confirm). The result (`feature` or `tech`) determines the `type:` frontmatter
and the target backlog directory: `feature` → `docs/features/backlog/`;
`tech` → `docs/tech-tasks/backlog/`. For mixed input, follow the
mixed-input handling in `classification.md`.

Note: a new tool or capability intended for developers to use (CLI command,
test runner, debugging tool, developer portal, SDK) classifies as `feature`,
not `tech` — the developer is the user of that tool. See `classification.md`
for the developer-as-tool-user vs developer-as-code-reader distinction.

### Step 2 — Existing-match sweep

Read every `B-XXX-*.md` stub in the backlog directory matching the classified
type (`feature` → `docs/features/backlog/`; `tech` →
`docs/tech-tasks/backlog/`), excluding that directory's `promoted/` and
`rejected/` subdirs from the overlap comparison, and classify each against the
incoming description using your own semantic reasoning:

| Classification | Meaning |
| -------------- | ------- |
| **No relation** | Unrelated — skip silently |
| **Overlap** | Same intent and scope — existing stub likely already covers the requirement |
| **Close match** | Related intent but distinct scope or angle — existing stub worth enriching |
| **Contradiction** | Descriptions point in opposite directions or imply conflicting design decisions |

Also check the proposed and implemented directories for the classified type.
For a `feature` stub, check `docs/features/proposed/` and
`docs/features/implemented/`: a match in `proposed/` → ask whether to redirect
to `refine-feature`; a match in `implemented/` → ask whether to redirect to
`change-feature`. For a `tech` stub, check `docs/tech-tasks/proposed/` and
`docs/tech-tasks/implemented/`: a match in `proposed/` → ask whether to
redirect to `refine-tech-task`; a match in `implemented/` → ask whether to
redirect to `implement-feature`. Apply any redirect before continuing.

Complete the full backlog sweep before surfacing anything. Then present
non-trivial matches sequentially: contradictions first (highest severity),
then close matches, then overlaps.

**Per-match interaction — Overlap:**

1. Show both descriptions side-by-side.
2. Present options: **Add new anyway / Skip / Update existing Origin / Discuss**
3. If **Update existing Origin**: append the following line to the existing
   stub's `## Origin`:
   `Also captured via add-backlog on YYYY-MM-DD from user description "<short quote>".`
4. If **Discuss**: open dialogue — the user can question the classification or
   provide context; revise your assessment if warranted, then loop back to step 2.
5. Apply the confirmed action before moving to the next match.

**Per-match interaction — Close match:**

1. Show both descriptions with label "Close match" and a one-sentence
   explanation of the relationship.
2. Draft a proposed edit to the existing stub — e.g., an amendment to
   `## Description`, a new bullet in `## Requirement details`, or a scoping note.
3. Present options: **Confirm / Adjust / Reject / Discuss**
4. If **Discuss**: open dialogue; revise the draft if warranted, then loop back
   to step 3.
5. If **Reject**: present fallback options: **Add new anyway / Skip**
6. Apply the confirmed action before moving to the next match.

**Per-match interaction — Contradiction:**

1. Show both descriptions with label "Contradiction" and a one-sentence
   explanation of the conflict.
2. Draft a proposed resolution edit to the existing stub — e.g., a scoping
   clause in `## Description` or a new entry in `## Design constraints`.
3. Present options: **Confirm / Adjust / Reject / Discuss**
4. If **Discuss**: open dialogue; revise the draft or re-classify the
   relationship if warranted, then loop back to step 3.
5. If **Reject**: present fallback options: **Add new anyway / Skip**
6. Apply the confirmed action before moving to the next match.

**Coverage assessment (after all matches):**

Once all non-trivial matches have been processed, assess whether the original
incoming requirement is now covered — either because an existing stub already
captured it, or because edits applied during the sweep absorbed it.

- **Covered**: inform the user which stub(s) now cover the requirement and
  exit without writing a new stub.
- **Not covered**: summarise what changed during the sweep and propose writing
  a new stub. Continue to Step 3 only if the user confirms.

### Step 3 — Candidate title

Propose a short noun-phrase title in **Descriptor + Core Function** shape
(e.g. "Saved Filter Sets", "Bulk Order Cancellation"), ≤5 words. Confirm with
the user; apply any edits.

### Step 4 — ID and slug

Determine the next `B-XXX` per
`../refine-feature/references/conventions.md` — one above the highest `B-NNN`
across **both** `docs/features/backlog/` and `docs/tech-tasks/backlog/`,
including their `promoted/` and `rejected/` subdirs for number continuity.
Derive the slug from the confirmed title using the same conventions file's
slug rules. Confirm both with the user before proceeding.

### Step 4a — Epic reference

Ask the user: "Does this backlog item belong to a parent epic? If yes, provide
the epic ID in `E-XXX` format (e.g. `E-001`). If no parent epic, just press
Enter." Validate any supplied value: it must be the letter `E`, a hyphen, and
exactly three zero-padded digits (`E-001`…`E-999`). Reject invalid inputs and
re-prompt until a valid value or an explicit "no" is confirmed. Record the
outcome for Step 5.

### Step 5 — Draft the stub

Fill the stub using the template in
`../refine-feature/references/backlog-stub.md`. Set the `type:` frontmatter
field to the value determined in Step 1.5 (`feature` or `tech`). If an
`epic_ref` was confirmed in Step 4a, also set `epic_ref:` in the frontmatter;
omit the line when no value was confirmed (the `type:` field is still
required). If a priority was supplied (e.g. by a caller routing a finding to
backlog), set `priority:` in the frontmatter to `critical | high | medium | low`; omit the
line when none was supplied (the `type:` field is still required). Write the
file to the directory matching the classification:
`feature` → `docs/features/backlog/`; `tech` → `docs/tech-tasks/backlog/`.

- **`## Description`**: a concise what/why summary derived from the input.
- **`## Requirement details`**: every concrete specific in the input (field
  names, formats, validation rules, value ranges, units, examples, sample
  payloads). Do not condense or drop substance. Omit the section only if the
  input contains no concrete specifics.
- **`## Design constraints`**: any settled HOW decision the user mandated
  (protocol, platform, sync/async). Omit if none.
- **`## Origin`**:
  `Captured directly to backlog on YYYY-MM-DD from user description "<short quote or summary>".`

Use the date-stamp rule in `../refine-feature/references/conventions.md` for
`YYYY-MM-DD`.

### Step 6 — Review and write

Present the complete draft to the user before writing. Apply any requested
edits. Write the file only after the user confirms.
