---
paths:
  - "libs/proto/**"
  - "**/*.proto"
  - "**/api/openapi.yaml"
---

# Transport conventions ([ADR-0002](../../docs/arch/adr/0002-grpc-internal-rest-external.md))

- **Service-to-service: gRPC.** Contracts live in `libs/proto`, generated via
  `buf`. Breaking changes get a new `v2` package alongside the old one.
- **Public-facing: REST + OpenAPI.** Each service with an external surface
  ships `api/openapi.yaml`.
- **mcp-gateway** speaks MCP to its clients — neither REST nor gRPC on that side.

Full contract rules (error format, gRPC-code-to-HTTP mapping, deadline
propagation, identity-in-metadata) — [docs/arch/api-contracts.md](../../docs/arch/api-contracts.md).
