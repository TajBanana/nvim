# Requirements interview

Drives the questions that turn a feature idea into a spec precise enough that
**regenerating code from the same spec yields the same behavior**, and complete
enough to **derive automated end-to-end tests** from the spec alone.

The interview's job is to hunt down every source of behavioral divergence — not
just the interface contract. Its areas route into the existing template sections;
only one template field is new (the enriched `## Data and contracts → Inputs`).

## How to run it — interleaved, never upfront

Do **not** dump these questions on the user at once. Weave them into the
`refine-feature` drafting loop: draft one increment, present it, ask that
increment's questions, refine, confirm — then the next increment. Stay
transport-agnostic (no HTTP verbs, paths, queue names); harness detail is
resolved later at `implement-feature` time.

## Stage A — feature level (once, at description time)

Just enough to frame the stories — keep it light:

- Who are the actors (users, operators, external systems)?
- What are the feature's inputs and outputs at a glance?
- Any feature-wide non-functional requirements or design constraints
  (throughput target, data-residency, platform)?

## Stage B — per story (repeat, one story at a time)

1. Present the drafted story (`As a … I want … so that …`).
2. Ask:
   - What does the stakeholder observe to agree this story is delivered?
     (→ `## Acceptance Criteria`)
   - Which actor is this for, and where are the edges of this story's scope?
3. Refine and confirm the story, then descend into its use cases (Stage C).

## Stage C — per use case (repeat, one use case at a time)

Present the drafted use case (summary, trigger, main flow), then work the areas
below. Each states what to ask, why it matters, and where the answer lands.

### C1 — Interface contract (what goes in and out)

- **Inputs** → `## Data and contracts → Inputs` (fill the template's five
  per-input sub-labels): **Schema** (fields, types, required/optional with
  defaults, format, precision, units, validation rules, value ranges); **Source**
  (which actor or system produces it); **Volume** (max/peak rate, per-item and
  batch size, frequency, growth); **Ordering & identity** (ordering guarantees,
  uniqueness, idempotency / dedup key); **Malformed input** (how an invalid or
  out-of-range value is handled). *Why:* without volumetrics, load-shaped tests
  and stubs are guesses.
- **Outputs & observables** → `## Data and contracts → Outputs`, `## Postconditions`.
  Schema, format (precision, number/date format, locale), recipient, **result
  ordering / sort**, pagination. *Why:* unspecified sort order is a classic
  regeneration divergence.
- **External contracts** → `## External contracts`. Every external system,
  direction, data exchanged, and what must be stubbed for tests.

### C2 — Behavioral logic (what the system decides / computes)

The largest reproducibility lever.

- **Business rules** → `## Business rules`. Formulas, thresholds,
  rounding/precision/units, precedence, tie-breaking.
- **Decision / branching** → `## Alternate flows`. Every condition that changes
  the outcome, and the exact result of each branch.
- **State & lifecycle** → `## Business rules` / flows. Valid states, allowed
  transitions, terminal states.
- **Defaults & optionality**. The default value *and* the behavior when each
  optional input or config is absent. *Why:* unspecified defaults diverge silently.

### C3 — Failure & edge semantics

- **Error identity** → `## Alternate flows`, failure `## Postconditions`. Exact
  code/message/copy, side-effects on failure, validation precedence (first-fail
  vs report-all), retry/idempotency, partial-failure handling.
- **Boundary behavior** → boundary validation scenarios. Exact behavior at
  empty/zero/min/max/overflow (reject vs clamp vs truncate).
- **Authorization** → permission validation scenarios. Who may trigger; exact
  denial behavior.

### C4 — Timing & concurrency

- **Time & date**. Timezone, clock source, cutoffs, expiry, scheduling.
- **Ordering & concurrency**. Processing order, dedup, race resolution,
  idempotency keys.

### C5 — Non-functional requirements → `## Non-functional requirements`

Each NFR measurable, with a threshold, at least one validating scenario, and a
production metric. Add an NFR-validating scenario (the `S6` pattern in
`use-case.md`) that tests the mechanism, not just the outcome.

### C6 — Test-derivation wrap → `## Validation scenarios`, `## Preconditions` / `## Postconditions`

- Scenario coverage: happy path, alternates, boundaries (empty/zero/max),
  error/invalid, state/permission — each with concrete values and a `Validates:`
  trace to a step, business rule, alternate flow, or NFR.
- Preconditions (test setup) and postconditions (assertions), split success-only
  vs always-true.

## Determinism checklist — before confirming a use case

A use case is under-specified for reproducibility if any of these is unanswered:
defaults for every optional input; rounding/precision/units on every computed
value; sort/order of every multi-item output; exact error identity on every
failure path; timezone/clock for every time-dependent rule. Surface the gap and
resolve it before moving on.
