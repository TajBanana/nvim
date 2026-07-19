# 3. Code review & refactor

Use skills relevant to the codebase to review the changes for best practices,
anti-patterns, and potential bugs. Then:

- Analyze changed files for cyclomatic complexity and readability.
- Flag any file much larger than ~500 lines; identify the specific areas of
  complexity. If complexity can be reduced, propose a specific refactor plan
  (extract methods, re-assign component responsibilities) and **ask for
  confirmation before refactoring**.
- Favor self-documenting code: intention-revealing naming, single responsibility,
  linear execution flow, encapsulation of complexity, constants over magic
  numbers, type annotations.
- Where comments are warranted, ensure they are effective: explain the "why" not
  the "what", document intent and rationale, use standardized formats.

Record findings per `../decision-framework.md`.
