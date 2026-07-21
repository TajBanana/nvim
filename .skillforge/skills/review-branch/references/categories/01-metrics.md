# 1. Metrics

**Applies to:** backend services only. The stack file says whether to skip (the
frontend stack skips this category).

Review all affected API endpoints to ensure sufficient metrics are published to
monitor:

- **Error rates** — discarded input count, exceptions thrown, error responses
  returned.
- **Load & performance** — latency, request count, queue length, throughput.

See the detected stack file for the concrete metrics library and conventions.
Record any gaps as findings per `../decision-framework.md`.
