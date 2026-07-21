# 4. Architecture

Review the system architecture and design of the branch's changes:

- **Coupling** between distinct features.
- **Consistency** with patterns already established elsewhere, or a justified
  divergence.
- **Layering / dependency direction** — no lower-level module reaching into a
  higher-level one; no new circular dependencies.
- **Placement correctness** — new code lives in the module/layer/boundary it
  belongs to, not bolted onto something unrelated for convenience.
- **Duplication vs premature abstraction** — consolidate logic that now repeats;
  avoid abstractions introduced ahead of real need.
- **Extensibility** — check the target repo's backlog stubs, proposed specs, and
  pending change folders for planned work the current design should not foreclose.

This review is **not limited to the diff**: surface pre-existing architectural
issues in code the branch touches or depends on.

For any file that (a) exceeds ~400 lines or (b) mixes 3+ distinct concerns
(rendering, async/lifecycle, external-system integration, embedded domain logic,
multiple independently exposed outputs), read it **end-to-end** — not just the
diff hunks — and check for:

- **Misplaced domain logic** — business/domain decisions embedded in a file whose
  layer is something else (rendering, routing, IO adapter, controller). Flag by
  placement, not quality.
- **Fragile external integration** — reaching into another module's/library's/
  platform's internal or undocumented details instead of a stable contract. Check
  the version history of that region; a prior bugfix there signals recurrence.
- **Inconsistent internal extraction** — the same sub-problem solved twice in the
  file with only one instance extracted to a shared module. Flag the asymmetry.
- **Duplicated derivation** — the same conceptual value computed via two code
  paths. Flag as a drift risk even if they currently agree.
- **Cohesion** — count distinct concerns; 3+ is itself a finding.

Verify test coverage against the *specific* logic found this way, not the file in
general. Record findings per `../decision-framework.md`.
