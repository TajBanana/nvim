# Ephemeral sidecar schemas

The three `.backstage/` sidecars are **ephemeral** (gitignored, regenerated per run — see SKILL.md
→ *Repository files and commit policy*). They are the per-run review render; durable state lives in
`catalog-info.yaml`. Use these schemas when writing them.

## `.backstage/human-system-view.yaml`

```yaml
schemaVersion: ibom/human-view/v1
capturedAt: "<iso-8601-timestamp>"
capturedBy:
  kind: human-assisted-ai
  engineer: "<name-or-id-or-unknown>"
  aiTool: "<tool-name-or-unknown>"
repo:
  url: "<repo-url-or-unknown>"
  revision: "<git-sha-or-unknown>"

humanView:
  confidence: partial
  summary: "Plain-language explanation of what this repo is believed to be for."
  commonNames:
    - "<name people use verbally>"
  businessCapability: "<business or product capability, if known>"
  believedSystem: "<plain-language or Backstage system name>"
  believedOwner: "<plain-language or Backstage owner>"
  believedLifecycle: "<production|experimental|deprecated|unknown|plain-language>"
  believedRuntime:
    - "<for example: runs as a backend service>"
    - "<for example: deployed through Helm>"
    - "<for example: publishes a Docker image>"
  believedProvides:
    - name: "<interface or capability name>"
      kind: "<plain-language|http|grpc|events|library|cli|chart|unknown>"
      confidence: "low|medium|high|unknown"
      notes: "<why the engineer believes this>"
  believedConsumes:
    - name: "<interface, service, platform, vendor, topic, API, package, or capability>"
      kind: "<plain-language|http|grpc|events|database|vendor-api|platform|unknown>"
      confidence: "low|medium|high|unknown"
      notes: "<why the engineer believes this>"
  believedUsersOrConsumers:
    - "<team, service, product, user group, or system>"
  knownUncertainties:
    - "<what the engineer is unsure about>"
  knownMismatches:
    - "<known naming, ownership, system, repo, or dependency mismatch>"
  freeformNotes: |
    <preserve relevant plain-language context without forcing technical precision>
```

Rules:

- Preserve the human's terms even if they are not Backstage-safe.
- Do not store secrets, credentials, incident details, personal data beyond an approved
  engineer identifier, or confidential customer information.
- Convert human statements into structured claims during reconciliation.
- Do not use human-only claims as Backstage graph relations unless confirmed by policy.

### Normalizing human claims (Step 0)

Convert the human view into claims, but do not decide yet whether they are catalog facts:

```yaml
humanClaims:
  - id: hv-001
    claim: "This repo is part of Payments Platform."
    normalizedCandidate:
      relation: partOf
      entityRef: component:default/payment-gateway
      targetRef: system:default/payments-platform
    source: human-declared
    confidence: partial
  - id: hv-002
    claim: "Checkout calls this service."
    normalizedCandidate:
      relation: apiConsumedBy
      entityRef: api:default/payment-gateway-api
      targetRef: component:default/checkout-service
    source: human-declared
    confidence: low
    note: "Direction and API identity require repo/catalog evidence."
```

## `.backstage/interface-discovery-report.yaml`

```yaml
schemaVersion: ibom/discovery/v2
repo:
  url: "<repo-url-or-unknown>"
  revision: "<git-sha-or-unknown>"
  scannedAt: "<iso-8601-timestamp>"
mode: pr-assist
inputs:
  catalogSnapshot: "<path-or-none>"
  catalogPolicy: "<path-or-none>"
  interfaceRegistry: "<path-or-none>"
  strictMode: true

claims:
  - id: claim-001
    layer: repo-evidenced
    entityRef: component:default/payments-service
    relation: provides            # provides | consumes | implements | absorbs
    targetRef: api:default/payments-grpc-api
    mode: native                   # native | ai
    tool: buf@1.47                 # the pinned tool used (also the pin for re-runs)
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
  # For an absorbs claim, also record the absorption fields:
  #   relation: absorbs
  #   absorbed: { source: "roster-api@4.1.0", coordination: "immutable snapshot", reconciliationOwner: "group:edge-ops", request: "OPS-482" }

reconciliation:
  - claimId: hv-001
    humanClaim: "Repo belongs to payments-platform"
    repoEvidence:
      status: weak-support
      evidence:
        - path: README.md
          selector: "Payments Platform"
    catalogEvidence:
      status: contradicted
      currentValue: system:default/checkout
    classification: catalog-contradicted
    action: blocking-question
    question: "Should this component remain in checkout, move to payments-platform, or is this repo shared?"
```

## `.backstage/catalog-questions.yaml`

```yaml
schemaVersion: ibom/questions/v1
questions:
  - id: q-api-001
    severity: blocking
    entity: component:default/payments-service
    claim: "Candidate provided gRPC API payments-grpc-api"
    evidence:
      - path: proto/payments.proto
        selector: "service PaymentsService"
      - path: src/main/java/.../GrpcServer.java
        selector: "addService(new PaymentsServiceImpl())"
    defaultAnswer: confirm
    allowedAnswers:
      - confirm
      - reject
      - rename
      - external-owner
      - unknown
    requestedFieldsIfConfirmed:
      - api_ref
      - owner
      - system
      - lifecycle
      - visibility
      - definition_path
```

A developer answer of `unknown` must not become an ingestible Backstage relation. Keep it out of
the graph — parked in the **candidate lane** (with `review: needs-*`) and, for the current review,
this ephemeral questions sidecar.
