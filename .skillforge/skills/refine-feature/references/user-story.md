# `US-XXX`: User Story Title

## Story

As a `stakeholder role`,
I want `capability or outcome`,
so that `value or benefit`.

Keep this to the canonical three-line form. If you cannot fit the
intent into this shape, the story is probably two stories or is leaking
implementation detail. The "so that" clause is the most important part —
it is the value the CPO is validating.

## Acceptance Criteria

The conditions under which a reviewer would agree the story is delivered.
Written from the stakeholder's perspective, not from the system's.

- AC-1: `observable condition the stakeholder can verify`
- AC-2: `another condition`
- AC-3: `another condition`

Acceptance criteria are not test cases. They describe what "done" looks
like to the stakeholder. The concrete test cases live in the use case
specs (as validation scenarios) that implement this story.

## Use cases

The use cases that, taken together, flesh out this story:

- [UC-XXX: short title](../use-cases/UC-XXX-short-title.md) — covers `AC-1`, `AC-2`
- [UC-YYY: short title](../use-cases/UC-YYY-short-title.md) — covers `AC-3`

A story with zero use cases is unimplemented intent. A story whose use
cases do not collectively cover every acceptance criterion is
under-specified.

## Jira

<!-- Maintained by this repo's CI pipeline. Do not edit by hand. -->

The Jira issue for this user story is created and kept in sync by this repo's CI
pipeline. On merge it creates the Jira issue (type **Story**, a child of the
parent feature's Jira issue), writes the issue link into this section, and updates
the Jira status as the story ships. No manual ticket creation is needed; do not
author or edit the link by hand - the pipeline owns this section.

## Open questions

- `Q-1`: ambiguity blocking approval, with target resolution
- `Q-2`: another open item
