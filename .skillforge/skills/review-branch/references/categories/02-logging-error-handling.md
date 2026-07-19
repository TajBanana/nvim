# 2. Logging & error handling

Review changes and additions to log messages, and check for missing logs. Review
changes to error handling and reporting.

The shared, language-neutral baseline for this category is `../guidelines/error-handling.md`
(error handling — error-type taxonomy + treatment; don't leak internals across a trust
boundary) and `../guidelines/logging.md` (logging — when to log, log-level severity, how to
log). Each stack file layers its own concrete rules on top.

Concrete rules are stack-specific — see the detected stack file (e.g. the
Gradle/Kotlin stack applies the `kotlin-logging-guidelines` and
`kotlin-error-handling-guidelines` rules). If the stack file marks this category
as deferred/skipped, note that and move on.

Record any gaps as findings per `../decision-framework.md`.
