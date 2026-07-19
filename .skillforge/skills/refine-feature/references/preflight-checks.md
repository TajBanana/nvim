# Pre-flight Checks

Run both checks before any other file operation in refine-feature and
change-feature.

## Pre-flight directory check

Verify the feature documentation root uses the correct plural name:

1. If `docs/features/` exists — proceed normally.
2. If `docs/feature/` (singular) exists instead, stop and recommend:
   > "This repo uses `docs/feature/` — the current convention is `docs/features/` (plural).
   > Rename before proceeding?"
3. If the user agrees: run `git mv docs/feature docs/features` (or plain `mv` +
   `git add docs/features` if untracked — verify tracking with
   `git ls-files --error-unmatch docs/feature 2>/dev/null` before choosing the path).
   Commit the rename immediately via the `git-commit` skill with message
   `docs: rename docs/feature to docs/features`. Then continue, using `docs/features/` for all
   subsequent operations.
4. If the user declines, continue using `docs/feature/` as-is for this session.

## Assembly check

Using the definition in the `architecture-context` rule, determine whether the current
repo is an assembly. If it is:

- **Assemblies cannot implement service logic directly.** Every story, use case, or delta that
  requires new or changed service behaviour must be backed by a backlog stub in the relevant
  service repo (existing or new sub-component).
- Keep this constraint in mind throughout drafting — any capability or delta implying
  service-level work is automatically a candidate for the post-acceptance dep step.
- At the post-acceptance dep step, be especially thorough: most assembly features and changes
  will have at least one service dependency.

**Abstraction level for assembly specs.** Assembly specs describe composition and orchestration
contracts, not service-level implementation. When drafting stories, classify each story:

- **Assembly-level story** (deployment, configuration, rollout, routing) → in scope; draft
  normally.
- **Service-level story** (new or changed service behaviour) → not in scope; capture in the
  post-acceptance dep step as a backlog stub in the relevant service repo.

If a proposed story is ambiguous, ask: "Does this require changing code inside a service, or
only how the assembly composes and configures existing services?" Service-level → dep step.
Assembly-level → in scope.

**Self-contained service requirement.** If the **entire** requirement is service-level work in a
**single service**, with no assembly-level story (composition, configuration, rollout, routing),
do not create an assembly feature spec at all — an empty-stories assembly spec plus one dep stub
is pure ceremony. Instead:

1. Resolve the service repo via the repo-resolution procedure
   (`acquire-feature-repo <slug> <service>`; see the `repo-resolution` rule).
2. Write a seed backlog stub in `<service>`'s `docs/features/backlog/` following
   `writing-backlog-stubs.md`. There is no parent feature to link to, so use this Origin:
   ```
   Surfaced during refine-feature in <assembly-repo> on YYYY-MM-DD; self-contained service
   requirement routed to <service> (no assembly-level concern).
   ```
3. Prompt the user: _"This requirement is entirely service-level and self-contained in
   `<service>`. I've written a seed stub at `<path>`. To define it as a full feature, switch to
   an agent rooted in `<service>` and run `refine-feature` on that stub — that uses the service
   repo's own feature-spec skills."_

Unlike a mono-repo submodule component, an assembly's services are **separate repos**, so the
assembly agent must not author the service's full spec — it seeds the stub and hands off. The
moment any assembly-level concern exists alongside the service work, fall back to the normal
assembly flow (assembly spec + dep stub via the post-acceptance step).

## Mono-repo check

Determine whether the current repo is a **submodule-based mono-repo**:

1. Run `git config -f .gitmodules --get-regexp '\.path$'` (or `git submodule status`)
   to discover embedded submodules. Each `path` is a submodule directory.
2. If `.gitmodules` declares one or more submodule paths → mono-repo mode. Record
   those submodule paths as the component list for this session.
3. If there is no `.gitmodules` (or it declares no submodules), treat this as a
   plain repo.

A submodule is a **separate repository embedded by pin**. Work routed to a
submodule is authored by checking out a branch directly inside the submodule
directory (`git -C <submodule-path> checkout -b <branch>`) and integrated by
bumping the gitlink with `sync-submodule`.

When mono-repo mode is confirmed, surface the discovered submodules to the user so
they can correct or supplement the list before drafting begins.

Keep the **mono-repo constraint** (see `glossary.md`) in mind throughout drafting:
work specific to a submodule becomes a backlog stub in
`<submodule-path>/docs/features/backlog/` — not an in-scope story. Cross-cutting
logic already present in the root is in-scope.

**Abstraction level for root-level specs involving a new submodule component.** When
the feature creates or implies a **new submodule component**, ask before drafting
stories:

> "Should the root-level spec describe only the integration contract — what interfaces
> the new component exposes and how existing submodules interact with it — with
> implementation stories delegated to the new component's own spec?"

- **Interface-level (yes, default):** Write `feature.md` with description + in/out
  scope only. The `## Stories` section holds a brief delegation note (see template).
  Implementation stories go into the new component via the post-acceptance dep step.
- **Full-detail (no):** Draft stories and use cases normally in the root spec.

The interface-level answer is the default when a new submodule component is the
primary delivery vehicle for the feature.

**Self-contained submodule requirement.** If the entire requirement lives in a
single existing submodule with no cross-cutting work in the root and no
integration contract spanning multiple submodules, author the feature spec
**in that component**: check out a branch (`git -C <submodule-path> checkout -b
<branch>`), write the spec under `<submodule-path>/docs/features/`, commit and
push there, then bump the gitlink (`sync-submodule`) and commit it. The committed
`<submodule-path>/docs/features/...` link resolves in the monorepo once the
pointer is bumped. No root spec, no dependency entry, no stub.

If any cross-cutting root work or multi-submodule concern exists, fall back to the
root-first + stub flow.

If both assembly mode and mono-repo mode are detected, apply the **mono-repo variant**
at the dep step for submodule component work; the assembly constraint still governs
in-scope drafting (assemblies cannot implement service logic directly).
