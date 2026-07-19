# Stack: Frontend (Node / TypeScript)

Concrete steps per category for a `package.json`-based frontend repository.

## 1. Metrics

**Skip** — not a backend service.

## 2. Logging & error handling

Apply the neutral `../guidelines/error-handling.md` and `../guidelines/logging.md`, using any
frontend review skills installed in the repo.

## 3. Code review & refactor

Follow the generic checks in `../categories/03-code-review.md`, using any
frontend review skills installed in the repo.

## 4. Architecture

No stack-specific override; follow `../categories/04-architecture.md`.

## 5. Documentation

Reconcile existing docs (README, component/module docs, diagrams) per
`../categories/05-documentation.md`.

## 6. Test review

Review unit **and** end-to-end (e2e) tests against the changes for coverage and
quality. Identify critical cross-unit functionality that should be added to the
E2E suite, per `../categories/06-test-review.md`.

## 7. Test verification

Run all unit tests and any available end-to-end tests (detect the scripts from
`package.json`, e.g. `npm test`, `npm run test:e2e`). Investigate and fix
failures even if unrelated to the change.

**Always attempt the e2e gate** (`npm run test:e2e`) — never skip it for speed. If it
requires a live backend that is not reachable, run the repo's offline/mock configuration if
present (e.g. `CI=1 npm run test:e2e`) rather than skipping. Record `NOT RUN — <reason>`
only when neither a live backend nor a mock/CI mode is available.

Report E2E results per the **Gate protocol** (`../categories/07-test-verification.md`):
a flaky E2E suite is **one** Medium finding, never one per failing spec, and is not
re-run.

## 8. Code quality check

- **Lint** explicitly — detect the lint script from `package.json` (e.g.
  `npm run lint`) and run it with zero-warnings enforcement (e.g.
  `--max-warnings=0`).
- **Type-check** explicitly — e.g. `tsc --noEmit`. This is separate from lint;
  both must pass.
- Then run the `sonar-check` skill (the frontend `sonar-check` uploads the scan,
  downloads reports to `build/sonar-reports/`, and fixes quality-gate failures).

Fix errors/warnings before committing. If the fixes are too complex, present a
plan and ask for confirmation first.

If `sonar-check` cannot reach the registry, record the Sonar gate as
`NOT RUN — no registry access` per the Gate protocol — not a finding.

## 9. Over-engineering

No stack-specific override — ponytail is language-neutral. Follow
`../categories/09-over-engineering.md`.
