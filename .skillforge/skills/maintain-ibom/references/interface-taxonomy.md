# `implements` conformance taxonomy

The approved identifier baseline for `interface.implements`, plus the controlled-registry
validation shape. SKILL.md holds the **rule** (never invent or commit an unrecognized identifier;
an unmodeled conformance → question in the ephemeral sidecar for taxonomy review). This file holds
the **vocabulary**.

Prefer organization-approved identifiers from `interface_registry_path` when one is provided;
otherwise use this baseline. Use concise, stable identifiers.

## Baseline identifiers

- `standard:oci-image`
- `package:war`, `package:jar`, `package:npm`, `package:pypi`, `package:nuget`, `package:gem`,
  `package:cargo`, `package:go-module`
- `platform:kubernetes-manifest`, `platform:kubernetes-helm-chart`, `platform:kubernetes-ingress`,
  `platform:kubernetes-crd`, `platform:terraform-module` — the org stack (Azure AKS + Helm +
  Ingress + Terraform; **no Gateway API**, never emit `platform:kubernetes-gateway-api`).
  `platform:api-gateway` (e.g. Kong), `platform:service-mesh` (e.g. Istio / Linkerd).
  `platform:serverless-framework`, `platform:knative-service` only if a repo genuinely contains them.
- `protocol:http`, `protocol:grpc`, `protocol:websocket`, `protocol:sse`, `protocol:webhook`,
  `protocol:kafka`, `protocol:amqp`, `protocol:mqtt`, `protocol:nats`, `protocol:graphql`
- `schema:protobuf`, `schema:avro`, `schema:json-schema`, `schema:graphql`, `schema:wsdl`,
  `schema:xsd`, `schema:sql` (DB DDL / migrations owned by the repo)
- `security:oauth2-client`, `security:oauth2-provider`, `security:oidc-client`,
  `security:oidc-provider`, `security:saml-sp`, `security:saml-idp`,
  `security:secrets-manager` (e.g. Vault), `security:policy-engine` (e.g. OPA)
- `ux:*` — **user-facing** surfaces (human counterparty), interactive **or** static. The
  discriminator is *user-facing*, not interactivity — a PDF / spreadsheet is still UX. Inventory only;
  **never** a `providesApis` / `consumesApis` graph edge.
  - *interactive:* `ux:web-ui`, `ux:cli`, `ux:tui`, `ux:desktop`, `ux:mobile` — escalate to an API
    entity only if a machine-consumable contract exists behind the human one (scriptable CLI output,
    a documented URL / deep-link scheme).
  - *static artifact:* `ux:document` (PDF / spreadsheet / slides), `ux:infographic`, `ux:guide`,
    `ux:api-reference`, `ux:runbook` — a shipped documentation deliverable (e.g. a foreign-setup
    guide); apply the portability check (flag hard-coded infra).

Typical construct mapping: a Component implements `standard:oci-image`; an assembly implements
`platform:kubernetes-helm-chart`; a release implements the helmfile / Kubernetes contract.

## Controlled interface registry (validation)

When `interface_registry_path` is provided, validate all `implements` values against it. Example
shape:

```yaml
interfaces:
  standard:oci-image:
    category: standard
    displayName: OCI Image
    relation: implements
    allowedEvidence:
      - Dockerfile
      - buildpack config
      - Jib/Kaniko/Buildah config
      - CI step publishing a container image
    notEvidence:
      - docker-compose file used only for local development
      - README mention without build evidence

  package:war:
    category: package
    displayName: Java WAR package
    relation: implements
    allowedEvidence:
      - Maven packaging war
      - Gradle war plugin
      - WEB-INF structure

  platform:kubernetes-helm-chart:
    category: platform
    displayName: Helm chart
    relation: implements
    allowedEvidence:
      - Chart.yaml
      - values.yaml
      - templates directory

  platform:kubernetes-ingress:
    category: platform
    displayName: Kubernetes Ingress
    relation: implements
    allowedEvidence:
      - Kubernetes manifest kind Ingress
      - Helm template rendering kind Ingress
    notEvidence:
      - commented-out ingress template
      - disabled template with values default false and no production override
```

If `implements` relationships must be queryable as graph relations, the organization should
implement a custom Backstage kind and processor such as `Interface`, `Standard`, or `Contract`,
and generate a relation such as `implementsInterface`. Until then, keep conformance as controlled
annotations backed by the registry.
