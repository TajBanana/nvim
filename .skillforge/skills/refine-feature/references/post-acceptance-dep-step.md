# Post-Acceptance Dependency Step

Run this step only after the user has reviewed and accepted the full spec.

## Feature variant — use from `refine-feature`

1. **Infer downstream repos.** Reason about the accepted spec and identify downstream repos
   likely to need a backlog stub — including any new sub-modules or sub-components implied by
   the spec that do not yet have a remote repository. **For assembly repos, this step is almost
   always applicable** — assemblies cannot implement service logic directly, so every capability
   requiring new or changed service behaviour needs a stub in the relevant service repo. Surface
   each candidate to the user for confirmation. Dismiss those the user rejects.

2. **Resolve any new repos** not yet in the `references/repos.yaml` registry using the shared
   on-demand resolution procedure in `repo-resolution.md`, with `acquire-feature-repo
   <F-XXX-slug> <name>`. For a repo that **already exists** (has a known remote), resolve it
   the normal way.

   For a **brand-new sub-component that has no remote yet**, do not silently create one — ask
   the user how to create it, then proceed by the chosen path:
   - **(a) User provides a remote URL.** The user creates the repository on their host (it must
     already contain at least one commit) and gives you the URL. Pass that URL via
     `acquire-feature-repo <F-XXX-slug> <name> --url <git-url>` (the resolver registers it and
     clones). If the command reports the remote has no commits, stop and ask the user to push an
     initial commit, then retry. From here treat it as an existing downstream repo (branch +
     commit + the normal step-5 downstream commit apply).
   - **(b) Claude creates it locally.** Pass the literal `<pending>` via
     `acquire-feature-repo <F-XXX-slug> <name> --url '<pending>'`. The resolver creates a local
     repo under `references/repos/<name>` on an orphan branch (registry URL stays `<pending>`).
     It has no remote, so the step-5 exemption applies: write the stub but do not commit there.
     Tell the user they can wire up a remote later with the `attach-remote` skill once they
     create the repository.

3. **Write the backlog stub in the downstream repo.**
   - For **existing** downstream repos: ensure the repo is on a non-main branch before writing.
     If already on a non-main branch, confirm with the user whether to continue on that branch or
     create a new one. If on main, create a new branch.
   - For **new sub-components** (acquired via `acquire-feature-repo` with a `<pending>` registry
     URL): skip the branch check — the freshly initialised bare cache has no history yet.
   - Follow the shared procedure in `writing-backlog-stubs.md`, targeting the downstream repo's
     `docs/features/backlog/`. Use this Origin (substitute the calling skill name):
     ```
     Dependency of F-XXX <parent-feature-title> in <parent-repo-name>, surfaced during refine-feature on YYYY-MM-DD.
     ```

4. **Add the dependency entry** to the feature's `feature.md` `## Dependencies` section (create
   the section if absent), with annotation `— pending`. Place `## Dependencies` between
   `## Stories` and `## Origin`:
   ```
   - [B-XXX: <stub-title>](references/repos/<repo-name>/docs/features/backlog/B-XXX-<slug>.md) — pending
   ```
   Only create the `## Dependencies` section when at least one entry is confirmed.

5. **Commit separately:**
   - Downstream repo (existing only): commit the new backlog stub on its non-main branch.
     **Skip for new sub-components** — a `<pending>`-URL repo is an independent git repo the
     user must still set up with a real remote; do not commit there.
   - Parent repo: commit the `## Dependencies` update (and the `references/repos.yaml` registry
     entry if a new repo was added in step 2).

## Change variant — use from `change-feature`

Same five steps as the feature variant, including all step 5 sub-component exemptions, with
these two differences:

**Step 3 Origin string** (`<change-folder-date>` is the date in the change folder name;
`<today>` is the date this dep step runs — they may differ):
```
Dependency of change <change-folder-date>-<change-title> on F-XXX <parent-feature-title>
in <parent-repo-name>, surfaced during change-feature on <today>.
```

**Step 4 parent doc:** Add the dependency entry to `feature-change.md`'s `## Dependencies`
section (not `feature.md`). Format is otherwise identical:
```
- [B-XXX: <stub-title>](references/repos/<repo-name>/docs/features/backlog/B-XXX-<slug>.md) — pending
```

## Mono-repo variant — use from `refine-feature` and `change-feature`

Use this variant when submodule mono-repo mode was detected during the pre-flight
check. A submodule is a separate repo embedded by pin, so its stub is authored in
the component (via a worktree) and integrated by bumping the gitlink.

1. **Infer submodules that need stubs.** Reason about the accepted spec and
   identify which submodules have work routed to them. Surface each candidate to
   the user for confirmation. Dismiss those the user rejects.

2. **For existing submodules** (a `path` already in `.gitmodules`):
   - Check out a branch in the submodule:
     `git -C <submodule-path> checkout -b feature/<holder-slug>`.
   - Write the backlog stub to `<submodule-path>/docs/features/backlog/B-XXX-*.md`,
     following `writing-backlog-stubs.md`. When sweeping for near-duplicates, scan
     `<submodule-path>/docs/features/backlog/`. Use this Origin:
     - `refine-feature`:
       ```
       Dependency of F-XXX <parent-feature-title> in <parent-repo-name>, surfaced during
       refine-feature on YYYY-MM-DD.
       ```
     - `change-feature`:
       ```
       Dependency of change <change-folder-date>-<change-title> on F-XXX <parent-feature-title>
       in <parent-repo-name>, surfaced during change-feature on <today>.
       ```
   - Commit and push the stub: `git -C <submodule-path> commit`, `git -C <submodule-path> push`.
   - Bump the gitlink: `sync-submodule <holder-slug> <submodule-path>`, then commit
     the staged gitlink via `git-commit`.

3. **For new submodules** (no existing submodule path):
   - Ask the user to confirm the component name and submodule path.
   - Create the component repo and add it: if the user supplies a remote URL,
     `git -c protocol.file.allow=always submodule add <url> <submodule-path>` and
     commit the `.gitmodules` + gitlink. For a brand-new component with no remote
     yet, create it as a `<pending>` sub-component and wire the remote + run
     `git submodule add` later via the `attach-remote` skill.
   - Check out a branch and write the stub directly in the new submodule directory
     (same Origin as step 2), push, then `sync-submodule` and commit the gitlink.

4. **Add dependency entries** to the feature or change document's `## Dependencies`
   section (create it only when at least one entry is confirmed):
   ```
   - [B-XXX: <stub-title>](<submodule-path>/docs/features/backlog/B-XXX-<slug>.md) — pending
   ```

5. **Commit the dependency update** in the mono-repo via `git-commit`.
