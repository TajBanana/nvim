# Feature vs. tech-task classification

Shared across `add-backlog`, `refine-feature`, and `refine-tech-task` (the
feature-spec skills install together, so this resolves at
`../refine-feature/references/classification.md` from any sibling).

## The test

A change is a **feature** when any actor — user, operator, or developer acting
as the consumer of a new capability — observes new or changed behavior. A
change is a **tech-task** when it produces no such observable difference for
any of those actors.

The test distinguishes two senses of *developer-observable*:

- **Developer-as-code-reader**: a refactor that changes internals but keeps
  outputs and contracts identical is observable only to someone reading the
  code. No new capability is delivered to any actor. This is a tech-task.
- **Developer-as-tool-user**: a new CLI command, test runner, debugging tool,
  developer portal, or SDK intended for developers to invoke is a new
  capability delivered to the developer as a user of that tool. This is a
  feature.

| Input | Class | Why |
|-------|-------|-----|
| Refactor a module; outputs identical | tech | no new capability for any actor |
| Performance work that keeps outputs/contracts identical | tech | behavior parity |
| Dependency / build / CI bump | tech | internal only |
| Internal API refactor (no user/operator/developer-tool surface) | tech | developer-as-code-reader only |
| Observability/logging plumbing | tech | unless an operator-facing surface (dashboard/alert) is added → then feature |
| Add/alter a user- or operator-facing API contract | feature | contract changes |
| New CLI tool or test runner intended for developer use | feature | developer is the tool user; new capability delivered |
| Security hardening | depends | feature only if user/operator/developer behavior changes |
| New user/operator/developer-facing capability | feature | new behavior delivered to an actor |

## The gate (auto-classify, then confirm)

1. Apply the test to the input.
2. State the verdict and the one-sentence reason to the user.
3. Ask the user to confirm before committing to a path. Misclassification is
   costly, so never route silently.

## Re-review on promotion

When promoting a backlog stub, **re-derive** the classification from the stub's
content — do not trust the stored `type:` blindly (a stub may have been misfiled
or its understanding may have shifted). Confirm with the user before routing:
`feature` → `refine-feature`; `tech` → `refine-tech-task`.

## Mixed input

If the input contains both a functional part and a technical part:
1. Ask the user **which artifact to author this run** (feature spec or tech-task).
2. Author the chosen one.
3. Write backlog stubs for the remaining part(s) with the correct `type:` and in
   the correct backlog dir, deduping against existing stubs (modify rather than
   duplicate). IDs come from the shared `B-XXX` counter (see `conventions.md`).
