---
paths:
  - "**/*.go"
---

# Linting

`golangci-lint` v2 is a `tool` dependency in `go.mod` (Go 1.24+ tool directive, no separate global install). Config in `.golangci.yml`. Run via `task lint`, not a manually-installed binary — keeps the version pinned and reproducible across machines/CI.

Nothing lints automatically on edit — the per-edit advisory hook was removed (see root `CLAUDE.md`'s "Claude Code hooks"). Use GoLand MCP's `get_file_problems`/`lint_files` (or `gopls-lsp`) while editing, and `task lint` before finishing.
