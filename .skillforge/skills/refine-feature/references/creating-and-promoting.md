# Creating and promoting a feature spec

The create / promote front-end of `refine-feature`. Run this when the input
is a free-form description (no matching feature) or a backlog stub path
(`docs/features/backlog/B-XXX-*.md`). On completion, hand the seeded title,
ID/slug, folder, and seed `## Origin` back to the main skill's bootstrap step.

This file resolves from `refine-feature/SKILL.md` as
`references/creating-and-promoting.md`, and from sibling skills (install-together)
as `../refine-feature/references/creating-and-promoting.md`.

## Input disambiguation

If `$ARGUMENT` is a path that exists under `docs/features/backlog/` and matches
`B-XXX-*.md`, treat it as **backlog promotion**; otherwise treat it as a
**free-form description**. The two paths differ only in how the seed description
and candidate title are obtained, and whether a stub is archived at the end.

## Context-phase repo hydration

While exploring project context — checking `docs/features/proposed/`,
`docs/features/implemented/`, `docs/features/backlog/`, and reading any
existing stubs or specs — acquire a per-feature checkout of a downstream repo
on demand by running `skillforge-repos acquire-feature-repo <F-XXX-slug> <repo>`
(via the Bash tool). See the `repo-resolution` rule. Do
not acquire repos up front — resolve a repo only when you actively need it.

## Existing-match check

Before drafting anything, check `docs/features/proposed/`,
`docs/features/implemented/`, **and `docs/features/backlog/`** (excluding
`docs/features/backlog/promoted/`) for a feature or candidate matching the
input. If a likely match is found, surface it:

- Match in `implemented/` → ask whether they meant to change it; redirect to
  `change-feature`.
- Match in `proposed/` → ask whether they meant to keep refining that existing
  spec; continue there rather than creating a new folder.
- Match in `backlog/` (not `backlog/promoted/`) and the user is **not** already
  promoting that stub → ask whether they meant to promote it; if yes, restart
  with the stub path as `$ARGUMENT`.

Only proceed if no match exists or the user confirms this is genuinely new.

## Backlog dedupe on promotion

When this is a promotion (`$ARGUMENT` is a stub path), after the existing-match
check, sweep `docs/features/backlog/` for other stubs whose `## Description`
overlaps the one being promoted. For each, show both descriptions and ask:

- **Fold into this promotion** — append the matched stub's `## Description`
  (or salient parts) into the seed description, then delete the matched stub.
- **Leave alone** — not a duplicate; keep both.
- **Delete as stale** — no longer relevant; delete without folding.

Apply confirmed actions before title derivation. This is the only grooming this
front-end performs — whole-backlog curation is out of scope.

## Title derivation

- **Free-form description.** Derive one or more candidate titles, each a clear
  noun phrase using Descriptor + Core Function. Name the feature, not the task —
  e.g. "Track Streaming", not "Track Streaming Implementation"; drop task words
  like "implementation", "support", "build" (see the title rule in
  `references/feature.md`). Present candidates to the user.
- **Backlog stub.** Read the H1 title as the initial candidate; present it and
  offer to refine. If it names a task rather than the feature, refine it.

In both cases the user picks **exactly one** title — one run produces one spec.

## Multi-feature split

After title derivation, apply the H1 heuristic from
`references/split-detection.md`. If the input contains sub-parts that each
deliver value independently, surface the split candidates and follow the outcome
model in `references/split-detection.md`.

On **Split**: keep one candidate as the active feature (defined now). Write the
rest as `feature` backlog stubs in `docs/features/backlog/` via
`references/writing-backlog-stubs.md` (Origin variant:
`Surfaced during refine-feature on YYYY-MM-DD from input description "<short quote or summary>".`).
Distribute each candidate's specifics to the stub it belongs to — never leave a
user-provided detail behind. Do not define multiple features in one run.

On **Proceed as-is** or **Discuss**: follow the outcome model in
`references/split-detection.md` and continue accordingly.

## ID, slug, and folder

New specs are created under `docs/features/proposed/F-XXX-<title-slug>/`.
Assign the `F-XXX` ID and derive `<title-slug>` per `references/conventions.md`.
Confirm the chosen ID and slug with the user before creating the folder.

## Seed `## Origin`

Construct the seed Origin string the bootstrap will write into `feature.md`:

- **Free-form description.** `Defined on YYYY-MM-DD from user input "<short quote or summary>".` Use the date-stamp rule in `references/conventions.md`.
- **Backlog stub (promotion).**

  ```
  Promoted from [backlog stub B-XXX](../../backlog/promoted/B-XXX-<slug>.md) on YYYY-MM-DD.

  Stub origin: <verbatim content of the stub's ## Origin section>
  ```

  Use the stub's actual filename slug for `<slug>` (it does not change on the
  move). Preserving the stub's `## Origin` verbatim carries any cross-repo dep
  link or earlier surfacing context into the promoted feature.

Surface the seed Origin to the user for confirmation along with the ID and slug
before handing back to the bootstrap step.

## Promotion and `## Jira`

`## Jira` is **pipeline-managed** - the skill never writes a Jira key, on a
promotion or otherwise. The promoted `feature.md` seeds the **blank managed
`## Jira` placeholder** from the template (the marker comment, no link), exactly
like a free-form create. Do **not** copy a key out of the stub.

The backlog's Jira issue is still reused (not re-created): the CI reconciles the
carried key from the **promoted stub** at
`docs/features/backlog/promoted/B-XXX-<slug>.md` (its `carried_jira_key()`
helper). So the only promotion requirement is that the stub is archived into
`backlog/promoted/` with its `## Jira` section **intact** - the archive step below
already does a `git mv` (which preserves it) and only appends `## Promoted`, so do
not strip or rewrite the stub's `## Jira`.

## Spec-writing principles

When seeding, follow `references/spec-writing-principles.md`. Strip transport
*form* (HTTP methods, URL paths, SQL, queue topics) and re-express as intent and
data exchange — but **strip form, keep substance**: file formats, field schemas,
validation rules, value ranges, units, and examples are requirements, preserve
them. **Never drop a user-provided detail without confirmation.** Pass the
**full** user input into bootstrap, not a summary — the seed Origin quote is
provenance only, not the channel for requirement detail.

## Dep-originated stub promotion

If the stub's `## Origin` starts with `Dependency of F-XXX`, the parent spec is
available in `references/repos/<parent-repo>/` as reference context. Draft in
the downstream component's own terms — do not carry over upstream actor names,
system names, or scenarios.

## Promotion cleanup (after acceptance)

Run only after the spec is fully drafted and the user has accepted it. Do not
touch the stub earlier.

1. **Move** `docs/features/backlog/B-XXX-<slug>.md` →
   `docs/features/backlog/promoted/B-XXX-<slug>.md` (filename unchanged). First
   `mkdir -p docs/features/backlog/promoted/`. Use `git mv` if the stub is
   committed; otherwise `mv` then `git add` the new path. Check tracking with
   `git ls-files --error-unmatch docs/features/backlog/B-XXX-<slug>.md 2>/dev/null`.
2. **Append a `## Promoted` section** to the moved stub:

   ```markdown
   ## Promoted

   Promoted to [F-XXX <feature-title>](../../proposed/F-XXX-<title-slug>/feature.md) on YYYY-MM-DD.
   ```

   The relative path resolves from `docs/features/backlog/promoted/`.
3. **Announce:** "Archived backlog stub B-XXX to `docs/features/backlog/promoted/`."
4. **Stage and commit** the move and the `## Promoted` write together
   (`git add docs/features/backlog/promoted/B-XXX-<slug>.md`), via `git-commit`.
