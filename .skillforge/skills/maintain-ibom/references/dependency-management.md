# Dependency management — resolving referenced members

**Scope.** This file is about a **parent's member dependencies** — the components/assemblies a
**assembly or release composes** — and how to turn each *reference* into its committed IBOM
(`catalog-info.yaml`). It **also** resolves a repo's own **first-party library dependencies** (linkage,
§7) — the one class of package dependency that is an interface. *Third-party* packages stay out (SBOM,
`interface.implements` at most); operational infra stays `spec.dependsOn`. It is the companion to
`compose.md`: **`compose.md`
holds the federate→reduce algorithm over already-fetched members; this file holds resolve → fetch
→ degrade/recover, plus the construct-from-deployment defaults.** Read it for an assembly/release
repo, alongside `compose.md`.

## 0. Hard rule — onboarding gives references, never terminology

The org runs an **onboarding registry**: solution YAMLs (one per solution, under the onboarding
repo's `inputs/solutions/`) that list every `component` / `assembly` / `release` with its `name`
and `teams`. The platform provisions each at a **fixed path** under a configurable anchor:

```
<org_path_prefix>/<solution>/<item-type>/<item-name>   item-type ∈ {components, assemblies, releases}
```

**The anchor and host are inputs, never baked in.** `org_path_prefix`, `git_host`, and
`image_registry_prefix` (§1.1) are the skill's **own** cross-locus configuration — the same portability
rule this skill enforces on the repos it scans (a hard-coded endpoint breaks foreign deployment). The
shipped defaults live in `references/org-config.yaml`; an explicit run input overrides them —
precedence is **an explicit run input > `references/org-config.yaml` > ask (never guess)**. The
examples below use a **generic placeholder estate**, since this file is estate-neutral; a foreign
steward supplies theirs, and the whole resolver re-points with no other change.

Use the registry **only to resolve references** (name → repo path) and `teams` → `spec.owner`. Its
`component/assembly/release` filing is a **provisioning** taxonomy, **not** an architecture — **do
not** infer Backstage kind/construct from it. Terminology (kind, grouping, the interface surface)
comes from **what is deployed + judgement** (§6). Any `import_url` in the registry is a **migration
seed** (where GitLab imported history *from*); the canonical repo is **always** the fixed path —
**ignore `import_url`.**

### Locating the registry on the dev machine

The registry lives in the onboarding repo (`<org_path_prefix>/onboarding`, under `inputs/solutions/` —
configured in `references/org-config.yaml`, `onboarding_registry`). This
is a **compose-only** prerequisite — a *leaf* component repo has no members to resolve and never needs
it. Read it like a member IBOM (§2), **without mutating anything**, in this order:

1. **`$<onboarding_env_var>`** (a local clone — the onboarding-repo env var whose **name** is estate
   config: `onboarding_registry.env_var` in `references/org-config.yaml`; a dev who has onboarded before
   already has it exported). If set and valid: `git -C "$<onboarding_env_var>" fetch
   --quiet` (**non-mutating — no pull/checkout**) then read `git show FETCH_HEAD:inputs/solutions/<sol>.yaml`.
   A stale clone would falsely flag a new member as `needs-onboarding`, so fetch first; **offline**, fall
   back to the working-tree copy, flagged *possibly stale*.
2. **Unset / missing → a shallow bare clone to a cache** (same cheap mechanism as §2; the registry is
   small): `git clone --bare --depth 1 --filter=blob:none <onboarding-url> onboarding.git` (URL scheme
   matched to the dev's protocol, §2), then `git show HEAD:inputs/solutions/<sol>.yaml`. **Suggest the
   dev set `$<onboarding_env_var>`** to persist it.
3. **Unreachable** (no network / no auth) → **degrade, do not guess.** Members are unresolvable → record
   them as holes (§4) flagged `needs-review` ("onboarding registry unreachable"); recommend setting
   `$<onboarding_env_var>`. **Never** fall back to constructing a repo path from the convention alone
   when the registry cannot be read — that would reintroduce a guess.

## 1. Resolve — member name → repo path

**Precedence — prefer the environment's resolver; the built-in below is the standalone fallback.**
If the environment provides a **governed resolver** — a shared capability that turns a coordinate into a
read-only repo worktree and owns the cache / worktrees / registry — **use it, and do not clone or compute
a repo path yourself.** Pass the coordinate (a **deploy/container** coordinate for a member, §1–§6; a
**package** coordinate — maven / npm / pypi — for a linkage library, §7) and take the worktree it returns.
This keeps resolution consistent with the rest of the toolchain and off a second, private clone path. The
**registry + convention + bare `git show`** described in §1–§2 is the **self-contained fallback** — for a
standalone / foreign checkout where no such capability is present. Both produce the same input to §2's
fetch semantics; only *who clones* differs. *(No asset is named here on purpose: the capability is
detected, and the environment's own governing convention — if any — binds the concrete resolver, so this
file stays self-contained and portable when copied into any repo.)*

Resolution is a pure function of three fields the registry already carries:

```
repo(solution, item-type, name) = <org_path_prefix>/<solution>/<item-type>/<name>
```

`payments-api` (a component of solution `payments`) → `<org_path_prefix>/payments/components/payments-api`.
All **three** coordinates are required — a name is **not** unique on its own (`shared/components/report-tool`,
`shared/assemblies/report-tool`, `shared/releases/report-tool` are three distinct repos). If the ref is
not in any solution YAML, it is **not onboarded** → *stop that branch* and flag `needs-onboarding` (the
resolver cannot manufacture a repo). This yields a repo **path**; the clone **URL** (SSH or HTTPS) is
formed at fetch time (§2).

**The onboarding registry is primary**: the image
coordinate is a *deployment artifact*, not an address — its path segments **drift** from the real repo
across renames, migrations, and images that mirror no repo at all. The registry's
`(solution, item-type, name)` triple is the stable key. Do **not** derive the repo path by parsing an
image coordinate as the primary resolver.

### 1.1 Corroborate with the image coordinate (do not resolve from it)

The image coordinate carries `<image_registry_prefix>/<solution>/<item-type>/<name>` — the **same
triple**, self-contained. It is *more self-describing* than a bare name, so use it — as a **corroborator
of the registry result, never as a replacement**. Three concrete jobs:

- **Disambiguate a non-unique name.** When a bare name matches more than one registry entry (two
  solutions, or `components/` vs `assemblies/`), the coordinate's own `<solution>`/`<item-type>` segments
  pick the intended one — resolving what the name alone cannot.
- **Correct a misleading manifest name.** A helmfile *release/service name* can differ from the real
  component (a `fullnameOverride`): a deploy in solution `payments` names it `pm-graph` while the image
  path carries `…/shared/components/auto-models-graph` — the coordinate holds the true identity the
  release name hid, and it is **not even in this solution**.
- **Flag drift, never silently pick a side.** When the coordinate's derived path and the registry path
  **disagree**, the registry wins the resolution, and the divergence is recorded in a
  **`interface.source-repo/<member>`** annotation at `review: needs-review`. Use this exact grammar — a
  single line of `key=value;` tokens, in order:

  ```text
  interface.source-repo/<member>: "image-path=<path>;registry=<path>;review=<ok|needs-review|contradicted|needs-owner>"
  ```

  (`image-path` = the path the image coordinate derives to; `registry` = the canonical path the
  onboarding registry gives; an optional `note=<terse-token>` may precede `review`.) It is a real
  finding — a rename, a migration, or a phantom image — not noise to smooth over, and not free prose:
  the fixed grammar is what lets a later run compare and a validator check it. *(Schema note: this key
  currently validates only as a string.)*

To read a coordinate's triple you must know where the org path starts inside it: that anchor is
`image_registry_prefix` (an input), because the image host carries an extra namespace segment the git
host does not (`…/<image_registry_prefix>/<org_path_prefix>/…` vs `<git_host>/<org_path_prefix>/…`).

### 1.2 Why the coordinate cannot be the primary resolver

These members would be **misresolved** by coordinate-parsing, each of which the
registry resolved correctly:

| member | image path says | real repo | coordinate-primary outcome |
|---|---|---|---|
| `orders-connector` | `…/components/orders-connector` | `…/components/**integration**-orders-connector` | `git ls-remote` → **no such repo** → member lost entirely |
| `billing-engine` (pub) | `…/components/**legacy-invoicing-core**` | `…/components/billing-engine` | resolves to a renamed/wrong repo |
| `checkout-api` (pub) | `…/**storefront**/components/…` | `…/**payments**/components/…` | wrong `<solution>` segment → wrong path |
| `checkout-web` (pub) | `…/**storefront**/components/…` | `…/**payments**/components/…` | wrong `<solution>` segment → wrong path |

The `orders-connector` case is decisive: parsing the image path *"lands on nothing"*, while the
registry name `integration-orders-connector` resolves and fetches. The existence probe (§2, a
non-zero `git show`) still catches the non-existent path — but it converts a **resolvable** member into
an **unresolvable** one and loses its whole surface. Corroboration records the divergence and still
fetches via the registry; replacement does not.

### 1.3 The artifact-only fallback

Resolving a member **purely from its container coordinate** `<registry>:<tag>` (plus a `name → url`
registry map and OCI labels) is the **foreign / artifact-only** strategy — for a repo with **no git
access** via the convention. Prefer to have the **environment's governed resolver** (§1 precedence)
perform it — pass the container coordinate, take the worktree it returns — rather than parsing the
coordinate yourself. This is a *strategy* of last resort, **not** a preference over §1: on-estate the
registry + convention is the path, the coordinate only **corroborates** (§1.1), it never leads. (Where
no governed resolver is present, this artifact-only path is simply unavailable — degrade per §3–§4.)

## 2. Fetch — one bare `git show` (content + revision + existence)

Fetch a member IBOM with a bare, partial, shallow clone and a single blob read — no working tree:

```sh
# leaf / tip (default branch):
git clone --bare --depth 1 --filter=blob:none <url> repo.git
git --git-dir=repo.git show HEAD:catalog-info.yaml 2>/dev/null \
  || git --git-dir=repo.git show HEAD:catalog-info.yml

# revision-correct (member pinned at a SEMVER tag from the parent's manifest):
git clone --bare --depth 1 --filter=blob:none --branch <tag> <url> repo.git
git --git-dir=repo.git show <tag>:catalog-info.yaml 2>/dev/null \
  || git --git-dir=repo.git show <tag>:catalog-info.yml
git --git-dir=repo.git rev-parse HEAD           # → the fetched commit sha (for free)
```

- `--bare --filter=blob:none --depth 1` → tip commit + trees only, zero blobs. `git show <ref>:path`
  lazily faults in **one** blob; a **missing** path resolves against the local root tree → **no
  network** on the `.yaml`→`.yml` fallthrough. Exit is content-or-fail for free.
- **This one op triples as fetch + existence-probe + revision.** Non-zero (empty repo, or no IBOM
  path) = "uncatalogued" → route to degraded (§4). `rev-parse` yields the fetched sha with no extra
  call — which is why git beats a Files-API here (content + revision together).
- **Clone URL — match the developer's protocol and host.** The convention gives the repo *path*;
  `<url>` is either SSH `git@<git_host>:<path>.git` **or** HTTPS `https://<git_host>/<path>.git`
  (e.g. `git@<git_host>:…`). A dev machine is configured for **one protocol, not both** —
  so **derive both the scheme and the host from the current repo's origin** (`git remote get-url origin`
  → `git@…` vs `https://…`, and the host after it) and reuse them, so member clones inherit the same
  working auth (SSH key, or HTTPS credential helper / token). `git_host` is the **explicit input** for
  when origin is not a guide (a foreign steward standing the estate up fresh). **Do not** hard-code an
  `https://oauth2:$TOKEN@…` URL — it fails on an SSH-configured machine (and vice-versa).
- **Cleanup / prereqs:** `rm -rf repo.git` after each (each pack is ~1 tree + 1 blob + 1 commit;
  parallel-safe at N members). `--filter` needs `uploadpack.allowFilter` (default on; degrades to
  `--depth 1` bandwidth if off).

### Revision semantics — three revisions, not one
Three revisions are in play and are **not** interchangeable:

| fact | where it lives | question |
|---|---|---|
| **pinned** | the parent's deploy **manifest** (helmfile / image tag) | which revision does this parent deploy? |
| **fetched** | `git rev-parse` after clone | which revision did I actually read? |
| **checked-at** | `interface.discovery/checked-at` *inside* the member IBOM | which revision does the IBOM *claim* to describe? |

A member IBOM's `checked-at` cannot stand in for the other two: it is the *member's* revision (not
the parent's pin), and it is an assertion (a member that shipped code without re-running the skill
lags). So the **manifest pin chooses** the revision, `--branch <tag>` **fetches** it, and
`checked-at` **validates freshness**. Signals: `fetched ≠ pinned` → fetch landed wrong (tag missing);
`checked-at ≠ pinned` → the member IBOM is **stale** for this deployment → `review: needs-review`.
For a leaf / importable assembly (no pins) there is nothing to reconstruct — **HEAD + `checked-at`
is enough.** The pin is what distinguishes a **release** (reproduce what's deployed) from an
**assembly** (describe current state).

**Resolving a pinned *image* tag to a *git* revision.** A release pins **image** tags; fetching needs a
**git** revision. Most pipeline tags are also git tags (`v1.12.0` → use it directly). A **pre-release /
dev build tag usually embeds the commit sha** — `1.5.1-dev.3-f17533d0` → `f17533d0`;
`0.0.1-dev.20-379b4a70` → `379b4a70`. **Extract that sha and use it as the pinned revision** (expand it
to the full sha from the clone); do **not** give up on the pin. Only when **no** git revision can be
recovered at all is the pin `unresolvable` — and then the vendored slot is necessarily `stale=true`
with `review ∈ {needs-review, contradicted}` (§4.1).

## 3. Reference by default; vendor only when forced

Backstage is **one entity per thing, linked by refs** — a parent that **embeds** a member entity it
also references would **collide** on ingestion. So the everyday model is **reference** (the parent
carries the member ref; §2 fetches the real committed IBOM). **Vendoring** (a local copy of the
member's surface) is the **forced exception**, and only ever **non-ingested** (flattened onto the
parent's annotations, never a duplicate entity). Two forced cases: the **foreign export bundle** (a
boundary-crossing consumer with no resolver) and the **uncatalogued leaf** (§4). On-estate, prefer the
central `catalog_snapshot_path` (the estate-wide materialization) over per-parent vendoring.

**Every vendored surface is stamped absorbed-style — and the stamp goes on the *surface*, not the
entity.** A parent vendoring two members holds **two** copies from **two** sources, so a single
entity-level `interface.absorbed/source` (one key per entity) **cannot express it**. The per-surface
stamp is the candidate lane's fourth key:

```text
interface.provides/candidate/<surface>: provenance=…;confidence=…;review=…;absorbed=<member-ref>@<fetched-sha>
```

with the **slot** carrying `provenance ∈ {manifest,guessed}` (the parent's derivation) while each
vendored **fact** keeps its own true tier. Reserve `interface.absorbed/source` for a copy that has
earned a real `API` entity. **Every `interface.vendored/<member>` slot must be named by at least one
`absorbed=`** — a vendored member contributing no declared surface is a *silent absorption*, and fails
`references/ledger-validation.md` C9c.

## 4. Degraded mode — holes, and recovery

When a member IBOM is **unreadable** the parent degrades — but the clone result splits the case, and
the split decides the **recommended** recovery:

- **Reachable but uncatalogued** — the clone **succeeds**, the repo exists, but it carries no
  `catalog-info.yaml`. **Vendoring is the recommended default here** (§4.1): clone is already in hand,
  so run the skill on it and flatten the real surface. A hole leaves the release's surface *unknown*;
  vendoring makes it *known now*. *Waiting* is not a substitute: it depends on the child publishing on
  a timeline the parent cannot force (§4.3).
- **Unreachable** — the clone **fails** (no repo, no auth, no network). **A hole is forced** — there is
  nothing to vendor. Flag `needs-review` ("member unreachable").

Either way, record a **degradation-point hole first**, **never** a fabricated surface, and **fully
federate the members it *can* read** (partial, "M of N"). A reachable-uncatalogued hole is the
*recommended candidate for immediate vendoring*; an unreachable one *rests* until the member is
reachable. Holes are tracked, not guessed:

```
interface.members: component:default/payments-api,component:default/inventory-svc,component:default/shipping-svc
interface.federation: 1/3                                  # slots FILLED (vendored + referenced)
interface.federation/mode: vendored                        # vendored | referenced | mixed
interface.federation/referenced: 0/3                       # filled from the child's OWN committed IBOM
interface.federation/stale: 1/3                            # vendored slots whose source ≠ the pinned tag
interface.federation/degraded: inventory-svc@v2.1.0,shipping-svc@v1.2.0   # the remaining holes
```

`interface.members` = the whole composition; `interface.federation/degraded` = the subset that is a
hole (ref + pinned tag).

**The counters are not interchangeable.** `interface.federation` counts slots **filled**; only
`…/referenced` counts slots **truly federated** from the child's own committed IBOM. A parent that has
vendored every member reads `11/11` while `…/referenced: 0/11` — **`interface.federation` is not a
federation claim.** `…/stale` counts vendored slots whose source revision differs from the pinned tag
(§4.1). `…/mode` ∈ `{vendored, referenced, mixed}` and must agree with the counts.

**Do not infer the child's internals from the parent's manifests** — a
guessed name (`payments-api-http-api`) that the real IBOM later renames (`payments-api-settlement-events`)
would force a retract-a-guess; a hole has **nothing wrong to retract**, so recovery is pure fill-in.
A degraded child's edge stays a **candidate / annotation, never a live edge** (no dangling ref). The
degraded parent is structurally schema-valid, committable, and pushable — its
`interface.federation/degraded` list is the honest record of what is unfederated, and the scope the
parent may later **self-heal** by vendoring (§4.1). It is **not** a task list for the child's owners.

### 4.1 Recovery lifecycle — three states per ref
Each member is a **slot keyed by its ref**, stored as status (+ surface, once it has one) on the
**parent's annotations** — never a duplicate entity. The stable ref key makes every transition
deterministic (find-by-ref). A **vendored slot** is one line of `key=value;` tokens:

```
interface.vendored/<member>: "source=<ref>@<fetched-sha>;pinned=<tag-or-sha>;provenance=…;confidence=…;review=…;stale=<true|false>"
```

- **`source`** = the **fetched commit sha** (`git rev-parse HEAD` on the clone) — *ground truth of what
  was actually read*, not the tag echoed back. Recording the tag makes `stale` compare a tag to itself,
  which is tautological and cannot catch "recorded the pin without fetching it."
- **`pinned`** = the revision this parent deploys (the tag, or the sha it resolves to; `unresolvable`
  only as a last resort — §2).
- **`stale=true`** **iff** the fetched sha differs from the revision `pinned` **resolves to** (resolve
  the tag → sha before comparing; never compare a sha to a tag textually).

- **hole (degraded)** — ref + pinned tag + status; **no internals**. The **forced** state when the member
  is **unreachable**; and the transient first state for a reachable-uncatalogued member on its way to
  **vendored** (which is the recommended next step, not a resting place — §4).
- **vendored** — the human recovered it: **clone the child at the parent's pinned tag**
  (`git clone --depth 1 --branch <pinned-tag>`), **run this skill on that checkout, and flatten the
  generated surface into the parent** (a local copy, *not* pushed to the child).
  **Vendor at the pinned tag, never HEAD** — a release must describe what it *deploys*; a HEAD-derived
  surface is **born stale** and describes a commit no cluster runs. Fall back to HEAD **only** when the
  tag is absent from the repo, and stamp `stale=true`. When environments pin **different** revisions,
  vendor **once per distinct pin** (not once per environment). Stamped `absorbed/source:
  <ref>@<immutable-ref>`. The **slot** carries `provenance: guessed|manifest` (it is the parent's
  derivation), while each vendored **fact** carries its **own true source tier** — a `.proto`/OpenAPI/DDL
  read from the child is `provenance: contract`, code-derived is `code`. Carries the child's internals as
  a transient guess; **inherits the child's own degradation depth** (its sub-members come back as holes).
  It is **durable committed state** (see §4.2).
- **referenced (graduated)** — the child published its **own** IBOM; the parent **deletes the
  vendored slot and references the remote**. Single source of truth.

Precedence is **reference → vendor → hole**: a member that **has** an IBOM is **referenced** (best); a
member that is **reachable and has no IBOM** is **vendored** (the recommended default); a member that
is **unreachable** rests as a **hole**.
So `hole → vendored → referenced` is the recommended path for a **reachable, uncatalogued** member;
`hole → referenced` (patient) is the fallback when the member is unreachable or the human declines. Only the middle state carries internals. **Recommending
vendoring does not make it automatic** — it is still a confirmed, human-in-the-loop act (surfaced as
`vendor-now (recommended)` vs `accept-degraded`), and the recursion stays **lazy**: vendoring reads the
member **one level**, so its own sub-members come back as holes (§5), never an auto-descent.

### 4.2 Graduation is free; vendored is durable
Every parent run already does §1 resolve → §2 fetch per ref — and **that fetch is the graduation
check**: fetch succeeds → **referenced** (delete any vendored copy for that ref); fetch fails → keep
the **hole**, or keep the **vendored** copy if one was recovered. No watcher, deterministic by ref.
**Vendored content is durable** committed state: a normal re-run does only the cheap fetch, **not** a
re-clone/regenerate — refreshing a vendored copy is a deliberate **re-recovery**.

### 4.3 Cross-parent consistency — self-heal and wait; never reach across the boundary
A vendored copy heals the **parent**, not the estate (two parents can vendor divergent guesses of the
same child). **The parent never reaches across the boundary:** it does **not** author the child's IBOM,
and it does **not** ask, request, or task the child to publish one. It **self-heals and waits.**

The cure arrives on the **child's own timeline**: when the child eventually graduates (publishes its own
owner-reviewed IBOM), every parent's next fetch **detects** it and converges (§4.2). **Graduation is
detected, never solicited.** Until then cross-parent divergence is **tolerated** — the vendored copies
are transient, low-provenance, and superseded automatically.

### 4.4 Recovery guards
- **Reference at the pinned tag on graduation**, not HEAD; `checked-at ≠ pinned` → stale → `needs-review`.
- **Human-touched vendored content → flag, never silent-delete** on graduation (`review: needs-review`).
- **A vendored copy can go stale before graduating** (child ships code, no own IBOM yet) — the
  `absorbed/source: <ref>@<rev>` stamp catches it (vendored rev vs current pinned tag) → flag +
  suggest re-recovery. Not auto-fixed.
- **Partial recovery is normal** — mix of hole/vendored/referenced; rollup precedence + worst-of
  confidence keep the parent honestly `needs-review`/`low`. Expose a count (`interface.federation: 7/19`).
- **Contradictions escalate** — a graduated child whose real names don't match the manifest
  (mis-cataloged / mis-seeded repo) → `contradicted`. Surface it.

## 5. Recursion & orchestration

Composing a top-level IBOM is a **post-order DFS** over a **variable-depth** tree: a release composes
members that may be **components directly** (helm charts shipped from the component repo) **or**
assemblies **or** both — **the assembly layer is optional** — and a `Domain`, if any, wraps the release
Systems. A parent can only reduce after its children have IBOMs. Each node bottoms out in **has IBOM**
(read), **onboarded / no IBOM** (degrade → recover, §4), or **not onboarded** (stop + flag).

- **Never fabricate; recommend vendoring; stay one level.** On a missing member, **do not** invent a
  surface — record a **hole** first. Then, if the member is **reachable and has no IBOM to reference**,
  the **recommended** recovery is to **vendor** it (§4 / §4.1) — the default the human confirms, because a
  hole leaves the surface unknown. (A
  member that *has* an IBOM is **referenced**, not vendored.) Self-healing is still a
  deliberate, human-in-the-loop act — one ref at a time, or an all-in-one DFS sweep of every degraded
  ref — and it reads each member **one shallow level** (its sub-members degrade to holes, recovered on a
  later run). **Never task the child** (§4.3); never auto-descend the whole tree in one run.
- **No orchestrator today → the human is the orchestrator.** A release run over all-uncatalogued
  members records every ref as a hole; the human may then **self-heal by vendoring** (member-by-member
  or DFS) and re-run the parent, which converges as each child graduates **on its own timeline**.
  **Lazy is what makes this safe** — each run stays one shallow
  level (read-or-degrade, never generate-recurse), so no single run gets lost; the recursion is
  spread across many shallow runs instead of one deep automated one.
- If ever driven by an orchestrator: keep the traversal **sequential** (this skill mutates git
  branch/working state — concurrent runs collide) or, at most, parallel across **isolated-worktree
  siblings with a barrier at the parent**; the orchestrator (not the agent) holds the stack, with
  **revision-keyed memoization** (`repo@revision` — same repo at two pins = two nodes), cycle
  detection, and bounded depth **logging what it truncated**.

## 6. Construct from deployment (judgement, not the registry)

Kind comes from **what is deployed**, not the registry's filing (§0). At the release stage the
**certain** deliverable is the **boundary API surface** — the interfaces the environment makes
available (ingress/gateway routes → HTTP/gRPC APIs and UIs; published event streams) plus its
outward egress — readable from deploy config (ingress, gateway, mesh, netpol) **without** deep
federation. Internal decomposition and Domain boundaries are the uncertain, judgement-heavy part;
**anchor on the boundary surface, treat the rest as optional deepening** (the `compose.md`
federate→reduce is that deepening).

Defaults:
- **component → `Component`** (build unit).
- **assembly → `System`** — build-time composition/reuse; internal structure lives here. **Optional**:
  present only when there is a real reuse layer (e.g. a `<component>-helm` chart shared across releases);
  absent when a release pulls a component's helm chart directly.
- **release → `System`, one per environment (strictly)** — carries *that environment's* runtime
  boundary API surface. It composes **components directly and/or assemblies** (the assembly layer is
  optional): a *reused* chart factors into an assembly; a one-off component chart needs none. A solution
  deployed to dev/pub/demo = three release Systems, each with its own surface.
- **`Domain` → opt-in only, default off; never inferred.**

**Domain wraps, never replaces.** When opted in, a `Domain` **wraps** the System(s) — never
converts/replaces one, **even 1-1** (`Domain: payments` *contains* `System: payments`, not
instead-of). **Interfaces always live on the `System`** (the stable interface-set home); the
**`Domain` carries no interfaces** — it is pure grouping. This keeps the interface-set ↔ domain-set
mapping clean and keeps composition-drift sane: opting a Domain in/out only re-parents Systems, never
migrates interfaces. (It also dissolves any same-name concern — `Domain:X` + `System:X` is the
intended wrap.)

Naming across the three: **entity/repo name** from the registry (a reference); **interface names**
from the members' real committed contracts; **kind** from judgement.

## 7. Linkage — a repo's own first-party library dependencies

*Members are what a construct **deploys** (§1–§6); linkage is what it **builds against**. Only a
**first-party** library — one that resolves to an org repo — is an interface; a third-party package is
SBOM, not an edge (SKILL.md *False-positive suppressions*). Terminology: this is **linkage**, not to be
confused with composition (members) or `spec.dependsOn` (an operational Resource).*

A build-manifest dependency (`pom.xml` / `Cargo.toml` / `package.json` / `go.mod` / Helm `dependencies:`)
that resolves to a first-party repo is a **linkage** edge — a consumed interface. Record it as an
`interface.consumes/candidate/<lib>` (parked until it has an entity); a **vendored/bundled** copy is an
**absorbed** twin (SKILL.md *Absorptions*), not a candidate. The library's contract identity is its
**coordinate** (`lib@version`), which is enough to build the graph; its real public-API surface is a
separate, later concern.

**Resolve `name → repo` — governed resolver first (§1 precedence), then a ladder INVERTED from a
member (§1):**
0. **The environment's governed resolver (§1 precedence), when present** — pass the **package
   coordinate** (`maven` / `npm` / `pypi`; e.g. `<group>:<artifact>:<version>`) and take the worktree it
   returns. Do not clone or compute a path yourself.
1. **A `name → url` registry map — primary self-contained resolver.** The environment's / the scanned
   repo's own map — a committed `references/repos.yaml` **in the repo under test**, or equivalent; it is
   **not** a file shipped with this skill, and if none exists, skip to (2). Libraries live *outside* the
   `<org_path_prefix>/<solution>/components/<name>` convention — shared libs sit in other namespaces
   (e.g. `.../assemblies/shared-charts/<lib>`) — so where a map exists it is the only reliable resolver.
   An entry with **no `artifacts:` coordinate** is a source-only reference (a **library**); an entry
   **with** a container coordinate is a deployable **component**.
2. **Onboarding registry + convention — secondary.** An *in-solution* library
   (`<solution>/components/<lib>`) resolves member-style (§1).
3. **Package self-metadata — last resort, always flagged.** POM `<scm>` / npm-`cargo` `repository`, used
   only when present, recorded `interface.source-repo/<lib>: "…;review=needs-review"` — often absent; never
   lead with it. Name↔repo divergence (an artifactId unlike the repo name) is the `orders-connector`
   alias hazard: the map wins, the divergence is recorded via `interface.source-repo` at `needs-review`.

**Then reuse the engine unchanged:** §2 fetch (bare `git show <version>:catalog-info.yaml`), the §3–§4
`reference → vendor → hole` recovery, and absorbed stamping for a vendored copy — all identical to a
member.

**Traverse full-depth to the org frontier** — the *opposite* of composition's lazy one-level (§5), and
safe because it is **bounded by the org**: recurse into every first-party linkage edge; **stop at the
first third-party coordinate** (not resolvable to an org repo → record as external / SBOM, do **not**
follow). Use **revision-keyed memoization** (a diamond visits a node once) and **cycle detection** (a
first-party cycle is itself a finding). The **same library at two versions via two paths** is a **twin
finding** — record both edges and flag it; never collapse to one (a package resolver's nearest-wins would
throw the finding away).
