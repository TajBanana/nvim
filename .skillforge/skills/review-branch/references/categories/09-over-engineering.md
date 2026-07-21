# 9. Over-engineering

Hunt code that need not exist: reimplemented standard library, dependencies doing what
the platform already does, abstraction ahead of real need, dead flexibility.

This is the one category that **delegates to another skill** rather than defining its own
checks.

## Availability gate

Pick the skill by review mode:

| Review mode | Skill | Scope handed to it |
| --- | --- | --- |
| diff (default) | `ponytail-review` | the branch diff, `base_sha..HEAD` |
| baseline | `ponytail-audit` | the repo tree at HEAD under `<scope>` |

If the mode's skill is **not installed**, record this category as **skipped** — e.g.
`09 over-engineering: SKIPPED — ponytail-review not installed` — and move on. A recorded
skip is a valid disposition (`../reviewer-subagent.md`), so the category-completeness
backstop is satisfied and no re-sweep is triggered. **Do not** substitute your own
over-engineering hunt for the absent skill: the point of this category is the second,
independent opinion, and a self-authored imitation of it is not that.

## Classify by substance, not by tag

Ponytail returns one line per finding, tagged `delete:` / `stdlib:` / `native:` / `yagni:` /
`shrink:`. **The tag is a hint, not the classifier.** Classify every returned finding by its
**substance**, top-down through the closed taxonomy in `../decision-framework.md`, first
match wins — exactly as for a finding from any other category.

The common resolutions:

| ponytail tag | usually lands in |
| --- | --- |
| `delete:` — dead code, unused flexibility | `style-deadcode-magic` |
| `shrink:` — same logic, fewer lines | `style-deadcode-magic` |
| `yagni:` — abstraction with one implementation | `redundant-implementation` (no specific class fits a one-implementation abstraction) |
| `stdlib:` — hand-rolled thing the standard library ships | `redundant-implementation` |
| `native:` — dependency doing what the platform already does | `redundant-implementation` |

A tag **absent from this table needs no special case**: classify it by what the finding says.
`redundant-implementation` is the **catch-all at the bottom**, reached only when nothing else
in the taxonomy fits — a truthful floor, because ponytail's own boundary means everything it
emits is a complexity finding.

Substance-first is also why a change in ponytail's scope needs no edit here: if it ever emits
a performance finding, top-down evaluation matches `performance-hotpath` on the way down and
never reaches the catch-all.

**Carry ponytail's line verbatim** into the finding description, tag included — its value is
in the specifics (`stdlib:` names the replacement function; `native:` names the platform
feature). An unrecognized tag then stays legible to the human at the gate instead of being
normalized away.

## Source

Every finding this category produces carries **`Source: ponytail`**
(`../decision-framework.md`). If it merges with a finding from another category — same
defect-class, same merge-unit scope — the merged entry's Source becomes `both` by the union
rule. That merge is the Normalize pipeline's job; this category mints no merge of its own.

**Exception — the class-probe backstop.** `framework.md`'s per-file class-probe backstop
probes every defect-class, including `redundant-implementation`, on every file — so it can
surface a `redundant-implementation` finding natively, without ponytail. Such a finding
carries **`Source: review-branch`**, not `ponytail`, and is still reported under this
category (which owns the class) regardless of whether this category itself ran or was
skipped.

## Boundary

**Complexity only** — this category inherits ponytail's own scope limit.

- **Correctness, security, and performance stay with categories 01–08.** If ponytail returns
  one of those, classify it by substance (it lands in `correctness-logic`,
  `security-hardening`, `performance-hotpath`, …), never in `redundant-implementation`.
- **Never flag a single smoke test or `assert`-based self-check for deletion.** It is the
  minimum, not bloat. Categories 06 and 07 own test adequacy; contradicting them here is a
  defect in this category, not a finding.
- **A deliberate, documented simplification is not a finding.** Code marked with a stated
  ceiling and upgrade path is a recorded decision, not accidental complexity.

## The net-lines note

Ponytail closes with `net: -<N> lines possible`, or `Lean already. Ship.` when there is
nothing to cut. Carry it into the **gate report** as the one-line note described in
`../decision-framework.md` — marked a **pre-merge, pre-gate estimate**. It goes no further:
the durable review report (`../report.md`) does not carry it.

Record findings per `../decision-framework.md`.
