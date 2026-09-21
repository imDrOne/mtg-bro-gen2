# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

MTG-Bro: a platform for building Magic: The Gathering decks — deck building
with business-rule validation, combo/insight recommendations, community
article insights, and AI-agent deck assembly via an MCP server that plugs
into Claude, ChatGPT, etc. Full system architecture, service registry, and
implementation roadmap live in [docs/arch/](docs/arch/README.md) — read
`docs/arch/README.md` first when working on anything cross-service.

## Repo shape

Monorepo, **multi-module** ([ADR-0001](docs/arch/adr/0001-multi-module-go-workspace.md)):
every service and shared library is its own Go module, tied together by a
root `go.work` for local development.

```
go.work
services/<name>/     # deployable services, each its own go.mod + CLAUDE.md
libs/<name>/         # shared libraries, each its own go.mod
docs/arch/           # cross-service architecture docs + ADRs
```

**Before starting work on a milestone or service, check open GitHub issues**
(`gh issue list --milestone "<name>"` or `gh issue list`) — they are the
live task breakdown (one issue per roadmap milestone M0–M7, checkboxes
inside), not just `docs/arch/roadmap.md`. Tick off checkboxes / close the
issue as work lands; if the checklist has drifted from what actually needs
doing, edit the issue rather than silently ignoring it.

Current service registry (owner, DB schema, Kafka topics, status): [docs/arch/services.md](docs/arch/services.md).
**When adding, renaming, or removing a service, update that registry first** —
`docs/arch/overview.md` and `docs/arch/roadmap.md` follow it, not the other
way around. Each service gets its own `CLAUDE.md` under `services/<name>/`
with service-specific business logic, contracts, and invariants; this file
stays about the repo as a whole.

- Origin: https://github.com/imDrOne/mtg-bro-gen2
- Default branch: `master`
- `gh` CLI is authenticated and usable for issues/PRs/repo ops.

## Go modules and workspace

- `go.work` lists every `services/*` and `libs/*` module — run `go build`,
  `go test`, `go vet` from the repo root and they resolve across the whole
  workspace without `replace` directives.
- `libs/*` are versioned independently via git tags, e.g. `libs/scryfall/v0.1.0`.
  Services pin a specific version in their `go.mod`, not "whatever's on disk" —
  bumping a shared library requires an explicit version bump in each consumer.
- The root `go.mod` (tool dependencies: golangci-lint, mockgen) is repo
  tooling, not a library or service module — leave it as is.

## Transport conventions ([ADR-0002](docs/arch/adr/0002-grpc-internal-rest-external.md))

- **Service-to-service: gRPC.** Contracts live in `libs/proto`, generated via
  `buf`. Breaking changes get a new `v2` package alongside the old one.
- **Public-facing: REST + OpenAPI.** Each service with an external surface
  ships `api/openapi.yaml`.
- **mcp-gateway** speaks MCP to its clients — neither REST nor gRPC on that side.

Full contract rules (error format, gRPC-code-to-HTTP mapping, deadline
propagation, identity-in-metadata) — [docs/arch/api-contracts.md](docs/arch/api-contracts.md).

## Database conventions

- **One Postgres instance, one schema per service** — no service reads
  another service's schema directly; cross-service data access goes through
  gRPC. See [docs/arch/persistence.md](docs/arch/persistence.md).
- **sqlc for static queries, pgx (`pgxpool`) by hand for dynamic ones**
  (search filters, hybrid vector+text queries) — [ADR-0004](docs/arch/adr/0004-sqlc-plus-pgx.md).
  sqlc reads its schema straight from each service's `migrations/` directory;
  there is no separate copy of the DDL to keep in sync.
