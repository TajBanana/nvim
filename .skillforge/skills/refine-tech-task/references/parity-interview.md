# Parity & blast-radius interview

A tech-task changes mechanism without changing externally-observable behavior.
This interview pins the observable baseline precisely enough that "unchanged
behavior" is **verifiable**, and maps the blast radius so the parity check covers
everything the change can touch. It is the reproducibility lens inverted: instead
of specifying new behavior, it specifies exactly which behavior must stay identical.

Run it section by section as `refine-tech-task` drives the spec, presenting each
section for confirmation. Keep `## Intended Approach` and `## Design constraints`
free to describe HOW (the inversion); everything else stays outcome-focused.

## 1. Behavioral baseline / parity surface → feeds the `## Acceptance criteria` parity assertion

Which externally-observable inputs, outputs, and contracts of the affected
features must remain identical? Pin the observable "before" that must equal the
"after":

- Same outputs for the same inputs (values, schema, format, precision).
- Same **ordering / sort** of any multi-item output.
- Same **error identity** (codes, messages, copy) on the same failure paths.
- Same side-effects and persisted state.

## 2. Blast radius → `## Affected features`

Which features' *implementation* does the change touch? Each becomes an `F-XXX`
markdown link with a note on what part is affected. If nothing is affected, say
so explicitly and confirm.

## 3. Load / performance characteristics → `## Design constraints` / parity criteria

Capture the current load profile that must be preserved or improved, using the
volumetrics vocabulary from
`../refine-feature/references/requirements-interview.md` (area C1): throughput,
latency budget, resource ceilings, data volume. Note any budget the change must
stay within.

## 4. Parity verification method → `## Acceptance criteria`

How is parity proven? Make it concrete and runnable:

- Existing tests for affected features remain green.
- Output diffing / golden files for representative inputs.
- Benchmark within the stated budget.

Every `## Acceptance criteria` set must include a behavior-parity assertion and
how it is checked.

## 5. Risks & rollback → `## Risks and mitigations`

For each material risk: its impact, and the mitigation / rollback path.
