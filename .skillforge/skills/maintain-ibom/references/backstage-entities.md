# Backstage entity templates & mapping detail

Load this when emitting `catalog-info.yaml`. SKILL.md holds the *rules*; this holds the *shapes*.
The ledger annotations (`interface.provenance`, `interface.discovery/*`, `interface.review*`,
`interface.consumes|provides/candidate`) are defined in SKILL.md → *Provenance ladder and
reconciliation ledger*; reproduce them on entities as shown.

## Component entity

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: <component-name>
  title: <human-friendly-display-name>
  description: <short-description>
  links:                                # optional — user-facing surfaces: deployed URL, user docs
    - url: <deployed-url>
      title: <label>
  annotations:
    backstage.io/source-location: url:<repo-url>
    interface.provenance: <human|registry|contract|manifest|code|docs|guessed>
    interface.provenance/owner: <tier>        # per-field, e.g. owner from CODEOWNERS = human
    interface.discovery/mode: <native|ai>
    interface.discovery/confidence: <high|medium|low>
    interface.discovery/checked-at: <SEMVER tag or commit sha — never HEAD/branch>
    interface.review: <ok|needs-review|contradicted|needs-owner>
    interface.review/ref: <MR / ticket ref, e.g. MR-482>
    interface.implements: <comma-separated-conformance-refs>
    # Evidenced-but-unconfirmed relations — parked, NEVER emitted as consumesApis/providesApis:
    interface.consumes/candidate: <comma-list of names>
    interface.consumes/candidate/<name>: "provenance=<tier>;confidence=<high|medium|low>;review=<needs-owner|needs-review>"
    # a VENDORED candidate adds a required 4th key naming its source: ;absorbed=<member-ref>@<fetched-sha> (see §Compose / dependency-management.md)
spec:
  type: service | website | library | tool | documentation | deployment | chart | template | data-pipeline | worker | other | <org-defined>
  lifecycle: experimental | production | deprecated | <org-defined>
  owner: <owner-ref>
  system: <system-ref>
  providesApis:
    - <api-ref>
  consumesApis:
    - <api-ref>
  dependsOn:
    - resource:<namespace>/<resource-name>
  subcomponentOf: <component-ref>
```

Rules:

- `spec.owner` and `spec.lifecycle` are required for committed components.
- `spec.system` is required for production runtime components in strict mode unless an
  organization policy explicitly exempts them.
- Use `metadata.title` for display names. Do not churn `metadata.name` because a repo was
  renamed or the product was rebranded.
- Do not create one component per folder unless the folder represents an independently built,
  deployed, imported, published, or operated unit.

## API entity

```yaml
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: <api-name>
  title: <human-friendly-display-name>
  description: <short-description>
  annotations:
    interface.provenance: <human|registry|contract|manifest|code|docs|guessed>
    interface.discovery/mode: <native|ai>
    interface.discovery/confidence: <high|medium|low>
    interface.discovery/tool: <pin ref, e.g. buf@1.47>
    interface.discovery/checked-at: <SEMVER tag or commit sha — never HEAD/branch>
    interface.version: <semver, suggested from contract evolution + latest git tag>
    interface.visibility: public | partner | internal | system-private | component-private | external
    interface.review: <ok|needs-review|contradicted|needs-owner>
    interface.review/ref: <MR / ticket ref, e.g. MR-482>
    # For an absorbed twin only. Stamp above: provenance=contract (a vendored copy is still a
    # definition file — NOT docs); visibility mirrors the canonical (internal unless the canonical
    # owner is outside the org); stamp identically in every repo that absorbs the same contract.
    interface.direction: absorbed
    interface.absorbed/source: <name>@<version>   # <version> = SEMVER tag or sha — never a branch/namespace
    interface.absorbed/coordination: <immutable-snapshot|single-writer|locked>
    interface.absorbed/reconciliation-owner: <owner-ref>
    interface.absorbed/request: <ticket ref, e.g. OPS-482>
spec:
  type: openapi | asyncapi | graphql | grpc | <org-defined, e.g. websocket|sse|webhook|sql>
  lifecycle: experimental | production | deprecated | <org-defined>
  owner: <owner-ref>
  system: <system-ref>
  definition:
    $text: <relative-path-to-definition>
```

- Use `$text`, `$yaml`, or `$json` substitutions when a valid local interface definition exists.
  Inline `spec.definition` only when the definition is tiny or generated from source because no
  file exists.
- Only create an API entity when there is a stable contract identity and at least one of: a formal
  definition file; explicit developer confirmation; clear server/provider ownership evidence; or a
  matching entity already exists in `catalog_snapshot_path`. Do not create API entities from
  isolated HTTP client calls, environment variable names, route strings, README examples, tests,
  examples, vendored specs, or generated clients alone.

## Resource dependencies

Use `Resource` or `spec.dependsOn` for operational dependencies that are not APIs: databases;
caches; queues when modeled as infrastructure rather than event contracts; object stores; secret
stores; clusters; cloud accounts/projects/subscriptions; service mesh infrastructure; identity
providers where the dependency is operational rather than an API contract. Do not model
databases, object stores, queues, or caches as APIs unless the repository defines a formal API
contract for them. A **build/publish target** (container registry, package registry, artifact
repository) is a **packaging** concern, not a runtime dependency — record it via
`interface.implements` (e.g. `standard:oci-image`), not as a `spec.dependsOn` Resource.

**Owned vs consumed data.** A datastore the repo merely connects to is a `Resource` / `dependsOn`; a
data **schema the repo owns and publishes** (DB migrations / `schema.sql` / DDL, or a topic's Avro /
JSON-Schema) is a **provided interface** — an API entity referencing the schema via `$text`
(org-defined `spec.type` such as `sql` / `avro`), or at minimum `interface.implements: schema:*`.

## Custom conformance annotation (`implements`)

Backstage does not natively distinguish "conforms to OCI image format" from "provides an API."
Preserve these as custom annotations on the Component unless the organization has implemented a
custom kind/relation:

```yaml
metadata:
  annotations:
    interface.implements: "standard:oci-image,package:war,platform:kubernetes-helm-chart,platform:kubernetes-ingress"
