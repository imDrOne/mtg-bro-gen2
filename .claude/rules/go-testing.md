---
paths:
  - "**/*.go"
---

# Testing stack

- Assertions: `github.com/stretchr/testify` (`assert`/`require`)
- Integration tests: `github.com/testcontainers/testcontainers-go`, gated behind the `integration` build tag (`//go:build integration`) so `task test` stays fast/Docker-free; run them with `task test:integration`
- Mocks: `go.uber.org/mock` — generate with `go tool mockgen` (registered as a `tool` dependency in `go.mod`, no global install needed), wire generation through `//go:generate` directives + `task generate`
- Architecture boundaries: `go-arch-lint` enforces import rules between `internal/` packages and between `services/*`/`libs/*` — wired in as part of M0 once package boundaries exist.
