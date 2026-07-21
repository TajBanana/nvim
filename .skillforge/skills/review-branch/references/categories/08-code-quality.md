# 8. Code quality check

Run the stack's formatting, linting, type-checking, and static-analysis gates and
fix what they surface. The concrete commands are in the detected stack file
(e.g. formatter + `sonar-check`, or linter + type-checker + `sonar-check`).

If the fixes are too complex to apply directly, present a plan and ask for
confirmation before proceeding. Record anything left unresolved as findings per
`../decision-framework.md`.

Run these gates once and report them per the **Gate protocol** in
`07-test-verification.md`. In particular, when Sonar cannot run (e.g. no registry
access), record `NOT RUN — <reason>` — never omit it and never raise it as a
finding.
