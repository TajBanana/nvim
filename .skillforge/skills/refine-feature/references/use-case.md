# `UC-XXX`: Use case title

## Summary

One or two sentences describing what this use case accomplishes and the
behavior it specifies. Avoid implementation language. A reader should
understand what the system does without knowing how it is built.

## Actors

- **Primary**: the actor who initiates this use case
- **Secondary**: other actors, services, or systems involved
- **Trigger**: what causes this use case to begin — user action, scheduled
  event, system event, external signal

The trigger is often missed and is the most common source of ambiguity
for the agent. "User opens checkout" and "system detects abandoned cart
after 30 minutes" are very different triggers with very different
implications for testing.

## Preconditions

Conditions that must be true before this use case can run. The agent
uses these as test setup; engineering uses them to reject invalid
states early.

- `PRE-1`: `condition that must hold`
- `PRE-2`: `another condition`
- `PRE-3`: `another condition`

Each precondition should be independently verifiable. "User is logged
in" is verifiable; "user is ready" is not.

## Postconditions

What is true after the use case completes. Postconditions are
invariants the agent uses for property-based tests and assertions that
run across many scenarios.

- `POST-1` (on success): `what is true after a successful run`
- `POST-2` (on success or failure): `what is true after any run`
- `POST-3` (on failure): `what is true only after a failed run`

Distinguish success-only from always-true postconditions. "Audit event
written" is usually always-true; "balance decremented" is success-only.

## Main flow

The expected path through the use case. Number each step. Steps are
written in third person, present tense, with no implementation detail.

1. `actor or system action`
2. `next action`
3. `next action`
4. `terminal step`

Aim for 4–8 steps. Fewer than 3 suggests the use case is trivial and
might fold into another. More than 10 suggests it should be split.

## Alternate flows

Named branches off the main flow. Each gets its own ID so scenarios
can cite it.

### `AF-1`: short descriptive name (branches from `STEP-N`)

1. `action that differs from main flow`
2. `next action`
3. Resumes main flow at `STEP-M` (or terminates with specific outcome)

### `AF-2`: another alternate flow (branches from `STEP-N`)

1. `action`
2. Terminates with `specific outcome`

Every error path, fallback, and "what if the user does X instead"
belongs here. Burying error paths in prose is the single largest source
of spec drift later.

## Business rules

Constraints the use case must honor regardless of which flow runs. Each
rule is a single assertion the agent can test in isolation.

- `BR-1`: `single, unambiguous rule`
- `BR-2`: `another rule`
- `BR-3`: `another rule`

Rules of thumb:

- One assertion per rule. "Min 100 points and max 50% of cart" is two
  rules (`BR-1` minimum, `BR-2` maximum).
- Rules should be falsifiable. "System should be fast" is not a rule;
  "p95 latency under 300ms" is an NFR (see below).
- Rules apply across all flows. If a constraint only applies in one
  flow, it belongs in that flow's steps.

## Non-functional requirements

- `NFR-1`: `specification`
- `NFR-2`: `specification`

Every NFR must be measurable, have at least one validating scenario,
and have a corresponding production metric. NFRs without all three
fields are aspirations, not requirements.

## Data and contracts

Inputs and outputs of the use case. Reference shared schemas rather
than redefining them.

### Inputs

Enumerate every input this use case accepts. For each input, capture both its
**schema** and its **volumetrics** — the agent needs both to derive tests and to
stub or load-shape dependencies. Reference shared schemas rather than redefining
them.

- **`<input name>`**
  - Schema: fields and types; required vs optional (with defaults); format
    (encoding, precision, units); validation rules and value ranges.
  - Source: which actor or system produces it.
  - Volume: max / peak arrival rate; per-item and batch size; frequency or
    cadence; expected growth over time.
  - Ordering & identity: ordering guarantees, uniqueness, idempotency / dedup key.
  - Malformed input: how an invalid or out-of-range value is handled.

Omit a sub-bullet only when it genuinely does not apply (e.g. a single on-demand
input has no meaningful rate) — never drop it silently.

### Outputs

- output field: type, format, recipient
- output field: type, format, recipient

### External contracts

- `<System A>` → `<System B>`: `<what data is exchanged (fields, constraints)>`
- `<System A>` notifies / `<System B>` receives: `<what event or message — not the topic name>`

Name communicating parties and direction. Append `[sync]` or `[async]` only when the timing
model has business significance — see `spec-writing-principles.md` for the timing-model test.
Avoid HTTP methods, endpoint paths, queue names, SQL operations, or any other transport
specifics unless the interface is already implemented or established as a design constraint.

The carve-out restricts only transport **form**. Data/format **substance** — file formats,
field names and types, validation rules, value ranges, units, examples — is requirement
substance and is always preserved here in full; never strip it as "implementation detail."

This section is what lets the agent stub external dependencies during test generation. Without
it, tests either over-mock (hiding integration bugs) or under-mock (slow and flaky).

## Validation scenarios

The agent's primary input. Each scenario is a single Given/When/Then
block with concrete values, and a `Validates:` line listing which
steps, business rules, or NFRs it covers.

### S1: short descriptive name — usually the happy path

**Validates**: `STEP-1`..`STEP-4`, `BR-1`

```gherkin
Given <concrete precondition with values>
And <another precondition>
When <single action with concrete inputs>
Then <observable outcome with concrete expected values>
And <secondary outcome>
```

### S2: name of an alternate or rule-specific scenario

**Validates**: `BR-2`, `AF-1`

```gherkin
Given <concrete precondition>
When <action>
Then <expected outcome with specific error code or state>
```

### S3: another scenario

**Validates**: `BR-3`

```gherkin
Given ...
When ...
Then ...
```

### S4: empty / zero / boundary scenario

**Validates**: `STEP-2`, `BR-1`

```gherkin
Given <empty or boundary state>
When <action>
Then <specified behavior, including UI copy if applicable>
```

### S5: state-machine or permission scenario

**Validates**: `BR-N`, `AF-N`

```gherkin
Given <account or system in a specific state>
When <action attempted>
Then <expected denial or fallback>
```

### S6: NFR-validating scenario, if applicable

**Validates**: `NFR-1`, `BR-N`

```gherkin
Given <load or concurrency setup>
When <action under those conditions>
Then <functional outcome>
And <performance assertion with concrete threshold>
And <mechanism assertion, e.g. "upstream service is not called">
```

Scenario writing rules:

- Use concrete values ("500 points", "$80 cart", "200ms"). Never
  placeholders like "some points" or "appropriate value".
- Every scenario cites a step, business rule, alternate flow, or NFR
  via `Validates:`. Untraced scenarios are deleted.
- For UI use cases, pin user-visible strings exactly (punctuation,
  units, copy keys) — the displayed text is part of the contract.
- NFR scenarios should test the mechanism, not just the outcome
  (e.g. "cached value returned AND upstream service is not called").

## Open questions

- `Q-1`: ambiguity blocking approval, with target resolution date
- `Q-2`: another open item

Questions blocking implementation should fail approval. Questions about
future enhancements can stay open and roll forward into the next
version.
