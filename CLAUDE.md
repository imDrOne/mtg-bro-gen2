# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Skeleton Go module (`mtg-bto-gen2`, Go 1.27). Only `main.go` exists (prints "Hello world" via `log/slog`). No packages, tests, or microservices yet — architecture notes will be expanded here once the project idea is fixed.

## Repo shape

Monorepo for MTG-Bro: multiple Go microservices plus shared internal libraries (HTTP clients for external sources, pagination helpers, etc). Expect a structure like `services/<name>` for deployable services and `libs/<name>` (or `pkg/`) for shared code, added as they land — nothing exists yet beyond the module root.

- Origin: https://github.com/imDrOne/mtg-bro-gen2
- Default branch: `master`
- `gh` CLI is authenticated and usable for issues/PRs/repo ops.

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

## Testing stack

- Assertions: `github.com/stretchr/testify` (`assert`/`require`)
- Integration tests: `github.com/testcontainers/testcontainers-go`, gated behind the `integration` build tag (`//go:build integration`) so `task test` stays fast/Docker-free; run them with `task test:integration`
- Mocks: `go.uber.org/mock` — generate with `go tool mockgen` (registered as a `tool` dependency in `go.mod`, no global install needed), wire generation through `//go:generate` directives + `task generate`
- Architecture tests: not wired yet — no package boundaries exist to enforce. Once `services/<name>` / `libs/<name>` land, evaluate `go-arch-lint` (fe3dback) for declarative import-boundary checks between layers

These libs are pinned in `go.mod` ahead of any consumer code, so they currently show as unused/indirect. Don't run a bare `go mod tidy` until the first real test imports them, or it'll drop the requires — tidy right after wiring the first usage instead.

## Linting

`golangci-lint` v2 is a `tool` dependency in `go.mod` (Go 1.24+ tool directive, no separate global install). Config in `.golangci.yml`. Run via `task lint`, not a manually-installed binary — keeps the version pinned and reproducible across machines/CI.

## Docker

- `docker-compose.dist.yml` — tracked template for the local dev stack; copy to `docker-compose.local.yml` (gitignored, machine-specific) and adjust
- `docker-compose.local.yml` — your local dev stack, gitignored
- `docker-compose.prod.yml` — prod stack, tracked

All are empty scaffolds until services exist.

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