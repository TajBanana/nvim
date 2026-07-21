---
name: maintain-ibom
type: skill
tags: [interfaces, ibom, discovery, backstage]
description: Use when creating or maintaining the Interface BOM (IBOM) for a repository — captures the engineer's partial system view, discovers what the repo provides, consumes, implements, and absorbs, reconciles those against the existing catalog, and maintains a single committed reconciliation ledger (catalog-info.yaml) of review-safe facts, with ephemeral per-run review sidecars.
argument-hint: "[optional: path to another repo; defaults to the current repo]"
version: 4.9.15
compatibility: [copilot, claude]
---

## Purpose

Extract the meaningful interfaces, dependencies, conformance contracts, and system relationships in
a Git repository, then emit Backstage-compatible catalog declarations. Four relationship classes:

1. **implements** — the repo or an artifact conforms to a protocol, standard, packaging/platform/
   runtime contract, schema, or interface spec.
2. **provides** — the repo exposes an interface others call, subscribe to, consume, install, deploy,
   import, or depend on.
3. **consumes** — the repo calls, subscribes to, imports, deploys to, or otherwise uses an interface
   provided elsewhere.
4. **absorbs** — the repo holds a **constraint-forced local copy** of an interface owned elsewhere (a
   twin — e.g. an offline cache, a vendored contract kept because the owner cannot be reached live).

Output is a Backstage `catalog-info.yaml` (multi-document YAML). Use native Backstage fields
wherever possible; use custom `interface.*` annotations for non-native conformance and absorption.

**Scope.** This skill covers **software interfaces discoverable in a git repository** — the surfaces
present in an application / service / library / deployment repo, from in-process code up through
service, data, identity, and packaging boundaries. **Out of scope by construction** (not
repo-discoverable): systems-engineering and physical interfaces (hardware buses, device drivers,
industrial / RF, formal ICDs) and human / organizational interfaces (SLAs, team boundaries). Within
scope, represent *every* surface (see the breadth rule in *Backstage mapping rules*), not only the
four Backstage-native API types.

The engineer using this skill has a **partial** view of the system — possibly incomplete,
non-technical, stale, or wrong. It is still a required input: it captures the actual operating model.

## How to read this skill

This SKILL.md is the operating procedure and the **policy** — read it in full. It assumes you
**already know standard ecosystem knowledge**: how to read a Maven/Gradle/Cargo/npm/Go/Python
project, where OpenAPI/AsyncAPI/proto/GraphQL definitions live, and common web/RPC/messaging
frameworks. It does **not** re-teach those. It covers only what is specific to **this org** and to
the **reconciliation-ledger model**.

**Self-contained:** this skill is `SKILL.md` + the `references/` folder and **nothing else** — it must
not reference any file outside this package (repo theory docs, invariant numbers, sibling skills), so
it travels intact when copied into any repo. State a principle inline; never cite an external doc.

Load-on-demand detail lives beside this file in `references/` — read the relevant one at the moment
you need it:

- `references/backstage-entities.md` — Component / API / Resource templates, `$text` rules,
  directionality examples, dedup keys, naming detail. **Read before emitting entities.**
- `references/sidecar-schemas.md` — the three ephemeral `.backstage/` schemas + human-claim
  normalization. **Read before writing sidecars.**
- `references/interface-taxonomy.md` — approved `implements` identifiers + controlled-registry shape.
- `references/example-run.md` — a full worked PR-assist run.
- `references/ledger-validation.md` — the machine-checkable ledger rules (the *spec*).
- `references/validator.md` — the **runnable** semantic rules: POSIX `awk` blocks, nothing to install.
  **Read and run it at Step 8** (mandatory).
- `references/catalog-info.schema.json` — the **structural JSON Schema** for a `catalog-info.yaml`
  entity (Component / System / Resource / API) + its ledger annotations — the machine form of the
  output contract (consumed by runtime / CI).