```

The approved identifier baseline and the controlled-registry validation shape live in
`references/interface-taxonomy.md`.

## Directionality — worked examples

(The four directionality *rules* are in SKILL.md. These are illustrations.)

- `.proto` file with service plus server registration: provides `grpc` API and implements
  `schema:protobuf` / `protocol:grpc`.
- `.proto` file with only generated client usage: consumes `grpc` API.
- `asyncapi.yaml` with application publishing domain events: provides `asyncapi` if this component
  owns/publishes the event contract; consumes if it subscribes to externally owned events. If
  ambiguous, use evidence and lower confidence.
- Dockerfile or CI pushing image: implements `standard:oci-image`.
- Maven `packaging=war`: implements `package:war`.
- Helm `Chart.yaml`: implements `platform:kubernetes-helm-chart`.
- Kubernetes `Ingress` manifest: implements `platform:kubernetes-ingress`; it may also provide an
  HTTP entrypoint if host/path/service evidence is present.
- Terraform module variables/outputs: implements `platform:terraform-module`; do not create APIs
  unless org taxonomy models Terraform modules as APIs.
- Generated OpenAPI client plus runtime usage: candidate consumed API, not provided API.
- Generated server stub without runtime registration: candidate API, not confirmed provided API.
- A pinned, embedded copy of another service's OpenAPI/proto used offline: absorbs that interface —
  record source@version, coordination, and a reconciliation owner.
- A WebSocket server (`/ws/events`) or SSE endpoint the repo serves: **provides** a streaming
  interface (`type: asyncapi` or org-defined `websocket`/`sse`; `implements: protocol:websocket|sse`).
  A WebSocket/SSE the repo only *connects to* is **consumed** (candidate if uncataloged).
- A webhook endpoint the repo hosts to receive callbacks: **provides** it. A webhook URL the repo
  registers with / calls out to: **consumes** it.
- DB migrations / `schema.sql` this repo owns: **provides** a data-schema interface
  (`implements: schema:sql`, or an API entity referencing the DDL). A database the repo only connects
  to: `Resource` / `dependsOn`.
- An OIDC/OAuth provider the repo runs: **provides** (`security:oidc-provider`). Authenticating
  against Keycloak: **consumes** (`security:oidc-client`). A Kong gateway enforcing auth in front of
  the component: `platform:api-gateway`.
- A CLI or web UI the repo serves to users: a **user-facing** provided surface — Component
  `type: tool` / `website` + `metadata.links` + `implements: ux:cli` / `ux:web-ui`; **not** a
  `providesApis` edge unless it also exposes a machine contract (scriptable CLI output, a documented
  URL scheme).
- A shipped guide / infographic / PDF the repo publishes: a **static user-facing** deliverable —
  `type: documentation` (or the owning Component) + `metadata.links` / `backstage.io/techdocs-ref` +
  `implements: ux:guide` / `ux:infographic` / `ux:document`; never a graph edge.

## Entity identity & deduplication

Names are stable IDs, not labels. Use `metadata.title` for display names and human language. Do
not rename `metadata.name` because a repo moved or a product was rebranded. Prefer complete entity
refs for cross-repo references:

```yaml
spec:
  owner: group:default/payments
  system: system:default/payments-platform
  providesApis:
    - api:default/payments-grpc-api
  consumesApis:
    - api:default/ledger-events-api
```

Before creating a new entity, search `catalog_snapshot_path` for: same name, kind, and namespace;
same source location; same API title/spec hash; same protobuf package/service; same
OpenAPI/AsyncAPI `info.title` and `info.version`; same GraphQL schema hash; same Helm chart name
and repository; same package name and ecosystem; same human common name. If a likely duplicate is
found, prefer linking to the existing entity and add a review question instead of creating another.

## Naming

Deterministic, Backstage-safe (lowercase, invalid chars → `-`, prefer < 63 chars). Beyond the
obvious DNS-style rules, two non-obvious ones:

- Prefer explicit names from existing catalog-info, API spec `info.title`, protobuf
  package/service, AsyncAPI `info.title`, GraphQL schema name, Helm chart name, package manifest
  name, or repository name — and preserve historical entity names unless rename is confirmed.
- Use disambiguating suffixes when needed: `-grpc-api`, `-events-api`, `-http-api`,
  `-graphql-api`, `-chart`, `-worker`, `-library`. Human-friendly names/aliases go in
  `metadata.title`, not `metadata.name`.
```
