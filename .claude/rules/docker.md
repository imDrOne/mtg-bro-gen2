---
paths:
  - "docker-compose*.yml"
  - "**/Dockerfile*"
---

# Docker

- `docker-compose.dist.yml` — tracked template for the local dev stack; `task setup` copies it to `docker-compose.local.yml` (gitignored, machine-specific) on first checkout — adjust after that
- `docker-compose.local.yml` — your local dev stack, gitignored
- `docker-compose.prod.yml` — prod stack, tracked

All are empty scaffolds until services exist. Deployment topology (single
low-spec server, no k8s, DuckDNS domains, resource budget) — [docs/arch/deployment.md](../../docs/arch/deployment.md).
