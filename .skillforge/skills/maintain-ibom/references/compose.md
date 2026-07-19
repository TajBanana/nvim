# Compose — assembly / release roll-up (operational)

Read this when the repo is an **assembly** (composes other components) or a **release** (a deployment to
a cluster — of an assembly, or of components' helm charts directly; the assembly layer is optional).
SKILL.md §Compose holds the rules; **resolve / fetch / degraded-recovery /
construct live in `dependency-management.md`**; **this file holds the federate→reduce algorithm** over
already-fetched members. The output is a `System` (assembly / release — one per environment) whose IBOM
is the **federated roll-up** of its members (a `Domain` only if opted in — `dependency-management.md` §6).

The steps: **detect → enumerate → resolve → federate → reduce → emit**. The one that separates a real
roll-up from a lookalike is **federate** — actually reading each member's committed IBOM. Skipping it
(inferring the surface from the assembly's own manifests) gives correct *shape* but an *incomplete,
mis-named* surface (a member's own external deps are lost; provided interfaces get ad-hoc names that
never link to the members' real API entities).

## 1. Detect the construct

- **Assembly** — the repo composes multiple members (a helmfile with several `releases:`, an umbrella
  chart with `dependencies:`, a Kustomize/manifest set over several apps). → `kind: System`.
- **Release** — a deployment **bound to a cluster** with member versions **pinned** (deploy stage /
  cluster values / pinned image tags) — composing an assembly **or components' helm charts directly**
  (the assembly layer is optional). → `kind: System`, **one per environment** (the deployed grouping);
  its **primary deliverable is the boundary API surface**; plus the cluster edge and the
  hard-coded-infra check.
- **Product family** — an **opt-in** grouping → `kind: Domain` that **wraps** the System(s) (never
  replaces one, even 1-1); interfaces stay on the `System`, the `Domain` is pure grouping
  (`dependency-management.md` §6). **Default: no Domain.**
- **Component** — packages/builds/serves **one** unit → not this file (normal single-repo flow).

**Both assembly and release are a `System`** (never a `Component: deployment`); a `Domain`, when opted
in, wraps them. **Construct is judgement from what is deployed, not the registry's filing.**
**Federation is gated on concrete member coordinates, not on the construct** (§2/§3): a *release* pins member `<registry>:<tag>`
coordinates → it federates; an *importable assembly* usually leaves member images to **downstream
injection** (`envVars.image*`) → no coordinate → it does **name-only structural compose** and defers
federation to the release. *Exception:* an assembly carrying **baked-in member image tags** can
federate too — do so, and **flag the hardcoded tags** (`review: needs-review`): pinning what should be
injected is unusual, often a mistake.

If README/CI is ambiguous (importable assembly vs the actual release), ask — default to the engineer's
construct answer.

## 2. Enumerate members

*Listing* the members yields their **names + manifest-pinned tags** — enough for the **primary** resolve
path (registry + convention + bare-clone, §3.2, which needs no image coordinate). A **render** to obtain
each member's `<registry-path>:<tag>` **image coordinate** is needed for **two** things: the §3.3 resolver
fallback (foreign / no-git), and — worth a render even on-estate — to **corroborate the primary
resolution** (`dependency-management.md` §1.1): the coordinate carries the same `(solution, item-type,
name)` triple, so it disambiguates a non-unique name, catches a misleading release/`fullnameOverride`
name, and flags a path that drifts from the registry (rename / migration / phantom image). It
**corroborates; it never replaces** the registry (`dependency-management.md` §1.2). Per mechanism:

- **helmfile** — read `releases:` for member names + pinned tags/charts. *Only for the §3.3 fallback:*
  **run `helmfile template` via the Bash tool** and take each member's `<registry-path>:<tag>` image
  coordinate (the resolver's input). On render failure, log + skip + report.
- **umbrella chart** — read `Chart.yaml` `dependencies:` (render for image coordinates when resolving).
- **manifest set** — the workloads and their images in the manifest directory.

Many assembly repos ship a **`references/repos.yaml`** (or equivalent) mapping each member release →
its source repo + container coordinate — use it as the authoritative member list, and as the resolver's
registry (§3), when present.

*Note:* an *importable assembly*'s rendered image tags are usually **placeholders** (injected
downstream), so the render yields **no concrete coordinate** — federation defers to the release (§1).
Only a release (or an assembly with baked-in tags) gives the resolver a real
`<registry>:<tag>`.

## 3. Resolve each member to its IBOM

An entity **ref/name** is enough for `interface.members` and graph edges, but **not** to federate the
surface — that needs the member IBOM *content* at the **revision deployed in this assembly** (not the
member's latest `main`). Sources, in order:

1. **`catalog_snapshot_path`** — the aggregated catalog, when fresh enough. Cheapest on-infra.
2. **Registry + convention + bare-clone (primary, on-estate).** Resolve the member name → repo via the
   onboarding registry + path convention, then fetch its IBOM with a bare `git show` at the
   manifest-pinned tag — full mechanism in **`dependency-management.md` §1–§2** (it also yields the
   fetched revision + existence probe for free). No image coordinate needed.
3. **The environment's governed resolver (§1 precedence — foreign / no-git fallback).** Only when a
   member has **no git access** via the convention: pass it the **container coordinate**
   `<registry-path>:<tag>` and read `catalog-info.yaml` in the revision-correct **worktree** it returns.
   On a "not registered" miss, backfill its `name → url` registry (the repo's **`references/repos.yaml`**
   or equivalent) with the producing repo (URL from the OCI `org.opencontainers.image.source` label;
   else the platform's registry↔repo path convention, stamped `review: needs-review`; else ask) and
   retry. Defer to the resolver; do not re-implement or clone around it.

`references/repos.yaml` is the resolver's **registry**, not a source you read IBOMs from directly.
Revision-correctness is the point: the resolver path (3) gives each member *as deployed
here*, not its default branch. **The org rule that pipeline tags are immutable makes this free** —
`repo@<tag>` *is* the deployed commit, so `repos.yaml` (repo) + the tag (revision) suffice on-infra;
the OCI `image.revision` label is a robustness nicety, not a requirement.

**Member linkage.** A member already belongs to its own owning `spec.system`, so you cannot claim it
via `spec.system`. Record composition membership as an **`interface.members`** annotation on the
assembly `System` (a comma list of member entity refs), stamped with the resolution provenance
(`registry`/`human` when confirmed, `guessed` until confirmed).

## 4. Federate — read the member IBOMs

Federating the surface needs each member's actual `catalog-info.yaml` **content** at its deployed
revision, sourced (in order):

1. **`catalog_snapshot_path`** — the aggregated catalog export (publish-then-query), when fresh.
2. **Registry + convention + bare-clone (§3.2)** — resolve name → repo, `git show` the IBOM at the
   pinned tag (`dependency-management.md` §1–§2). The **governed resolver (§3.3)** is the foreign /
   no-git fallback.
3. **degrade to a *hole*** — when a member IBOM is unreadable (no snapshot; fetch non-zero): **do not
   infer the child's surface from the assembly's own manifests.** Record a degradation-point hole
   (`interface.federation/degraded: <ref>@<tag>`), keep the parent `confidence: low` /
   `review: needs-review` / *pending federation*, and **recover it later** (`dependency-management.md`
   §4). Holes are honest and retract-free — a fabricated surface would carry wrong names the real IBOM
   must later undo. **Federate the members you *can* read** (partial, M of N); only the unreadable ones
   become holes.

**Federation is bottom-up.** A release/assembly can only federate members that have **published their
own IBOM** (a committed `catalog-info.yaml`). Resolution is necessary but not sufficient: **if the member
has no `catalog-info.yaml`, it is *uncatalogued*** — there is nothing to read, so **degrade to a hole**
first. Then, **if the member is reachable and has no IBOM, self-healing by vendoring is the recommended
recovery** (`dependency-management.md` §4) — the parent clones it at the pinned tag, runs the skill, and
flattens the surface; it **waits** only when the member is unreachable or the human declines. It
**never** authors, asks for, or tasks the member's IBOM (§4.3 there). Convergence is bottom-up and happens
on the child's **own timeline**: when a member eventually publishes its own IBOM, the roll-up federates it
automatically and cancels the internal pairs.

An entity **ref** alone (§3 intro) is enough for `interface.members` and graph edges but **not** to
federate the surface. When you *can* federate (1 or 2), read each member's IBOM and collect, *by the
member's real committed entity names*:

- its `providesApis` + `provides/candidate` (what it offers),
- its `consumesApis` + `consumes/candidate` (what it needs, **including its own external deps** — e.g.
  payments-api's `shipping-svc-compute` / `billing-engine-be`),
- its `dependsOn` resources.

Do **not** re-derive these from the assembly's own helmfile/chart-values — that view sees ingress
hosts and proxy targets but not the member's full contract set, and it invents names
(`payments-api-http-api`) that never match the member's real entities (`payments-api-settlement-events`,
`pa-control-http-api`). If a member IBOM is **unreadable**, record an
`interface.federation/degraded: <ref>@<tag>` **hole** — **never** a manifest-inferred surface — keep the
parent `confidence: low` / `review: needs-review` / *pending federation*, **federate the members you
*can* read** (M of N), and recover it later (`dependency-management.md` §4).

## 5. Reduce the wiring

Over the *federated* member surfaces:

1. **Match** provider↔consumer across members (member A's provides vs member B's consumes), by
   contract identity / entity ref — not by fuzzy name.
2. **Cancel** each matched pair — internal; do not emit it on the assembly node. (storefront-frontend →
   payments-api is internal and disappears.)
3. **Internalize infra** the assembly deploys for its members (an in-namespace NATS, a secrets
   release) → an in-assembly `Resource` (`spec.system: <assembly>`); the member's former external
   dependency on it is cancelled.
4. **Carry up the unmatched surface, both sides, by real member names:**
   - unmatched **consumers** → `interface.consumes/candidate` (foreign dependencies) — **union across
     members**, so a member's own external deps (shipping-svc, billing-engine) appear here;
   - unmatched **providers** → `interface.provides/candidate` (the external provided surface — UIs,
     APIs, event streams exposed via the gateway), named after the members' real provided interfaces.
     **Never** flatten to a lone `platform:kubernetes-ingress` token.

## 6. Emit + reconcile

- `kind: System` (assembly / release — one `System` per environment; a `Domain` only wraps, if opted
  in), `spec.owner`, `interface.members`, the
  assembly-level `implements` (helm-chart / ingress / api-gateway / service-mesh — Kong is
  `platform:api-gateway`, not just ingress), the rolled-up `provides/candidate` + `consumes/candidate`,
  and the internalized `Resource`s.
- **Ledger discipline is identical to a component:** `review` is the rollup with precedence
  (`contradicted > needs-owner > needs-review > ok` — a contradicted foreign dep makes the System
  `contradicted`); `confidence` is worst-of over the composed member facts; `checked-at` is a tag or
  sha. Unconfirmed member refs → `provenance: guessed` + a blocking question.
- **Release only:** add the cluster edge (actual ingress/egress) and **flag any endpoint hard-coded to
  our infrastructure** — it must be configurable to be foreign-deployable.
