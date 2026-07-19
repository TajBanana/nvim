# 5. Documentation

Reconcile the repository's documentation with the branch's changes. Two
independently-triggered checks — run both on every review:

**Technical docs pre-check (via `update-tech-docs`) — not diff-triggered.** Run
this regardless of what the diff touches; nothing in the diff will prompt it, so
check it proactively on every review:

- **Confirm installation first** — actively check whether the `update-tech-docs`
  skill is installed among your available skills. **Do not assume it is absent**
  and skip to the fallback; confirm one way or the other.
- **If installed, it owns the technical docs** — it defines the expected Markdown
  docs: `architecture.md`, and for multi-module roots, `developer.md` and
  `troubleshooting.md`.
- **Apply its structural criteria to the repo's actual docs** — its "Review
  Existing Documents" criteria: repository-type structure, required sections,
  Mermaid-diagram descriptions, and DDR cross-referencing.
- **Scope is the whole repo, not the diff** — evaluate the current technical docs
  against `update-tech-docs`'s expected structure independent of what this branch
  changed; a review is the point to catch doc drift.
- **Raise a finding** for any doc that is missing, does not match the expected
  structure, or is stale, per `../decision-framework.md`.
- **On "Fix now", invoke `update-tech-docs`** to create or update the affected
  docs — do not hand-edit them ahead of the user's decision.
- **Fallback** — only if `update-tech-docs` is genuinely not installed, reconcile
  those docs by hand instead.

**Everything else — diff-anchored.** Staleness-check the docs `update-tech-docs`
does not own, against the branch's changes:

- README and getting-started docs.
- API / endpoint docs.
- Design/decision records not already covered by the technical docs.
- Doc-comments that describe changed behaviour.

Flag stale docs as findings per `../decision-framework.md`, and update existing
ones in place when actioned.
