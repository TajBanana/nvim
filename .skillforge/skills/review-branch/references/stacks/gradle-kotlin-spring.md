# Stack: Gradle / Kotlin / Spring

Concrete steps per category for a Gradle-built Kotlin/Spring repository.

## 1. Metrics

Applies. Verify affected endpoints publish Prometheus (Micrometer) metrics for
error rates and load/performance as listed in `../categories/01-metrics.md`.

## 2. Logging & error handling

Apply the neutral `../guidelines/error-handling.md` and `../guidelines/logging.md` as the base,
then the `kotlin-logging-guidelines` rule to log message changes and the
`kotlin-error-handling-guidelines` rule to error handling/reporting changes (Kotlin/Spring
specifics: Arrow `Either`, `require`/`check`, HTTP + RFC 9457 problem-details).

## 3. Code review & refactor

Use any Kotlin/Spring review skills installed in the repo alongside the generic
checks in `../categories/03-code-review.md`.

## 4. Architecture

No stack-specific override; follow `../categories/04-architecture.md`.

## 5. Documentation

Reconcile existing docs (README, `architecture.md`/diagrams, module docs) per
`../categories/05-documentation.md`.

## 6. Test review

Review unit tests (and any integration suite present) for coverage and quality per
`../categories/06-test-review.md`.

## 7. Test verification

Run the unit tests:

```bash
./gradlew test
```

Investigate and fix failures even if unrelated to the change.

## 8. Code quality check

```bash
./gradlew spotlessApply
```

Then run the `sonar-check` skill and address the issues it reports. Fix any
formatting/lint issues surfaced by Spotless.

## 9. Over-engineering

No stack-specific override — ponytail is language-neutral. Follow
`../categories/09-over-engineering.md`.
