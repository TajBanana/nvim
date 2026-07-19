# 7. Test verification

Run the test suites to verify no regressions, and investigate and fix any
failures **even if not directly related** to the branch's changes.

The concrete commands (unit only, or unit + end-to-end) are in the detected stack
file. Record unresolved failures as findings per `../decision-framework.md`.

## Gate protocol (deterministic)

Run each gate (this category and category 08) **once**; capture its raw command
output into a fixed **evidence block** that the report's gate section is filled from
as a template, not free prose. Report each gate with a fixed status: `PASS`, `FAIL`,
`NOT RUN — <reason>`, or `FLAKY`.

- **Unavailable gate** (e.g. no registry access for Sonar, no e2e script in
  `package.json`): record `NOT RUN — <reason>`. **Never omit the gate**, and **never**
  turn its unavailability into a finding.
- **E2E always-run invariant.** The e2e gate is **always attempted** — never skipped as a
  discretionary or performance choice ("off fast path", "to save time", "skipped for speed"
  are **never** valid reasons). If the suite needs a live backend that is unavailable,
  **use the repo's documented offline/mock mode** (e.g. `CI=1` with mocked endpoints) if one
  exists before declaring it unrunnable. `NOT RUN — <reason>` is valid for e2e **only** when
  there is no e2e script, or a live backend is required **and** no mock/CI mode exists — the
  reason must name the blocker. Once it runs, the flaky-suite rule below applies.
- **Flaky suite → exactly one finding.** A suite that fails **non-deterministically**
  (E2E timing/async/network flakiness, or a test annotated flaky) yields **at most
  one** gate-derived finding — `"suite <X> is flaky"` — that **enumerates whichever
  tests failed this run**, at a **fixed severity of Medium** — flakiness is a real
  test-quality weakness but names no concrete product trigger-plus-failure, so it is
  Medium by the criticality rubric's default (`../decision-framework.md`). **Never one
  finding per failing test**, and **do not re-run to confirm**. A **deterministic**
  failure (a genuine, repeatable break) is a normal finding tagged per
  `../decision-framework.md`.
