# Ledger validation — spec for a CI validator

The machine-checkable rules a linter must assert over a committed `catalog-info.yaml`. Purpose:
**lock in the ledger discipline the skill already produces** and mechanically catch the slips a
prose rule alone cannot enforce. This is a *spec* — the org wires the actual job (a GitLab CI lint
stage; `.gitlab-ci.yml`). Backstage annotations are string-valued, so most rules are value patterns /
enums plus cross-entity checks.

**The structural rules (§1 H-rules) ship as an executable schema:** `references/catalog-info.schema.json`
is the authoritative machine form (per-entity shape / enums / patterns / required fields) — one artifact
consumed by the runtime (constrain generation) and this CI validator. This
file is its **human-readable companion** and additionally specifies the **semantic / cross-entity**
rules (§2–§4) a JSON Schema cannot express (rollup precedence, candidate-not-an-edge, exact identifier
membership in `interface-taxonomy.md`, absorbed-copy cross-repo consistency, federation completeness).
Keep the two consistent (cross-check in CI). **The one exception is H11 (no stray comments): comments
are stripped before a JSON Schema ever parses the document, so H11 is *schema-invisible* and ships only
in the `awk` validator (`references/validator.md`) — the sole place a comment is even observable.**

## 1. Hard rules (enforce always)

| # | Rule | Assertion |
|---|---|---|
| H1 | Approved `implements` / `ux:` identifiers | every token in `interface.implements` (and `ux:*` conformances) exists in `interface-taxonomy.md`; **hard-reject** `platform:kubernetes-gateway-api` (org has no Gateway API) |
| H2 | `checked-at` immutability | `interface.discovery/checked-at` matches a SEMVER tag or a commit sha; **reject** `HEAD`, a branch name, or any moving label |
| H3 | Candidate-lane grammar | `interface.(consumes\|provides)/candidate/<name>` value is a **single line** of `provenance=..;confidence=..;review=..` — those three keys in order, **plus the optional fourth `absorbed=<ref>@<immutable>`** (C9a) and nothing else; `confidence ∈ {high,medium,low}`; `review ∈ {ok,needs-review,contradicted,needs-owner}` |
| H4 | Valid refs (right kind) | **every** ref (`spec.owner`, `spec.system`, `spec.domain`, `interface.members`, `providesApis`/`consumesApis`, `dependsOn`) is a valid Backstage ref for its field — a bare `name`, `ns/name`, or `kind:ns/name` — carrying the **correct kind** (owner ∈ `group`/`user`; system ∈ `system`; domain ∈ `domain`; members ∈ `component`/`resource`/`api`/`system`). **Reject wrong-kind** (`owner: team:default/payments-team`) and free-text/spaces. Bare shorthand (`owner: payments-team`, `system: payments`) is **valid** — Backstage resolves it in the default namespace; do not reject it (prefer-qualified is a soft lint, not a hard rule) |
| H5 | Review vocabulary | `interface.review` ∈ `{ok,needs-review,contradicted,needs-owner}`; `interface.discovery/mode` ∈ `{native,ai}`; `interface.provenance` (and `…/<field>`) ∈ the ladder tiers |
| H6 | `review: ok` floor | an entity is `ok` **only** if it has no candidate-lane entry, no `review/fields`, and no open question referencing it (rule 5) |
| H7 | Candidate is not an edge | a name in `interface.(consumes\|provides)/candidate` must **not** appear in `spec.consumesApis`/`spec.providesApis` (parked ≠ committed) |
| H8 | `source-location` present | every `Component` (and every entity the org marks ingestible) carries `backstage.io/source-location` |
| H9 | Referential integrity | every `providesApis`/`consumesApis`/`dependsOn` ref resolves in-file or in `catalog_snapshot_path`; no dangling refs |
| H10 | Sidecar self-loop | in the discovery report, a claim's `entityRef != targetRef` |
| H11 | No stray comments | the committed file carries **no `#` comment** except the self-describing header at the top (the `# yaml-language-server:` modeline and the `# maintain-ibom … reconciliation ledger` / `# … understand-ibom skill …` marker lines), and only in the leading block before the first content line. A comment is a *fact without provenance*: narrative belongs in the discovery report, a caveat in the questions sidecar, a fact in a field — never a YAML comment. **Schema-invisible** (comments are stripped before JSON-Schema parsing), so enforced **only** in `references/validator.md`, never the schema. Full-line comments only; an inline trailing `#` is a known gap (a `#` inside a quoted value is not a comment, and telling them apart in `awk` is the quoting hazard past rules were bitten by). |

