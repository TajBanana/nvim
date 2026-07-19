# Repo resolution: directory layout, registry, lifecycle, lock semantics

Every skill that needs a checkout of a dependent or reference repository goes
through the resolver skills listed below. No skill clones, fetches, or
computes a repo path on its own.

## Skills

- `resolve-repo-worktree` — low-level cache + worktree mechanics. Lock-unaware.
- `acquire-feature-repo` — feature-scoped lifecycle wrapper (lock + symlink + .gitignore).

  `resolve-repo-worktree` and `acquire-feature-repo` take the git URL for an
  unregistered repo via `--url <git-url>` (use `--url '<pending>'` for a new local
  sub-component with no remote yet). There is no stdin or interactive-prompt fallback:
  an unregistered repo invoked without `--url` is an error, as is a `--url` that
  conflicts with an already-registered URL.
- `release-feature-repo` — symmetric counterpart of acquire.
- `attach-remote` — wire a real remote onto a `<pending>` local sub-component (rebase onto it).
- `resolve-artifact-source` — coord → repo mapping via the registry, then read-only worktree.
- `sync-submodule` — bump the monorepo gitlink to a reviewed, pushed component
  commit.

## Public contract

1. **Path shape for committed markdown links.** A consumer doc may link into a
   feature-mode repo using the path `references/repos/<repo>/<subpath>`. This shape
   is stable; the resolver guarantees the link resolves whenever the (project,
   feature) pair is the active holder of `<repo>`. The path is a symlink under the
   hood, but the shape is the contract.
2. **Skill API surface.** Consumer skills interact with the resolution system only
   through the skills above. They do not read or write the cache directory, the
   worktree directories, the registry file, the lock files, or the symlinks directly.
3. **Registry as project state.** The registry file is project-scoped, machine-
   readable, and committed to git.

## Submodules

Submodule components are resolved from **`.gitmodules`** (path + url), not
`references/repos.yaml` — the registry is only for non-submodule referenced repos.
The component cache-key name is the url basename (minus `.git`); the cache and
lock are shared with any like-named referenced repo within the project.

- **Reads** of submodule content are **in place** — the submodule is already
  checked out at its pinned commit. The `--ref` read-only worktree mode is for
  repos not physically present.
- **Writes** go directly in the submodule directory: `git -C <submodule-path>
  checkout -b <branch>`, edit, commit, push — then `sync-submodule` to re-pin
  the gitlink.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `SKILLFORGE_HOME` | `~/.skill-forge` | Root for the shared cache. |
| `SKILLFORGE_WORKTREE_DIR` | `${SKILLFORGE_HOME}` | Root under which `feature-worktrees/` and `read-only-worktrees/` live. |

## Directory layout

```
${SKILLFORGE_HOME}/references/repos/<repo>.git/                              ← bare cache (shared by all modes)
${SKILLFORGE_WORKTREE_DIR}/feature-worktrees/<F-XXX-slug>/<repo>/            ← feature-mode worktree
${SKILLFORGE_WORKTREE_DIR}/read-only-worktrees/<repo>/<sanitized-ref>/       ← read-only-mode worktree
<parent-project>/references/repos.yaml                                       ← registry (CHECKED IN)
<parent-project>/references/repos/<repo>                                     ← symlink → feature worktree (gitignored)
<parent-project>/.skillforge/locks/feature-repo-locks/<repo>                 ← lock file: "<F-XXX-slug>" (gitignored)
<parent-project>/.skillforge/locks/registry.lock                             ← flock target for registry mutations (gitignored)
```

`.gitignore` includes (added idempotently): `references/repos/` and `.skillforge/locks/`.
The trailing slash on `references/repos/` is significant — it matches only the
directory, so the sibling file `references/repos.yaml` stays tracked.

Sanitization for read-only ref directories: replace `/` with `_`.

## Registry schema (`references/repos.yaml`)

```yaml
referenced_repositories:
  - name: payments-service
    url: https://github.com/org/payments-service
    artifacts:
      - type: container
        coordinate: registry.example.com/org/payments-service

  - name: oatms-models
    url: git@gitlab.thalesdigital.io:.../oatms-models.git
    artifacts: []

  - name: analytics
    url: https://github.com/org/analytics
    artifacts:
      - type: npm
        coordinate: "@org/analytics-sdk"
      - type: container
        coordinate: registry.example.com/org/analytics-*
      - type: maven
        coordinate: com.example:analytics-core
```

Fields:
- `name` (required, unique): the repo's local handle.
- `url` (required): git remote URL. Placeholder `<pending>` allowed for a new
  sub-component with no remote yet.
- `artifacts` (optional, list of objects): each has `type` (one of `container`,
  `maven`, `npm`, `pypi`) and `coordinate` (glob `*` supported).

Per-repo role is intentionally absent — access pattern belongs to the operation,
not the repo.

## Tag convention

Internal artifacts are released on `v`-prefixed tags by convention. The resolver
tries `v<version>` first and falls back to plain `<version>` if no v-prefixed tag
exists. Callers can pass `--ref <override>` to bypass.