- `references/compose.md` — assembly/release roll-up: the federate→reduce algorithm over members.
- `references/dependency-management.md` — resolving a parent's **member** dependencies into their
  IBOMs: registry→repo resolution, bare-clone fetch, revision semantics, degraded-mode holes +
  recovery, construct-from-deployment. **Read with `compose.md` for an assembly/release.** Also §7 —
  **linkage** (a repo's own first-party library dependencies) — read when a repo builds against org libraries.
- `references/org-config.yaml` — the estate anchors: the **ONE file an adopting org edits**. An
  explicit run input overrides it.

## Core principles

1. **Human partial view is first-class input** — captured *before* deep scanning, as data. Do not
   discard it for being non-technical; do not blindly commit it as catalog truth.
2. **Keep three layers separate** — *human-declared* (what the engineer believes), *repo-evidenced*
   (what manifests/code/specs/CI show), *catalog-committed* (reviewed graph facts). Mismatches
   between them are useful architecture signals; never collapse them.
3. **Optimize for false-negative tolerance over false-positive pollution.** A missing relationship
   is usually tolerable; a wrong one corrupts the architecture/ownership/API graph at scale. The
   committed catalog contains only facts that meet the commit policy.
4. **Preserve useful uncertainty explicitly** — do not hide it by inventing owners, systems, API
   names, or directionality. Park it in the candidate lane with `review: needs-*` and raise a
   blocking question when a claim is plausible but unsafe to commit.
5. **Backstage-native relations before custom annotations** — `spec.owner/system/providesApis/
   consumesApis/dependsOn/subcomponentOf` for native semantics; `interface.*` only for conformance
   and absorbed twins Backstage does not model.
6. **Deterministic evidence first** — reference a formal spec file or run an extractor before
   summarizing source by hand. LLM inference is the gated fallback (see *Discovery*).
7. **Mirror exactly what is confirmed** — everything uncertain stays out of the graph, parked in the
   ledger's candidate lane and `review` tokens until confirmed.
8. **Concurrent, git-tracked lifecycle** — `catalog-info.yaml` is edited by many devs over time (the
   `.backstage/` sidecars are ephemeral and gitignored). Be merge-friendly: update entries in place,
   never clobber concurrent edits, preserve annotations you did not set (including another dev's
   pinned `interface.discovery/tool`), treat git/PR review as the coordination surface.

## Organization givens

Hold across this org; use as defaults and evidence hints. A repo may diverge — corroborate and lower
confidence on divergence.

- **CI is GitLab (`.gitlab-ci.yml`).** Read it first among CI files: best evidence of what the
  pipeline **builds/publishes** (release artifacts → `implements` such as `standard:oci-image`,
  `platform:kubernetes-helm-chart`) and whether it **deploys** (→ `production` lifecycle).
- **Versioning is SEMVER, driven by git tags.** Pipelines create the tags; the repo carries the tag
  history — the version source of truth. **Suggest** an `interface.version` from how the interface
  *itself* evolved (diff the contract vs its previous version — additive ⇒ minor, breaking ⇒ major)
  **reconciled with** the latest SEMVER tag; the engineer confirms. If interface version **diverges**
  from the repo's tag, raise a blocking question and mark the field `review: needs-review`.
- **Deployment is Azure AKS + Helm + Kubernetes (Ingress) + Terraform.** For `implements` use
  `platform:kubernetes-helm-chart`, `platform:kubernetes-ingress`, `platform:kubernetes-manifest`,
  `platform:terraform-module`. **There is no Gateway API** — never emit
  `platform:kubernetes-gateway-api`. CloudFormation/serverless only if a repo genuinely contains them.
- **CI helpers** may be `Makefile` or `Taskfile.yml` (no Jenkins/buildkite/skaffold/Earthfile).
- **Every repo has a `CODEOWNERS`** — the ownership source; `spec.owner` derives from it at
  provenance `human`. If **missing, do not enforce and do not infer owners from committers** — draft
  it with the engineer (they supply the owners; the AI scaffolds **minimally — a single `* <owner>`
  unless the engineer gives finer path ownership; never fabricate per-path rules**). **Drafting and
  committing it in-run from the supplied owners satisfies the gate** — then proceed with
  `provenance/owner: human`. Only when no owner is available at all do entities stay
  `review: needs-owner`.

## Discovery — repo-native tooling (primary) → AI scanning (fallback)

Produce the **repo-evidenced view** with the **repo's own toolchain**, not shipped or OS-native
binaries. Record the mode and exact tool on each claim.

- **Primary (`mode: native`).** Detect the ecosystem per component root from its manifests and use
  the repo's own build tool and interface configs (you know these). Where a formal contract file
  exists (OpenAPI / AsyncAPI / `.proto` / GraphQL SDL / `values.schema.json`), reference it directly;
  where it is defined in code or needs validating, run the repo's native tool or its native local
  runner (`mvn spring-boot:run`, `npm start`) and introspect a served `/openapi` / reflection.
- **On-demand extension, from a trusted, version-pinned source.** When a validator/extractor isn't
  present, bootstrap it through a trusted, **exact-version-pinned** front door — the ecosystem package
  manager (`npx <pkg>@<version>`, `uv run`/`pipx run <pkg>==<version>`, a Maven/Gradle plugin, `cargo …`,
  `go run`), **or a first-class ecosystem CLI pinned to an exact version** (e.g. `buf@1.47` for protobuf,
  the way `redocly` is for OpenAPI). What is **forbidden** is an **unpinned or OS-package-manager binary**
  (whatever `apt`/`brew`/`PATH` happens to give) — that reintroduces the supply-chain + drift risk the pin
  exists to remove. The test is *trusted-source + exact pin*, not *binary vs. not*.
- **Pinning lives in `catalog-info.yaml` annotations.** No shipped tools, no separate manifest — the
  catalog is the only pin. Record the exact pinned tool in `interface.discovery/tool` (e.g.
  `npx @redocly/cli@1.34.0`, `buf@1.47`); on re-run, re-use it. Always pin the version — a bare
  `npx <pkg>` pulls latest and reintroduces drift.
- **Offline / foreign checkouts.** Bootstrapping needs network. Prefer tools the repo already vendors
  or locks; if none and no network, drop to AI scanning flagged low-confidence — do not fail.
- **Side-effects.** Prefer read-only extraction (`buf build`, `helm template`, spec validation) over
  full builds; do not run arbitrary lifecycle scripts.
- **Secondary (`mode: ai`).** Only when no native path exists: read manifests / well-defined schemas
  / source and infer. Confidence at most `medium` (usually `low`); raise a finding to make the
  interface tool-extractable. `ai` is never terminal — see reconciliation rule 2.

The extraction *path* varies per repo; the IBOM *output shape* stays uniform.

## Inputs

Operates on the **current repository** (git root of the working directory); no repo path needed.

**Required — `human_system_view`:** the engineer's partial understanding. If not provided, ask
before deep scanning (short/informal answers are fine). Recommended prompt:

```text
Give your current working understanding of this repo. It can be incomplete, non-technical, or wrong.
1. What do people call this repo/component?
2. What system, product area, or business capability do you believe it belongs to?
3. Who do you believe owns it?
4. What does it provide to other teams, systems, users, or deployers?
5. What does it consume from other teams, systems, platforms, or vendors?
6. What runs in production, if anything?
7. What are you unsure about?
8. Are there names, ownership boundaries, or dependencies that people disagree on?
```

Do not require Backstage terminology; translate to structured claims later.

**Optional inputs (use when present):** `repo_url`, `revision`, `namespace` (default `default`),
`default_owner`, `default_lifecycle` (default `experimental`), `default_system` (only if org permits),
`org_path_prefix` (repo-path anchor), `git_host` (clone host), `image_registry_prefix` (where the org
path starts inside an image coordinate) — shipped defaults for all three live in
`references/org-config.yaml`; **precedence: an explicit input here > `references/org-config.yaml` >
ask (never guess)**. **The three make member resolution portable; nothing binds to our
infrastructure** (an interface hard-coded to our infra is exactly what this skill flags in the repos
it scans, so it must not hard-code its own),
`catalog_snapshot_path` (exported existing entities), `catalog_policy_path`, `interface_registry_path`,
`owner_registry_path`, `system_registry_path`, `visibility_taxonomy`, `existing_catalog_policy`
(`preserve|merge|replace`, default `merge`), `new_entity_policy` (`forbid|allow-with-owner-review|
allow`, default `allow-with-owner-review`), `monorepo_policy` (`single-component|multi-component|
detect`, default `detect`), `strict_mode` (default `true`), `schema_ref` (path or URL to the structural schema; when
set, the emitted ledger carries a `# yaml-language-server: $schema=<schema_ref>` modeline +
`interface.ledger/schema` echo — unset ⇒ rely on the environment's editor schema association, no
in-file path), `catalog_ignore_path`. Without a snapshot
or registries you may still produce local candidates, but must not invent global-looking systems,
owners, or external APIs without marking them for review.

## Repository files and commit policy

In PR-assist mode, create or update:

```text
catalog-info.yaml                            # committed — the only durable, ingested artifact
.backstage/human-system-view.yaml            # ephemeral — gitignored, per-run review aid
.backstage/interface-discovery-report.yaml   # ephemeral — gitignored, per-run review aid
.backstage/catalog-questions.yaml            # ephemeral — gitignored, per-run review aid
```

**Only `catalog-info.yaml` is committed** — Backstage ingests it. The three `.backstage/` sidecars
are **ephemeral**: generated per run as a local review aid and **never committed**. **Before writing
them, guarantee they cannot be checked in:** if `.backstage/` is not already ignored, add a
`.backstage/` entry to the target repo's `.gitignore` (creating `.gitignore` if it does not exist),
and never `git add` the sidecars. They hold the human view, evidence, and open questions for the
*current* review only; they are not a persistent audit trail. Do not create any other committed file
(e.g. a decision log) — the human-facing summary is printed, not committed.

## Output modes

1. **PR-assist mode** (default) — generate `catalog-info.yaml`, the three sidecars, and a PR impact
   summary.
2. **Catalog-only mode** — return only `catalog-info.yaml` (all required claims confirmed or policy
   allows unresolved fields).
3. **Report-only mode** — return findings, questions, reconciliation; write no ingestible YAML.

When the user asks for the Backstage declaration only, return only `catalog-info.yaml`. For
scale-safe adoption or AI-assisted onboarding, use PR-assist mode.

## Provenance ladder and reconciliation ledger

`catalog-info.yaml` is a **reconciliation ledger**: every value carries where it came from and how
sure we are, as terse tokens — no prose (rationale lives in the PR). Each run reconverges it.

**Provenance ladder** (high → low). Every committed value is stamped `interface.provenance` (and
`interface.provenance/<field>` where a field's source differs):

| tier       | value from…                                                                         |
|------------|-------------------------------------------------------------------------------------|
| `human`    | a person — `CODEOWNERS`, or the engineer/approver on this codebase                  |
| `registry` | a governed org registry (owner / system / interface)                                |
| `contract` | the interface definition file (OpenAPI / AsyncAPI / proto / GraphQL / JSON-Schema / DDL)  |
| `manifest` | release-artifact & deployment manifests (Helm / K8s / Terraform / `.gitlab-ci.yml`) |
| `code`     | source code (routes, client config, in-code annotations)                            |
| `docs`     | documentation                                                                       |
| `guessed`  | naming / repo / package inference                                                   |

**Ledger annotations** (committed; tokens only):

| annotation                                                     | values                                                                                                                                                                      |
|----------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `interface.provenance` (+ `…/<field>`)                         | ladder tier above                                                                                                                                                           |
| `interface.discovery/mode`                                     | `native` \| `ai`                                                                                                                                                            |
| `interface.discovery/confidence`                               | `high` \| `medium` \| `low` (recomputed every run)                                                                                                                          |
| `interface.discovery/tool`                                     | pin ref, e.g. `buf@1.47`                                                                                                                                                    |
| `interface.discovery/checked-at`                               | a **concrete, immutable** git ref the value was last reconciled at — **prefer the SEMVER tag**, else a commit sha; **never a symbolic ref** (`HEAD`, a branch), which moves |
| `interface.version`                                            | semver (suggested)                                                                                                                                                          |
| `interface.review`                                             | `ok` \| `needs-review` \| `contradicted` \| `needs-owner` — **rollup: `ok` only if no field / candidate / open question remains** (see rule 5)                              |
| `interface.review/fields`                                      | token list, e.g. `system,owner`                                                                                                                                             |
| `interface.review/ref`                                         | **durable** ref only — MR / Jira id or commit sha; never a sidecar question id; omit if none exists yet                                                                     |
| `interface.consumes/candidate`, `interface.provides/candidate` | evidenced-but-unconfirmed relations, parked; **never** emitted as `consumesApis`/`providesApis`                                                                             |
| `interface.members` (assembly/release only) | member entity refs an assembly / release `System` composes — the *composition* axis, distinct from a member's own `spec.system` |
| `interface.federation/degraded` (assembly/release only) | comma list of unreadable-member **holes**, each `<ref>@<tag>`; recovered per `references/dependency-management.md` §4 |
| `interface.federation` (assembly/release only) | completeness `M/N` — slots **filled** (vendored + referenced), `M ≤ N`, `N` = member count. **Not** a federation claim (a fully-vendored parent reads `N/N`) |
| `interface.federation/referenced` (assembly/release only) | `R/N` — slots filled from the child's **own committed IBOM**; the *only* real federation claim |
| `interface.federation/stale` (assembly/release only) | `S/N` — vendored slots whose fetched revision ≠ the pinned tag |
| `interface.federation/mode` (assembly/release only) | `vendored` \| `referenced` \| `mixed` |
| `interface.vendored/<member>` (assembly/release only) | a filled slot, single line: `source=<ref>@<fetched-sha>;pinned=<tag-or-sha>;provenance=…;confidence=…;review=…;stale=<bool>` |

**Authority.** Do **not** consult remote PR / merge state. The **committed `catalog-info.yaml` on the
current checkout is the baseline of record**, and the **human working on this codebase is the final
approver**. Any change lands as a **new commit** (also how remote-PR comments get addressed).

**Reconciliation rules** (each run):

1. **Precedence — lower never clobbers higher.** Overwrite a field only with an **equal-or-higher
   `provenance`** tier. Lower-tier evidence that *disagrees* sets `review: contradicted` and **leaves
   the value**. `human` is sticky. A field's tier *rises* as better evidence appears
   (`guessed` → `contract`).
2. **Mode preference — `ai` is never terminal.** Prefer `native`; **re-attempt `native`** for any
   `ai` entry every run and upgrade it (value + `mode: native` + recomputed confidence). **Incremental
   skip only when** `mode: native` **and** `review: ok` **and** the entry's source files are unchanged
   since `checked-at` (git diff). `ai` entries are always re-attempted.
3. **Confidence is live** — recomputed each run from current evidence × mode; a drop or a
   contradiction sets `review: needs-review`.
4. **`checked-at`** is stamped at each reconcile with a **concrete immutable ref** (SEMVER tag
   preferred, else a commit sha — **never `HEAD` or a branch**, which move) — the baseline for drift
   detection and the skip check. Also record `interface.version` from the resolved tag.
5. **`review` is a rollup — `ok` means nothing is open.** The entity-level `interface.review` is the
   **most-blocking** state among its fields (`review/fields`), its candidate-lane entries, and any
   open blocking question. **Precedence (most→least blocking): `contradicted` > `needs-owner` >
   `needs-review` > `ok`** — the entity takes the top open state (e.g. a Component over three
   `needs-owner` candidates reads `needs-owner`, not the vaguer `needs-review`). Emit `ok` **only**
   when every field is reconciled, no candidate is parked, and no blocking question is open.
6. **Confidence aggregates worst-of.** An entity's `interface.discovery/confidence` is the
   **minimum** confidence among its committed conformances/relations (a `System`/`Domain`'s is the min
   across the composed member facts). Never report `high` over a `medium` fact.

Only `catalog-info.yaml` persists this ledger. The `.backstage/` sidecars are ephemeral render for
the PR view; the durable memory is the annotations above.

**Candidate lane.** A relation that is *evidenced but not commit-safe* — e.g. a consumed backend with
no catalog entity, owner, or contract yet — must be neither invented as a graph edge (`consumesApis`
/ `providesApis`) nor dropped. Park it: `interface.consumes/candidate` / `interface.provides/candidate`
holds a comma list of candidate names, each detailed in
`interface.consumes/candidate/<name>: "provenance=…;confidence=…;review=…"` — a **single line** of
`key=value;` tokens (**those three keys, plus one optional fourth — `absorbed=` — and nothing else**;
no multi-line block scalars, no free-text `notes` in the committed value — notes belong in the
ephemeral sidecar). Backstage ignores these annotations, so they never pollute the graph.

**A vendored surface is a candidate that MUST also declare its origin.** When a surface was recovered
by **vendoring** a member (§Compose) — or is an **absorbed twin** (§Absorptions) — append the fourth
key naming the member it was copied from and the revision it was read at:

```text
interface.provides/candidate/as-hotspot-graphql: provenance=contract;confidence=high;review=needs-review;absorbed=component:default/as-hotspot@811d05d6cfaea5925dd7e3c5257bbde2bbcaa905
```

`<rev>` is the **fetched commit sha** — the same one in that member's `interface.vendored/<member>`
slot, not the tag echoed back. **This is not optional for a copy.** The candidate lane is where a
vendored surface *lands* (it has no owner or entity yet, so it cannot become an `API`), but it is
**not an escape from declaration**: without `absorbed=`, a copy of someone else's contract is
indistinguishable from a surface you derived yourself — an **undeclared absorption**, and a silent
twin. Every `interface.vendored/<member>` slot must be named by at least one `absorbed=`; a vendored
member that contributes no declared surface is a validation failure (`references/ledger-validation.md`
C9). Use `interface.absorbed/source` **only** when the copy has earned a real `API` entity. Each run re-checks candidates and **promotes** one to a real edge the
moment a matching entity exists (owner + contract), raising its provenance — or drops it when the
evidence is gone. Because the rationale (`prose → PR`) does not survive the merge, put a durable
back-reference in `interface.review/ref` (a durable MR / Jira id or commit sha — never a sidecar
question id; omit if none exists yet) so the "why" is one hop away.

## Backstage mapping rules

Entity templates, `$text` substitution, directionality examples, dedup keys, and naming detail are in
`references/backstage-entities.md` — **read it before emitting entities.** The load-bearing rules:

- **Component:** `spec.owner` and `spec.lifecycle` required; `spec.system` required for production
  runtime components in strict mode unless exempted. `metadata.title` for display; never churn
  `metadata.name` on rename/rebrand. One Component per independently built/deployed/published/
  imported/operated unit — else `spec.subcomponentOf` or leave out.
- **API entity:** create only when there is a stable contract identity **and** at least one of a
  formal definition file, explicit developer confirmation, clear server/provider ownership evidence,
  or a matching snapshot entity. Reference the definition by path via `spec.definition.$text` (inline
  only when tiny/generated). Never create API entities from isolated client calls, env var names,
  route strings, README examples, tests, vendored specs, or generated clients alone.
- **Resource / `dependsOn`:** operational non-API dependencies the repo **connects to but does not
  own** (databases, caches, queues-as-infra, object stores, secret/identity infra). A **build/publish
  target** (container/package/artifact registry) is **packaging** — record via `interface.implements`
  (e.g. `standard:oci-image`), **not** a `spec.dependsOn` Resource.
- **Owned data schema is a *provided interface*, not a Resource.** When the repo **owns and
  publishes** a data contract — DB migrations / `schema.sql` / DDL, or a topic's Avro / JSON-Schema —
  model it as **provided**: an API entity referencing the schema file via `$text` (org-defined
  `spec.type`, e.g. `sql` / `avro`), or at minimum `interface.implements: schema:*`. Reserve
  `Resource` / `dependsOn` for a datastore whose schema is owned **elsewhere** and merely consumed.
- **Streaming & callback surfaces** (WebSocket, SSE, webhooks) are first-class, not just a
  `protocol:*` conformance. When a contract exists — AsyncAPI can model WS / SSE / webhook bindings —
  emit an API entity (`type: asyncapi`, or org-defined `websocket` / `sse` / `webhook`) and put the
  conformance (`protocol:websocket` / `protocol:sse` / `protocol:webhook`) on the Component.
  **Direction:** a WS/SSE endpoint the repo *serves*, or a webhook it *hosts to receive* callbacks, is
  **provided**; a webhook URL it *calls out to* is **consumed**. With no contract file, park it in the
  candidate lane — do **not** bury it as an `implements` token alone.
- **Identity & gateway edge** is a *relationship*, not only a deploy conformance. An OIDC/OAuth or
  SAML **provider** the repo runs is **provided** (`security:oidc-provider` /
  `security:oauth2-provider` / `security:saml-idp`); authenticating **against** an IdP (e.g. Keycloak)
  is a **consumed** auth dependency (candidate, or Resource + `security:oidc-client`). A gateway / mesh
  fronting the component (Kong, Istio) is `platform:api-gateway` / `platform:service-mesh`; secrets /
  policy backends are `security:secrets-manager` / `security:policy-engine`. Do not reduce Kong to
  `platform:kubernetes-ingress` alone when it is enforcing auth.
- **User-facing interfaces** are a distinct class — the counterparty is a **human** (or a script
  driving the surface), not a cataloged component. It spans both **interactive** surfaces (UI, CLI,
  TUI) and **static artifacts** (documents, infographics, guides): a PDF / spreadsheet is still
  user-facing — non-interactivity does not exclude it. Inventory at the **Component** level: pick the
  fitting `spec.type` (`website` / `tool` / `documentation`); add `metadata.links` (deployed URL /
  published artifact) or `backstage.io/techdocs-ref` for TechDocs; tag a `ux:*` conformance
  (*interactive:* `ux:web-ui` / `ux:cli` / `ux:tui` / `ux:desktop` / `ux:mobile`; *static:*
  `ux:document` / `ux:infographic` / `ux:guide` / `ux:api-reference` / `ux:runbook`). **Never** emit
  them as `providesApis` / `consumesApis` — a human is not a graph node. Escalate to a real API entity
  **only** when a machine-consumable contract exists behind the human one (a CLI with a documented
  stdout/JSON or exit-code contract; a UI with a documented URL/deep-link or embed contract).
  Versioning, compatibility, and **portability** all apply — a broken CLI flag or UI route is a
  breaking change, and a shipped artifact that **hard-codes our infrastructure** (URLs, hosts) breaks
  foreign deployment (the foreign-setup guide is largely interface docs).
- **`implements` conformance** (custom annotation): identifiers come from
  `references/interface-taxonomy.md` (or `interface_registry_path`). **Never invent a new identifier
  and never commit an unrecognized one** — if a conformance seems real but has no approved identifier,
  do **not** coin one; record it as a question in the ephemeral questions sidecar for taxonomy review,
  and commit only recognized identifiers. (An nginx-served SPA is `ux:web-ui` — **not** an invented
  `standard:web-spa`.)
- **Breadth:** represent *every* discoverable surface in the interface taxonomy — in-process, sync,
  async, data, UI, identity, packaging, infra, integration — not only the four Backstage-native API
  types (`openapi` / `asyncapi` / `graphql` / `grpc`). Anything real but not natively typable is
  captured via an org-defined `spec.type`, an `interface.implements` conformance, or the candidate
  lane — **never silently dropped**.

## Workflow

Read `references/sidecar-schemas.md` for the sidecar shapes; `references/backstage-entities.md` for
entity shapes.

- **Step 0 — Capture the human view.** Before deep scanning. If `.backstage/human-system-view.yaml`
  exists, read it and ask only for deltas. Normalize the view into claims (schema in
  `references/sidecar-schemas.md`) — but do not yet decide whether they are catalog facts.
- **Step 1 — Load existing catalog and org context**, in order when available: existing
  `catalog-info.yaml`/`.yml`/`.backstage/**` → `CODEOWNERS` → `catalog_snapshot_path` →
  `catalog_policy_path` → `owner_registry_path` → `system_registry_path` → `interface_registry_path`
  → `.catalogignore`/`.gitignore`. `CODEOWNERS` is the ownership source (see Organization givens for
  the missing-file gate). If an existing `catalog-info.yaml` looks complete, trust it as the skeleton
  and scan for gaps; preserve user-authored names/owners/systems/lifecycle/API refs unless clearly
  contradicted and a human confirms the correction.
- **Step 2 — Cheap manifest pass.** Inspect repo structure and known manifest/config files first (do
  not read full source yet): existing Backstage declarations; API specs (OpenAPI/AsyncAPI/GraphQL/
  proto/`buf.yaml`/Avro/JSON-Schema/WSDL/XSD); package/runtime manifests; deployment manifests
  (Dockerfile/compose/Helm/Kustomize/K8s/Terraform); CI (`.gitlab-ci.yml` first, then others,
  Makefile/Taskfile); ownership/docs (`CODEOWNERS`, README, `docs/**`, ADRs). You know these
  filenames — do not enumerate, just collect what's present.
- **Step 3 — Convention fast path.** If the repo follows common conventions, minimize tokens: a
  single-service repo (catalog-info + one API spec + Dockerfile + chart) needs only targeted reads;
  a library repo with no server/deploy evidence → `type: library` (invent no runtime APIs); a pure
  Helm repo → `type: chart` implements `platform:kubernetes-helm-chart` (a chart/helmfile that **composes multiple members** is an *assembly* → §Compose, a `System`, not a Component); a pure Terraform
  repo → implements `platform:terraform-module` (module vars/outputs, not APIs, unless the org models
  modules as APIs); a docs-only repo → `type: documentation`. Stop deep scanning once strict output
  is complete and evidence sufficient.
- **Step 4 — Detect component boundaries.** One repo ≠ one component. Combine existing descriptors,
  package manifests, Dockerfiles, deployable roots, service entrypoints, CI build-matrix paths,
  workspace definitions, and human-declared boundaries. Emit a separate Component only for an
  independently built/deployed/published/imported/operated unit; else `subcomponentOf` or omit. If the
  repo instead **composes other components** (a helmfile / umbrella chart / manifest set over multiple
  members) it is an **assembly** (a **release** if it deploys to a cluster) — switch to the roll-up in
  §Compose.
- **Step 5 — Deep discovery (only if the cheap pass leaves gaps).** Search source for evidence of
  **provided** (HTTP routes, RPC/gRPC servers, event producers/consumers, GraphQL, CLI/library
  entrypoints, deployment interfaces), **consumed** (generated clients, outbound HTTP, messaging
  sub/pub, datastores/infra → model as `dependsOn` unless best as an API), **implemented** (container
  image, packaging, Helm/K8s, artifact ecosystems, schemas, auth), and **absorbed** interfaces. You
  know the frameworks — apply the *directionality rules* below; do not enumerate frameworks. For a
  suspected **absorbed** copy — look inside `vendor/` / `third_party/` (suppressed for other purposes,
  but the twin's home) — confirm it is a copy of an *elsewhere-owned* contract, then treat per
  *Absorptions* — a candidate (`review: needs-review`) until confirmed.
- **Step 6 — Reconcile** human, repo, and catalog views. Classify each claim:

  | Human view   | Repo evidence | Catalog   | Classification                | Action                                               |
  |--------------|---------------|-----------|-------------------------------|------------------------------------------------------|
  | agrees       | agrees        | agrees    | `confirmed`                   | Preserve or emit catalog truth                       |
  | agrees       | agrees        | missing   | `catalog-missing`             | Propose update if fields complete                    |
  | agrees       | missing       | missing   | `repo-missing`                | Park (`review: needs-review`); ask targeted question |
  | agrees       | contradicted  | missing   | `repo-contradicted`           | Ask targeted question; do not commit relation        |
  | missing      | strong        | missing   | repo-only candidate           | Commit only if policy allows; else ask               |
  | missing      | strong        | exists    | repo/catalog confirmed        | Preserve; optionally update human view               |
  | disagrees    | agrees        | disagrees | `catalog-contradicted`        | Blocking question or architecture review             |
  | disagrees    | disagrees     | agrees    | `stale-human-view`/repo drift | Preserve catalog unless correction confirmed         |
  | all disagree | mixed         | mixed     | `needs-architecture-review`   | Do not commit graph-changing relation                |

  A wrong human view is architecture signal, not failure. An **absorbed twin is itself a
  reconciliation signal** (the human believes a live call, the repo holds an embedded snapshot) →
  surface the mismatch and record the twin (`interface.direction: absorbed` + `interface.absorbed/*`,
  `review: needs-review`) until confirmed.
- **Step 7 — Generate committed output.** Emit `catalog-info.yaml` only from claims meeting the
  commit policy: one Component per unit; one API per concrete provided/consumed definition; native
  `providesApis`/`consumesApis`/`dependsOn`; `interface.implements` and absorbed-twin annotations;
  the ledger tokens per entity. Full evidence and reconciliation stay in the ephemeral discovery
  report, not per-entity file pointers.
  - **Prepend the self-describing header** so whoever opens the ledger — an AI, a human, or an IDE —
    discovers how to maintain and validate it. Two layers, environment-preferred with an in-artifact
    fallback (the same shape as member resolution):
    - **Skill discovery.** A top **marker comment**, above the first `---`:
      `# maintain-ibom reconciliation ledger — maintain via the maintain-ibom skill; read/understand via`
      `# the understand-ibom skill (read-only); do not hand-edit.` — and, per *facts only* below,
      **no other comment follows it**. Its **machine twin** is `interface.maintained-by: maintain-ibom`
      on the **primary/root entity** —
      it survives comment-stripping tooling and a tool that ingests any single split document. When the
      environment ships an ambient rule that routes ledger work to these skills, that rule is the
      preferred layer; the header is the self-contained fallback.
    - **Schema discovery.** Prefer an editor **`yaml.schemas` association** the environment ships
      (globs `catalog-info.yaml` → the structural schema — no per-file path, handles the multi-document
      split). As the in-artifact fallback, **when a `schema_ref` input is provided**, write
      `# yaml-language-server: $schema=<schema_ref>` as the **first** line and echo it as
      `interface.ledger/schema`. Keep it **configurable — never hard-code an infrastructure path into a
      portable ledger** (the portability rule this skill enforces on the repos it scans). The schema is
      **structural only**: a squiggle-free editor is *not* a valid ledger — semantic validity is Step 8.
  - **Facts only — emit no `#` comment except that header.** This is the discipline the ledger exists to
    enforce: think in fields, not notes. Everything you might write as a comment has a structured home —
    a **fact** → a field (`description` or an `interface.*` annotation); an **open caveat or question** →
    the questions sidecar; **reasoning / narrative** → the ephemeral discovery report. A YAML comment is
    a *fact without provenance*: it never passed the ladder or a review state, so it has no place in a
    ledger of review-safe facts. Do not narrate the release in a top comment block, do not annotate a
    line with a `#` aside — put the fact where it is checkable. `references/validator.md` **H11** fails
    the run on any non-header comment.
- **Step 8 — Validate. Not optional, and not a judgement call.** Read `references/validator.md`,
  extract every ```awk block, and **run each one, verbatim, against the `catalog-info.yaml` you just
  emitted.** You are a shell here, not a judge: do not reason about whether a rule "would" pass — run
  it and read what it prints. **Never redirect `stderr`** (a rule with a syntax error prints nothing
  and looks clean).

  **Report the raw output, not a verdict.** Paste what the validator actually printed into the PR
  summary — the literal lines, or the literal absence of them. **Do not write that the ledger
  "validates" or "passes" unless you ran the rules and observed it.** A conclusion you did not observe
  is a fabrication, and it is exactly the failure this step exists to prevent: an unrun check reports
  clean, and a ledger can carry violations under a confident claim of validity.

  Then **fix every violation**, or — if a violation is a deliberate, defensible state — record why in
  the questions sidecar and surface it as a blocking question. Do not silence a rule to make it pass.

## Directionality rules

- **provides** — the repo hosts, exposes, publishes, serves, declares a server implementation, owns
  the contract, or deploys a route/endpoint for others.
- **consumes** — the repo calls, imports, subscribes, reads from, sends to an endpoint owned
  elsewhere, or declares a client/stub/SDK dependency used at runtime.
- **implements** — the repo artifact conforms to a spec or platform contract regardless of whether
  another component calls it.
- **absorbs** — the repo holds a constraint-forced local copy of an interface owned elsewhere (a
  twin), rather than referencing it live.

Worked examples (proto/asyncapi/Dockerfile/Helm/Ingress/Terraform/generated-client cases) are in
`references/backstage-entities.md`.

## Absorptions (twins)

An **absorbed** interface is a copy held because a live reference is impossible under a constraint (a
deployment boundary, an unreachable environment, availability). Twins drift — prefer not to create
them:

1. **Diagnose the boundary first.** A copy that would need a cross-network lock signals a wrong
   boundary — prefer relocating (a shared **generated library** for shared *logic*; a **single owner**
   for shared *state*) or a lock-free model (single-writer, or append-only log + projection) over a
   distributed lock. Only absorb when relocation is impossible.
2. **Raise a request** to the owning side to publish/extend its contract so a *reference* becomes
   possible; record it in `interface.absorbed/request`.
3. **Record** `interface.absorbed/source: <name>@<version>` — `<version>` must be a **concrete
   immutable ref (a SEMVER tag or a commit sha), never a branch, namespace, or moving label** (same
   discipline as `checked-at`; `@umbrella` / `@feature-x` are wrong) — plus a coordination model (prefer
   an immutable, versioned snapshot so no lock is needed) and `interface.absorbed/reconciliation-owner`.
4. **Stamp the copy by its *nature*, not its filepath.** A vendored copy is still an interface
   **definition file**, so `interface.provenance: contract` (**never `docs`**). Its
   `interface.visibility` **mirrors the canonical contract's exposure**, not the fact that it is
   copied: `internal` for an org-internal contract (the common case), `external` **only** if the
   canonical owner is genuinely outside the org. Every repo that absorbs the same contract must stamp
   it **identically** — the twin must not read `contract` / `internal` in one repo and `docs` /
   `external` in another.

Absorbed twins are candidates by default: commit only when confirmed. **A twin parked as a candidate
still declares its source** — via the candidate lane's `absorbed=<ref>@<sha>` key (§Provenance ladder
→ *Candidate lane*), **not** `interface.absorbed/source`, which is one-per-entity and cannot carry more
than a single copy. "Candidate" means *not yet a graph edge*; it never means *undeclared*.

## Compose — assembly and release

An **assembly** (a repo that composes other components — typically a Helm chart / helmfile, but the
mechanism varies) and a **release** (a deployment to a cluster — of an assembly, **or of components'
helm charts directly**; the assembly layer is optional) are constructs whose IBOM is the **roll-up** of
their members. Detect the construct (Step 4) and switch to roll-up mode. **Construct is judgement from what is
deployed, not the registry's filing** (`references/dependency-management.md` §0 / §6): **model both
the assembly and the release as a `System`** — the grouping entity that carries the composed surface,
**not** a `Component: deployment`. A **release is one `System` per environment**, and its **primary
deliverable is the boundary API surface** (the interfaces the environment exposes/consumes); the
internal federate→reduce below is the *optional deepening*. A **`Domain` is opt-in (default off) and
wraps, never replaces, a `System`** — even 1-1 (`Domain:X` *contains* `System:X`); **interfaces
always live on the `System`**, the `Domain` is pure grouping. A member already belongs to its own
owning `spec.system`, so express composition membership with an `interface.members` annotation (a
comma list of member refs) — **not** by re-parenting members' `spec.system`.

**Enumerate members** by the construct's own mechanism — the invariant is *list the member artifacts*,
not *run Helm*: render the helmfile / read the umbrella chart's dependencies / read the manifest set.
**Resolve + fetch each member's IBOM via the onboarding registry + path convention and a bare-clone
`git show` at the manifest-pinned tag** — the mechanism (registry→repo resolution, the bare `git
show`, revision semantics) is in **`references/dependency-management.md`** (§1–§2). The
environment's governed resolver (a `repos.yaml`-style registry + OCI labels) is the **foreign / no-git
fallback** only. A guessed-by-name member ref is stamped `provenance: guessed` and raised as a question until
confirmed. **Federation is gated on concrete member coordinates**: a *release* pins member tags (so it
federates at those revisions), while an *importable assembly* usually leaves member images to
downstream injection (no pin) → **name-only structural compose**, deferring federation to the release.
An assembly with baked-in tags federates too — but **flag the hardcoded tags** (pinning what should be
injected is a smell).

**Reduce the wiring** — the core move, run over the *federated member IBOMs* (not the assembly's own
manifests alone):

1. **Match** provider↔consumer across the member set (one member's `providesApis` / `provides/candidate`
   against another's `consumesApis` / `consumes/candidate`).
2. **Cancel** each matched pair — it is **internal**; do not emit it on the assembly node.
3. **Record the *unmatched* surface on the `System`** (interfaces live on the System, never the
   wrapping Domain) **— both sides:**
   - unmatched **consumers** → external / **foreign dependencies** (candidate lane), **including each
     member's own external deps federated up** — do not drop them;
   - unmatched **providers** → the external **provided surface** (UIs, APIs, event streams exposed via
     the gateway). **Do not flatten this to a single `platform:kubernetes-ingress` token** — roll up
     the actual provided interfaces.
4. **Internalized infra** the assembly deploys for its members (e.g. an in-namespace NATS) becomes an
   in-assembly `Resource`, and the member's former external dependency on it is cancelled.

**For a release**, additionally add the **cluster edge** (actual ingress/egress) and **flag any
endpoint hard-coded to our infrastructure** — it must be configurable to be foreign-deployable.

The rolled-up surfaces must reference the members' **real committed entity names** (read from their
`catalog-info.yaml`), and a member's own unmatched external deps are the assembly's too — do **not**
re-derive the surface from the assembly's own manifests alone (that yields correct shape but an
incomplete, mis-named surface). **When a member IBOM is unreadable, degrade to a *hole* first — an
`interface.federation/degraded` entry (member ref + pinned tag), never a manifest-inferred surface.**
Then recover by precedence **reference → vendor → hole**: a member that **has** an IBOM is referenced;
a member **reachable with no IBOM** is **vendored** (the recommended default — `vendor-now`); only an
**unreachable** member rests as a hole (`references/dependency-management.md` §4). Operational detail is split across
**`references/dependency-management.md`** (resolve / fetch / degraded recovery / construct) and
**`references/compose.md`** (the federate→reduce algorithm); read both for an assembly/release repo.

## Confidence and evidence

- `high`: direct declaration in a formal spec, manifest, catalog-info, explicit server/client config,
  or developer-confirmed fact.
- `medium`: strong code evidence, framework conventions, generated client/server code, or
  CI/deployment evidence.
- `low`: docs-only, naming convention, partial config, unverified human statement, or ambiguous
  ownership/directionality.

Confidence is a **live ledger value**, recomputed each run. Commit only the ledger tokens; the full
evidence trail lives in the ephemeral discovery report and the PR, never as committed pointers. Do
not emit an API entity for low-confidence inferred APIs unless policy allows, the name is stable, and
there is at least one concrete evidence path — prefer candidates and questions.

## Commit policy

- `confirmed` claims may be committed.
- `catalog-missing` claims may be proposed if required fields are complete and policy permits.
- Repo-only high-confidence claims may be proposed if they create no new global system/API boundary
  and collide with no existing entity.
- `ambiguous`, `repo-missing`, `catalog-contradicted`, `repo-contradicted`, and unconfirmed absorbed
  twins stay out of the graph — parked in the candidate lane / `review` tokens and raised as PR
  questions — unless explicitly resolved.
- `needs-architecture-review` claims must not be committed until reviewed by the owner/architecture
  group.
- Human claims may be annotated (labeled human-declared) but never used as graph relations unmapped.

## Graph safety rules

- **System safety.** Do not create a new `System` from a repo/package/chart/deployment name or README
  heading. It must come from `system_registry_path`, existing catalog, or explicit owner/architect
  confirmation. Production `service/website/data-pipeline/worker/deployment/chart` components missing
  `spec.system` → blocking question in strict mode unless the org allows unassigned components.
- **API safety.** Create an `API` only with stable contract identity and sufficient evidence. Never
  from isolated client calls, env var names, route strings, README examples, tests, fixtures,
  vendored specs, generated clients alone, copied schemas, or docs that merely mention another API.
- **Consumed API safety.** Match against an existing `API` in `catalog_snapshot_path` first; if no
  match, park in the **candidate lane** (`interface.consumes/candidate`) — do not invent a global API
  name. For third-party APIs prefer central refs (`api:external/stripe-api`, `api:external/github-api`).
  Do not create one duplicate external API per consuming repo.
- **Conformance safety.** `interface.implements` describes conformance to a standard/packaging/
  runtime/platform/protocol/schema — never a substitute for `providesApis`/`consumesApis`/`dependsOn`.
  A `protocol:*` names a surface the repo **serves / conforms to**, not one it merely **consumes**: a
  protocol reached only through an outbound call or reverse proxy (e.g. an SSE or WebSocket upstream
  the repo proxies to) belongs on the **consumes / candidate** side, **never** in `implements`.
- **Ownership safety.** Never infer owner from last committer, top contributor, or package author.
  Precedence: existing descriptor → `CODEOWNERS` (reconciled with `owner_registry_path`) → repo
  topics/team annotations → package/Helm maintainers/README contacts → `default_owner` if policy
  permits → blocking question. Missing `CODEOWNERS`: draft-and-commit-in-run satisfies the gate (see
  givens); never commit `owner: unknown` for production runtime components in strict mode.

## False-positive suppressions

Ignore build/dependency/output/vendor/test/generated paths by default (`.git`, `node_modules`,
`vendor`, `third_party`, `target`/`build`/`dist`, `.venv`, `examples`/`samples`, `test(s)`,
`fixtures`, `generated`, sub-charts) unless the developer confirms they are authoritative.

**Exception — absorbed twins.** The `vendor/` / `third_party/` suppression does **not** apply to
absorbed-interface discovery: a vendored copy of an *elsewhere-owned* contract (a schema/spec whose
canonical `$id`/owner is another repo) is the **prime absorbed-twin signal**. Scan those directories
for such copies and model them per *Absorptions* — do not skip the directory.

The non-obvious ones:

- Specs under `examples/fixtures/test/generated/vendor/third_party` are **not** provided APIs by
  default.
- Docker Compose used only for local dev is not production architecture evidence.
- A Kubernetes `Ingress` proves ingress conformance, not an OpenAPI contract.
- A Helm chart proves chart conformance; it does not mean the chart repo owns the app it deploys.
- A generated client proves possible consumption only when runtime code uses it with endpoint/config
  evidence; a route proves a callable surface, not a published contract.
- A queue/topic name proves messaging integration, not directionality (need pub/sub/send/receive
  evidence or confirmation).
- A **third-party** package dependency is not a consumed API — it is SBOM (`interface.implements` at most),
  not an edge. **Exception — first-party libraries (linkage):** a build-manifest dependency that resolves
  to an org repo (via the repo's own registry map or the onboarding registry) **is** a consumed interface — a
  **linkage** edge. Resolve and recurse it per `references/dependency-management.md` §7 (full-depth to the
  org frontier; third-party coordinates stop the recursion). This is distinct from `spec.dependsOn` (an
  operational Resource) and from composition (members).
- A copied API spec is not ownership evidence unless the repo is the declared source of truth
  (otherwise it is a candidate **absorbed** twin).
- CI running tests against a service is not necessarily runtime consumption.

## Lifecycle & visibility inference

- **Lifecycle** precedence: existing descriptor → developer-confirmed → explicit docs/labels →
  release/deployment evidence → `default_lifecycle` → `experimental`. Do not infer `production` merely
  from a Dockerfile/Helm chart/CI workflow; it requires deployment evidence (e.g. a `.gitlab-ci.yml`
  stage deploying to AKS), explicit declaration, or developer confirmation.
- **Visibility** (`interface.visibility`, for APIs): `public` (external), `partner`, `internal`,
  `system-private`, `component-private`, `external` (owned outside the org). Do not infer `public`
  from HTTP/Ingress — an HTTP endpoint can be private.

## Strict validation gates

In strict mode, fail catalog output and emit blocking questions when:

- `CODEOWNERS` is missing **and** no owner was supplied — draft it with the engineer (never infer from
  committers) and mark entities `review: needs-owner`; a CODEOWNERS drafted+committed in-run from a
  supplied owner clears this gate.
- `spec.owner` is missing, invalid, unknown, or free text.
- `spec.lifecycle` missing or not in the approved taxonomy.
- `spec.type` missing or not in the approved taxonomy.
- a production runtime component lacks `spec.system` (unless exempted).
- `providesApis`/`consumesApis` references an API absent from both the current file and the snapshot.
- a new API lacks owner, lifecycle, type, visibility, and definition path.
- an `implements` value is absent from `interface_registry_path` when a registry is provided.
- an inferred relation has only low-confidence evidence.
- an entity name collides with an existing entity of the same kind and namespace.
- the output would remove or rename an existing entity without explicit developer confirmation.
- human view, repo evidence, and catalog state disagree on system boundary, owner, or global API
  identity.

## Final output

- **Catalog-only:** return only `catalog-info.yaml` when the user asks for just the Backstage
  declaration and all strict gates pass.
- **PR-assist:** return `catalog-info.yaml` plus the three ephemeral sidecars, and print a **PR impact
  summary** (new entities, updated relationships, implemented interfaces, absorbed twins, human-view
  reconciliation, blocking questions, possible duplicates — shape in `references/example-run.md`),
  **including a `Validation` section carrying the validator's raw output from Step 8 — verbatim, not
  summarised, and never a claim you did not observe.**
  Commit only `catalog-info.yaml`; ensure `.backstage/` is gitignored and never staged. Do not create
  any other committed file for the narrative — it is printed, not committed.
- Never let a PR silently introduce a new system boundary, rename an entity, create a global external
  API, or add cross-system dependencies.
- State blocking questions and graph-impact changes plainly; record uncertainty structurally (ledger
  tokens + candidate lane), not in prose; ask narrow, evidence-backed questions, not broad ones.

**Efficiency:** human view first → existing `catalog-info.yaml` → registries/snapshot → source, last.
Honor ignore paths. Reuse a still-present `.backstage/interface-discovery-report.yaml` for unchanged
files (it is gitignored, not guaranteed across clones/CI). Prefer manifest/spec parsing over source
summarization; targeted search before opening files; read only what resolves high-impact claims; in
monorepos, find component roots first and scan only relevant ones.
