# Logging

Review changes and additions to logging. Each stack file layers its own framework/idioms on
top of this neutral guidance (see each `../stacks/*.md` §2); the Gradle/Kotlin stack
additionally applies the `kotlin-logging-guidelines` rule.

## Where logs typically belong (orientation, not a checklist to enforce)

Logs usually accompany: major decisions/branches; errors and unexpected states; external
calls and IO (database, HTTP); important business/domain events (login, payment, order
changes); failures, retries, and slow operations; startup/shutdown/deployment milestones.
Use this to recognize a *genuinely* missing log — not to demand a log at every such point.

## What to flag (high-signal only — avoid noise)

- **A swallowed critical failure.** A significant failure is caught/ignored and the code
  continues with **no log at all**, so the failure leaves no trace. This is the only
  missing-log finding — do **not** flag routine points that merely *could* carry a log.
- **Wrong severity level.** The level misrepresents the event: an expected business exception
  at `error`; a genuine failure hidden at `info`/`debug`; `debug`/`trace` volume on a hot path
  in production.
- **A message that misdescribes the event.** What is logged is not what actually happened —
  the message names a different outcome or branch than the code took.
- **A message that cannot identify the event.** So bare it does not say what occurred (e.g.
  `"error"` with no indication of what failed). Judge only whether the event is *identifiable
  at all* — do **not** judge conciseness, completeness, or verbosity; those are subjective
  style, and flagging them is noise.
- **Clear over-logging.** Logging in a tight loop / per-item on a hot path / at high volume for
  a routine event. Only clear cases, not taste.
- **Leftover / purposeless logging.** A log statement with no operational purpose — dev or
  debug **scaffolding left in** committed code (a "got here"/checkpoint trace, a raw
  value/object dump added while debugging, a stray `console.log`). Flag it for removal. This is
  **not** legitimate `debug` tracing of a real flow (noisy-but-tolerable, above) — the test is
  whether the log answers a real troubleshooting question or is only an artifact of someone's
  debugging session.

## Severity levels

- **Error** — a failure of a function in the system; likely user-visible; needs human
  intervention.
- **Warn** — an impending or recovered problem worth tracking but not needing immediate
  intervention (a retry that recovered, a deprecated API).
- **Info** — normal behavior, milestones, state changes, and typical business exceptions
  (e.g. login failed due to bad credentials).
- **Debug** — flow-tracing useful in development/integration; noisy but tolerable in prod.
- **Trace** — detailed program-flow tracing; effectively never on outside local debugging.

## How to log

- Log through the project's **logging framework**, never raw stdout/stderr (`println`,
  `System.out`, `print`, or `console.log` in non-UI code).
- **Don't compute expensive log arguments unconditionally** — guard or lazily evaluate work
  done only to build a message a disabled level would discard.
- When logging an error, include the **exception / stack trace**. Server-side logs may carry
  full internal detail — the "Don't leak internals across a trust boundary" rule in
  `error-handling.md` is about a *remote client / UI*, not the log.
- **Never log secrets or PII** — credentials, tokens, full card/account numbers, personal
  data — even server-side.
