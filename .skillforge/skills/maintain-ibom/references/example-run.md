# Worked example — a full PR-assist run

A complete example for one service (`payments-service`): the human-view sidecar, the committed
`catalog-info.yaml`, the discovery-report sidecar, and the questions sidecar. Only
`catalog-info.yaml` is committed; the `.backstage/` files are ephemeral.

## `.backstage/human-system-view.yaml`

```yaml
schemaVersion: ibom/human-view/v1
capturedAt: "2026-07-07T00:00:00+08:00"
capturedBy:
  kind: human-assisted-ai
  engineer: unknown
  aiTool: unknown
repo:
  url: https://github.com/example/payments-service
  revision: unknown
humanView:
  confidence: partial
  summary: "This repo is believed to be the payments backend. It exposes payment authorization and is called by checkout."
  commonNames:
    - Payments API
    - Payment Gateway
  businessCapability: Payments
  believedSystem: payments-platform
  believedOwner: payments-team
  believedLifecycle: production
  believedRuntime:
    - Runs as a backend service
    - Deployed through Helm
    - Publishes a Docker image
  believedProvides:
    - name: Payments gRPC API
      kind: grpc
      confidence: medium
      notes: "Checkout is believed to call this."
  believedConsumes:
    - name: Ledger events
      kind: asyncapi-or-kafka-topic
      confidence: low
      notes: "Engineer is unsure which topic."
  believedUsersOrConsumers:
    - checkout-service
    - admin-portal
  knownUncertainties:
    - "Unsure whether this repo owns the API or only contains generated stubs."
    - "Unsure if ingress is production or only local/dev."
  knownMismatches:
    - "Team calls this Payments API, but repo name is payment-gateway."
```

## `catalog-info.yaml` (committed)

```yaml
# yaml-language-server: $schema=.claude/skills/maintain-ibom/references/catalog-info.schema.json   # emitted only when a `schema_ref` input is set; prefer an editor yaml.schemas glob instead
# maintain-ibom reconciliation ledger — maintain via the maintain-ibom skill; read/understand via
# the understand-ibom skill (read-only); do not hand-edit.
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: payments-service
  title: Payments Service
  description: Payments backend service
  annotations:
    backstage.io/source-location: url:https://github.com/example/payments-service
    interface.maintained-by: maintain-ibom
    interface.provenance: human
    interface.provenance/owner: human
    interface.discovery/mode: native
    interface.discovery/confidence: high
    interface.discovery/checked-at: v2.3.0
    interface.review: ok
    interface.implements: "standard:oci-image,package:war,platform:kubernetes-helm-chart,platform:kubernetes-ingress,protocol:grpc,schema:protobuf"
spec:
  type: service
  lifecycle: production
  owner: group:default/payments
  system: system:default/payments-platform
  providesApis:
    - api:default/payments-grpc-api
  consumesApis:
    - api:default/ledger-events-api
---
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: payments-grpc-api
  title: Payments gRPC API
  description: gRPC API provided by payments-service
  annotations:
    interface.provenance: contract
    interface.discovery/mode: native
    interface.discovery/tool: buf@1.47
    interface.discovery/confidence: high
    interface.discovery/checked-at: v2.3.0
    interface.review: ok
    interface.visibility: internal
spec:
  type: grpc
  lifecycle: production
  owner: group:default/payments
  system: system:default/payments-platform
  definition:
    $text: ./proto/payments.proto
---
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: ledger-events-api
  title: Ledger Events API
  description: AsyncAPI contract consumed by payments-service
  annotations:
    interface.provenance: contract
    interface.discovery/mode: native
    interface.discovery/confidence: high
    interface.discovery/checked-at: v2.3.0
    interface.review: ok
    interface.visibility: internal
spec:
  type: asyncapi
  lifecycle: production
  owner: group:default/ledger
  system: system:default/ledger
  definition:
    $text: ./asyncapi/ledger-events.yaml
```

## `.backstage/interface-discovery-report.yaml` (ephemeral)

```yaml
schemaVersion: ibom/discovery/v2
repo:
  url: https://github.com/example/payments-service
  revision: unknown
  scannedAt: "2026-07-07T00:00:00+08:00"
mode: pr-assist
claims:
  - id: claim-001
    layer: repo-evidenced
    entityRef: component:default/payments-service
    relation: provides
    targetRef: api:default/payments-grpc-api
    mode: native
    tool: buf@1.47
    confidence: high
    status: confirmed
    source: manifest-and-code
    evidence:
      - kind: protobuf-service
        path: proto/payments.proto
        selector: service PaymentsService
      - kind: server-registration
        path: src/main/java/.../GrpcServer.java
        selector: addService
  - id: claim-002
    layer: repo-evidenced
    entityRef: component:default/payments-service
    relation: implements
    targetRef: standard:oci-image
    mode: native
    tool: manifest
    confidence: high
    status: confirmed
    source: manifest
    evidence:
      - kind: dockerfile
        path: Dockerfile
reconciliation:
  - claimId: hv-001
    humanClaim: "This repo belongs to payments-platform."
    repoEvidence:
      status: supported
      evidence:
        - path: README.md
          selector: "Payments Platform"
    catalogEvidence:
      status: missing
    classification: catalog-missing
    action: propose-catalog-update
  - claimId: hv-002
    humanClaim: "This repo consumes ledger events."
    repoEvidence:
      status: supported
      evidence:
        - path: asyncapi/ledger-events.yaml
        - path: src/main/.../LedgerEventConsumer.java
          selector: "@KafkaListener"
    catalogEvidence:
      status: missing
    classification: catalog-missing
    action: propose-catalog-update
```

## `.backstage/catalog-questions.yaml` (ephemeral)

```yaml
schemaVersion: ibom/questions/v1
questions:
  - id: q-system-001
    severity: blocking
    entity: component:default/payments-service
    claim: "System assignment payments-platform (catalog currently lists checkout)."
    evidence:
      - path: README.md
        selector: "Payments Platform"
    defaultAnswer: unknown
    allowedAnswers:
      - confirm
      - reject
      - external-owner
      - unknown
    requestedFieldsIfConfirmed:
      - system
```

## PR impact summary (printed, not committed)

```markdown
## Catalog impact

### New entities
- component:default/payments-service
- api:default/payments-grpc-api

### Updated relationships
- component:default/payments-service provides api:default/payments-grpc-api
- component:default/payments-service consumes api:default/ledger-events-api
- component:default/payments-service dependsOn resource:default/payments-db

### Implemented interfaces
- standard:oci-image
- platform:kubernetes-helm-chart
- platform:kubernetes-ingress

### Absorbed twins
- api:default/ledger-events--offline (source ledger-events-api@2.1.0; reconciliation group:payments)

### Human-view reconciliation
- Human view and repo evidence agree that this belongs to payments-platform.
- Catalog currently lists checkout; system assignment requires review.

### Blocking questions
- q-system-001: Confirm system assignment for component:default/payments-service

### Possible duplicates
- api:default/payments-api may duplicate api:default/payment-service-api
```
