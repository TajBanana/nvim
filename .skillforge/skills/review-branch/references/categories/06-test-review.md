# 6. Test review

Review the tests around the branch's changes for both coverage and quality.

**Coverage:**

- Identify missing edge cases or logic paths that need additional unit coverage.
- Where the stack has an end-to-end suite, identify critical cross-unit
  functionality that belongs in it.
- Implement any necessary new test cases.

**Test quality:**

- Verify each test's assertions are **non-trivial and assert the test's stated
  objective** — a test named for behaviour X must actually fail when X breaks.
  Flag assertion-free tests, tautological assertions (a value asserted against
  itself or against a mock's own configured return value), and "it doesn't throw"
  tests that claim to verify a result.
- Watch for **excessive mocking that makes a test trivial** — mocking the very
  unit under test, or mocking so much that the test only re-verifies its own setup
  (that the mocks were called with the arranged values) rather than real
  behaviour. Prefer exercising real collaborators where practical.
- Identify redundant or trivial tests to consolidate or remove.

See the detected stack file for which suites exist and how to run them. Record
coverage gaps and weak tests as findings per `../decision-framework.md`.