- **Migrations run as a separate sidecar mini-app, never on service startup.**
  Every service ships `cmd/migrate` (up/down/version/force/seed) alongside
  `cmd/server`, each with its own `Dockerfile`/`Dockerfile.migrate`. DB roles
  are split: `<svc>_migrator` (DDL) vs `<svc>_app` (DML). Full pattern,
  including the `build_migrations → run_migrations → deploy` CI contract —
  [ADR-0003](docs/arch/adr/0003-migrations-as-sidecar-job.md) and
  [docs/arch/persistence.md](docs/arch/persistence.md#миграционный-паттерн).

## Distributed-systems patterns

Patterns (rate limiting, circuit breaker, outbox, singleflight, task leasing,
token budgets, DLQ, etc.) are adopted only where a service has a concrete
need for them — never added just for practice. The full map, with the
specific problem each pattern solves and what's deliberately *not* used, is
[docs/arch/patterns.md](docs/arch/patterns.md). Check it before reaching for
a pattern in new code.

## Task runner

Use [Taskfile](https://taskfile.dev/) (`Taskfile.yml`), not raw go/docker commands, when a task exists:

- `task run` — run main package
- `task build` — build all modules
- `task test` — run unit tests
- `task test:integration` — run integration tests (testcontainers, needs Docker)
- `task vet` — vet code
- `task lint` / `task lint:fix` — golangci-lint
- `task generate` — `go generate ./...` (mocks, etc)
- `task up` / `task down` — local docker-compose stack

Underlying commands (if `task` unavailable):

- Run: `go run main.go`
- Build: `go build ./...`
- Test: `go test ./...`
- Vet: `go vet ./...`
- Lint: `go tool golangci-lint run ./...`

Taskfile targets go module-aware as `services/*`/`libs/*` land (M0) — expect
`build`/`test`/`vet` to iterate modules rather than run a single `./...` once
there's more than the root module.

## Testing stack

- Assertions: `github.com/stretchr/testify` (`assert`/`require`)
- Integration tests: `github.com/testcontainers/testcontainers-go`, gated behind the `integration` build tag (`//go:build integration`) so `task test` stays fast/Docker-free; run them with `task test:integration`
- Mocks: `go.uber.org/mock` — generate with `go tool mockgen` (registered as a `tool` dependency in `go.mod`, no global install needed), wire generation through `//go:generate` directives + `task generate`
- Architecture boundaries: `go-arch-lint` enforces import rules between `internal/` packages and between `services/*`/`libs/*` — wired in as part of M0 once package boundaries exist.

## Linting

`golangci-lint` v2 is a `tool` dependency in `go.mod` (Go 1.24+ tool directive, no separate global install). Config in `.golangci.yml`. Run via `task lint`, not a manually-installed binary — keeps the version pinned and reproducible across machines/CI.

## Docker

- `docker-compose.dist.yml` — tracked template for the local dev stack; copy to `docker-compose.local.yml` (gitignored, machine-specific) and adjust
- `docker-compose.local.yml` — your local dev stack, gitignored
- `docker-compose.prod.yml` — prod stack, tracked

All are empty scaffolds until services exist. Deployment topology (single
low-spec server, no k8s, DuckDNS domains, resource budget) — [docs/arch/deployment.md](docs/arch/deployment.md).

## Go style

**MUST USE** the `modern-go-guidelines` plugin skill (`use-modern-go`) for all Go code writes/edits/refactors — it encodes [JetBrains: Help AI coding agents write up-to-date Go](https://blog.jetbrains.com/go/2026/08/24/help-ai-coding-agents-write-up-to-date-code-with-modern-golang-skills/): favor current stdlib idioms over outdated patterns an LLM may default to (e.g. `slog` over third-party loggers, `min`/`max` builtins, range-over-func where fitting, current error-handling conventions).

## GoLand MCP

**MUST USE** the `goland` MCP tools (when the MCP server is reachable, see `.mcp.json`) instead of raw `grep`/text search — it's IDE-index-backed, not a text scan, so it's cheaper on tokens and more precise:

- `search_symbol` — semantic lookup by identifier (classes/methods/fields), not string matching
- `analyze_calls` — real call hierarchy (incoming/outgoing), strongly preferred over usage/text search for "who calls X"
- `get_symbol_info` — quick-doc for a symbol at a file position
- `search_text` / `search_regex` / `search_file` — indexed search with match coordinates when symbol tools don't fit
- `get_file_problems`, `lint_files`, `rename_refactoring`, `apply_patch` — IDE-native alternatives to manual edits/diagnostics

Fall back to `grep`/`Grep` tool only if the MCP server is unavailable.

## Worktrees

Don't create git worktrees nested inside this repo (e.g. `.claude/worktrees/`). Create them one level up, as a sibling directory of the repo root instead. Reason: GoLand (and other IDEs) index/watch the whole repo tree — a nested worktree duplicates the monorepo's content inside itself, and as the monorepo grows (multiple services + libs) that duplication is enough to make the IDE hang.

## Ignoring files

`.gitignore` covers standard Go build/test artifacts plus any `*.local*` / `.local/` paths for local-only overrides — use that convention for machine-specific config instead of `.env`-only patterns.