## 2. Provenance / absorbed rules (enforceable now that §Absorptions specifies them)

| # | Rule | Assertion |
|---|---|---|
| P1 | Contract-file ⇒ provenance | a value sourced from an interface **definition file** (OpenAPI/AsyncAPI/proto/GraphQL/JSON-Schema/DDL — incl. a **vendored** copy) has `provenance ∈ {contract,registry,human}`; **reject `docs`** for a definition file (catches `.proto`→`docs`) |
| P2 | Absorbed source pin | `interface.absorbed/source` = `<name>@<ref>` where `<ref>` is a SEMVER tag or sha; **reject** a branch/namespace (`@umbrella`, `@feature-x`) — mirrors H2 |
| P3 | Absorbed twin stamping | an `interface.direction: absorbed` entity has `provenance: contract` and a `visibility` that is `internal` unless the canonical owner is out-of-org; the **same** absorbed contract is stamped identically across repos (cross-repo check, run over the aggregated catalog) |

## 3. Rollup rules (enforceable now that rules 5–6 specify precedence)

| # | Rule | Assertion |
|---|---|---|
| R1 | Review precedence | the entity `interface.review` equals the most-blocking open state among its fields/candidates on the order `contradicted > needs-owner > needs-review > ok` (catches a Component reading `needs-review` over `needs-owner` candidates) |
| R2 | Confidence worst-of | the entity `interface.discovery/confidence` = the minimum over its committed conformances/relations (and, for a `System`/`Domain`, over composed member facts) |

## 4. Compose rules (assembly / release repos; see §Compose + `references/compose.md`)

- C1 — an assembly and a release are each a `System` (not a `Component: deployment`); a release is one
  `System` **per environment**. A `Domain` is **opt-in** and **wraps** the System(s) (never replaces
  one, even 1-1); **interfaces live on the `System`**, never the `Domain`. Construct is judgement from
  what is deployed — **not** derived from the onboarding registry's filing.
- C2 — no matched internal provider↔consumer pair is emitted on the assembly node (it must be cancelled).
- C3 — the assembly's external **provided** surface is rolled up as real interfaces, **not** flattened
  to a lone `platform:kubernetes-ingress` token.
- C4 — a release flags any endpoint hard-coded to our infrastructure.
- C5 — an assembly `System` carries `interface.members` (member entity refs); members are **not**
  claimed via `spec.system`.
- C6 — federation completeness: rolled-up `provides/candidate` / `consumes/candidate` names resolve to
  the members' **real committed entities** (not ad-hoc manifest-derived names), and each member's own
  unmatched external deps appear in the assembly's `consumes/candidate`.
- C7 — **degraded holes**: `interface.federation/degraded` is a comma list of `<ref>@<immutable-ref>`
  (SEMVER tag or sha — **reject a branch / moving label**, mirroring H2/P2); every `<ref>` also appears
  in `interface.members`; a degraded ref must **not** appear in `providesApis`/`consumesApis` or the
  committed federated surface (a hole is not an edge — mirrors H7). An unreadable member is a hole,
  **never** a manifest-inferred surface.
- C8 — **federation accounting** (the counters are **not** interchangeable):
  `interface.federation` = `M/N` counts slots **filled** (vendored + referenced), `M ≤ N`, `N` = the
  number of `interface.members`, and `N − M` = the number of `interface.federation/degraded` holes.
  `interface.federation/referenced` = `R/N` counts only slots filled from the child's **own committed
  IBOM**, `R ≤ M`. `interface.federation/stale` = `S/N` counts vendored slots whose `source` ≠ `pinned`,
  `S ≤ M − R`. `interface.federation/mode` ∈ `{vendored,referenced,mixed}` and must agree with the
  counts (`referenced` iff `R = M > 0`; `vendored` iff `R = 0 < M`; else `mixed`).
  **`interface.federation` is not a federation claim — only `…/referenced` is.**
