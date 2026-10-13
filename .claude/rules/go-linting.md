---
paths:
  - "**/*.go"
---

# Linting

`golangci-lint` v2 is a `tool` dependency in `go.mod` (Go 1.24+ tool directive, no separate global install). Config in `.golangci.yml`. Run via `task lint`, not a manually-installed binary — keeps the version pinned and reproducible across machines/CI.
