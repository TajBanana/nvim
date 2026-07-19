# Stack: generic (no Gradle or frontend markers)

Use this when the repo matches neither the Gradle/Kotlin/Spring nor the frontend
stack — e.g. a Python/Go/Rust service, or a docs / skills / config / infrastructure
repo. There are no stack-specific command packs; run
the categories language-agnostically and use the repo's **own** tooling where it
exists. Discover that tooling first: look for a `Makefile`/`Justfile` target, a
`scripts/` entry, a task runner, CI config, or a documented command in the README.

## 1. Metrics

Skip unless the repo is a backend service exposing APIs. If it is, apply
`../categories/01-metrics.md` against whatever metrics library it uses.

## 2. Logging & error handling

Apply `../categories/02-logging-error-handling.md` and the neutral
`../guidelines/error-handling.md` and `../guidelines/logging.md`, using the repo's own logging
and error-handling conventions (no stack-specific rule pack is assumed).

## 3. Code review & refactor

Follow `../categories/03-code-review.md`.

## 4. Architecture

Follow `../categories/04-architecture.md`.

## 5. Documentation

Follow `../categories/05-documentation.md`.

## 6. Test review

Follow `../categories/06-test-review.md` against whatever test suite the repo has.

## 7. Test verification

Discover and run the repo's own test command (e.g. `pytest`, `go test ./...`,
`cargo test`, a `make test` target, or a `scripts/` entry). Investigate and fix
failures per `../categories/07-test-verification.md`. If the repo has no automated
tests, note that and move on.

## 8. Code quality

Discover and run the repo's own format / lint / type-check / validation gates
(e.g. a linter, formatter, type-checker, or a project script such as a
`validate` / `check` / `lint` target, a `Makefile`/`Justfile` target, or a
documented CI command). If the `sonar-check` skill is installed and the repo has a
Sonar setup, run it too. If the repo exposes no such
gates, note that and move on.

## 9. Over-engineering

No stack-specific override — ponytail is language-neutral. Follow
`../categories/09-over-engineering.md`.
