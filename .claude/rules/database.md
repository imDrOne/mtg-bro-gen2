---
paths:
  - "**/migrations/**"
  - "**/*.sql"
  - "**/sqlc/**"
  - "**/cmd/migrate/**"
---

# Database conventions

- **One Postgres instance, one schema per service** — no service reads
  another service's schema directly; cross-service data access goes through
  gRPC. See [docs/arch/persistence.md](../../docs/arch/persistence.md).
- **sqlc for static queries, pgx (`pgxpool`) by hand for dynamic ones**
  (search filters, hybrid vector+text queries) — [ADR-0004](../../docs/arch/adr/0004-sqlc-plus-pgx.md).
  sqlc reads its schema straight from each service's `migrations/` directory;
  there is no separate copy of the DDL to keep in sync.
- **Migrations run as a separate sidecar mini-app, never on service startup.**
  Every service ships `cmd/migrate` (up/down/version/force/seed) alongside
  `cmd/server`, each with its own `Dockerfile`/`Dockerfile.migrate`. DB roles
  are split: `<svc>_migrator` (DDL) vs `<svc>_app` (DML). Full pattern,
  including the `build_migrations → run_migrations → deploy` CI contract —
  [ADR-0003](../../docs/arch/adr/0003-migrations-as-sidecar-job.md) and
  [docs/arch/persistence.md](../../docs/arch/persistence.md#миграционный-паттерн).
