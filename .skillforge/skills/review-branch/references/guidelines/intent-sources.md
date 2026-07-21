# Determining intent

When a review judgment turns on the code's **intent** — e.g. deciding whether a surprising
behavior is a deliberate design choice or a defect — determine intent the same way everywhere,
from the best available source.

## Source hierarchy (highest authority first)

1. **An explicit driving spec.** In a **diff/branch review**, the branch's own design/spec:
   a superpowers spec (`docs/superpowers/specs/<date>-*-design.md`) or the feature / tech-task
   spec it implements (`docs/features/{proposed,implemented}/F-XXX-*/`,
   `docs/tech-tasks/{proposed,implemented}/T-XXX-*/`). This states what the change is meant to do.
2. **User-facing documentation.** README, user guides, API docs, ADRs — what the software
   promises its users and callers.
3. **Code-internal signals** (the fallback when 1–2 are absent). Naming, type/signature, the
   surrounding contract, tests as executable intent, and symmetry with sibling code (how
   comparable cases are handled nearby).

Consult the highest available source; drop to the next only when it is absent or silent on
the point.

## By review mode

- A **diff / branch review** usually *has* a driving spec (source 1), so intent is often
  **stated** — an effect that **contradicts** it is a self-evident divergence.
- A **baseline / whole-codebase review** usually has **no** single driving spec: rely on
  feature specs where they exist, otherwise on code-internal signals (source 3). Intent is
  weaker here — an ambiguous divergence stays a "confirm intent" question, not a confident call.

Absence of a *stated* intent is never a reason to drop a finding — infer intent from the next
source down and rate by the confidence you actually have (per the evidence tiers in
`../decision-framework.md`).