- C9 — **vendored recovery stamping.** *A vendored surface is a **declared absorption**, never a silent
  twin.* Four assertions, all checkable:

  - **C9a — every vendored surface declares its origin.** A surface recovered by vendoring a member
    records **which member it was copied from** and **at which revision it was read**:
    - as an **API entity** → `interface.direction: absorbed` **+** `interface.absorbed/source:
      <ref>@<immutable>` (per P2);
    - in the **candidate lane** → the optional fourth key on the candidate value:
      `provenance=…;confidence=…;review=…;**absorbed=<ref>@<immutable>**`.

    The candidate lane is the **normal** destination for a vendored surface on an uncatalogued estate —
    no owner and no catalog entity exists yet, so it cannot become an `API` (API safety). **It is not an
    escape from declaration.** Without `absorbed=`, a vendored surface is indistinguishable from one the
    parent derived from its own manifests — an *undeclared duplication of someone else's
    responsibility*: a **silent twin**, which is never permitted.

  - **C9b — referential integrity.** For every `absorbed=<ref>@<rev>`: `<ref>` MUST name a member that
    has an `interface.vendored/<member>` slot, and `<rev>` MUST equal that slot's `source=` revision.
    *You cannot declare a copy from a member you did not vendor, or at a revision you did not fetch.*

  - **C9c — no silent vendoring.** Every `interface.vendored/<member>` slot MUST be named by **at least
    one** `absorbed=` (candidate) or `interface.absorbed/source` (entity). A vendored member that
    contributes **no declared surface** is a **silent absorption**: the slot claims a surface was
    recovered while nothing in the ledger says where that surface came from. Fail the run.

  - **C9d — tiering.** The **slot** (`interface.vendored/<member>`) carries `provenance ∈
    {manifest,guessed}` — it is the *parent's derivation*, not the child's reviewed IBOM. Each vendored
    **fact**, however, carries its **own true source tier** (P1 still applies: a `.proto`/OpenAPI/DDL
    read from the child is `contract`; code-derived is `code`). **Do not cap facts at `guessed`** —
    graduation is a *delete-and-reference*, not an overwrite, so a higher fact tier never blocks
    supersession.

  *(Schema note: `candidateValue` accepts `absorbed=` with a SEMVER tag **or** a sha, matching
  `absorbedSource`; the key is **optional**. Policy prefers the **fetched sha**, on the same
  ground-truth argument as C10: a tag echoed back cannot prove the copy was actually read at that
  revision.)*
- C10 — **vendored slot grammar**: `interface.vendored/<member>` is a **single line** of exactly
  `source=<ref>@<fetched-sha>;pinned=<tag-or-sha>;provenance=…;confidence=…;review=…;stale=<true|false>`.
  `<member>` appears in `interface.members` and **must not** appear in `interface.federation/degraded`
  (a filled slot is not a hole). **`source` is the *fetched commit sha*** (`git rev-parse` on the clone)
  — ground truth of what was read, **not the tag echoed back** (a tag compared to itself makes `stale`
  tautological and cannot catch "recorded the pin without fetching it"). `pinned` is an immutable ref,
  **or** the sentinel `unresolvable` — a **last resort** only: a pre-release image tag that embeds a
  commit sha (`1.5.1-dev.3-f17533d0`) **must** be resolved to that sha, not declared unresolvable.
  **`stale=true` iff the fetched sha ≠ the sha `pinned` resolves to** (resolve the tag → sha first;
  never compare a sha to a tag textually). `pinned=unresolvable` ⇒ `stale=true` and
  `review ∈ {needs-review,contradicted}`. Vendor at the **pinned tag**, never HEAD — a HEAD-derived
  surface is born stale.

## CI hook

A GitLab CI lint stage over the changed `catalog-info.yaml` (and `.backstage/**` when present in the
working tree). Fail the pipeline on any H*/P*/R* violation; **surface `review != ok` and open
candidate-lane entries as review annotations, not hard failures** (they are legitimate parked state,
not defects). Compose rules (C*) apply only to assembly/release repos. The validator asserts *shape
and consistency*; it does **not** adjudicate which fact is true — that stays with the human approver
and the ledger's provenance.
