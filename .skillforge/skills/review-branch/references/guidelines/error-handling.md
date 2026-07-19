# Error handling

Review how the code **detects, represents, propagates, and records** errors. Each stack file
layers its own idioms on top of this neutral guidance (see each `../stacks/*.md` §2); the
Gradle/Kotlin stack additionally applies the `kotlin-error-handling-guidelines` rule.

## Error types and how to treat each

Classify each error, then check it is handled per its type:

1. **Logical** — an alternative outcome that can legitimately occur in the domain (a
   currently-missing record that may arrive later; input valid but not acceptable in the
   current state). **Return it explicitly** as a result the caller must handle — do not swallow
   it, and do not throw it past the caller as if it were exceptional.
2. **Pre-condition** — a documented input/caller contract (e.g. an argument must be > 0).
   Document it, and **signal a violation loudly** as a programming error, not a recoverable result.
3. **Internal-state** — an invariant that should never break if the code is correct. **Signal
   loudly** as a programming error.
4. **Technical** — an environmental/dependency failure (network, IO, database). **Propagate** it,
   or convert it to the layer's appropriate error signal; never silently drop it.

**Don't leak internals across a trust boundary** — stack traces, SQL, secrets, and internal
identifiers must not reach a **remote client, an external API caller, or a user interface**;
surface only generic, safe detail there. In-process (a local caller in the same service) and
server-side logs may carry full detail — the trust boundary, not the information itself, is
what to guard.
