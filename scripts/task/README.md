# Taskfile scripts

Shell helpers behind `Taskfile.yml`. `go.work` makes `./...` stop at module
boundaries (it only sees the root tooling module, silently skipping every
`services/*`/`libs/*`), so every multi-module task shells out to one of
these instead of inlining a loop in YAML.

| Script | Called from | What it does |
|---|---|---|
| [`list-modules.sh`](list-modules.sh) | `resolve-module.sh` (no args) | `find . -name go.mod` → every module dir that has at least one `*.go` file (`services/*` + `libs/*` once they exist), space-separated, one line. Excludes tool-only `go.mod`s — the root one exists purely for golangci-lint/mockgen's `tool` directives (ADR-0001) and has no code to build/test/vet/lint. Auto-discovers — no edit needed when a module is added. |
| [`resolve-module.sh`](resolve-module.sh) | `run-each.sh`, `run-module.sh` | Takes an optional module argument. Empty → delegates to `list-modules.sh` (every code module). Otherwise accepts a full path (`services/deck`) or a bare name (`deck`) and resolves it under `services/` or `libs/` — this explicit form works even for a tool-only module like `.`, since you asked for it by name. Exits 1 with a stderr message on an unknown module. |
| [`run-each.sh`](run-each.sh) | `task build\|test\|test:integration\|vet\|lint\|lint:fix\|generate` | `run-each.sh <module-or-empty> <cmd>` — resolves targets via `resolve-module.sh`, `cd`s into each and runs `cmd` (via `eval`), printing an `==> <dir>: <cmd>` banner per target. |
| [`run-module.sh`](run-module.sh) | `task run` | `run-module.sh <module>` — module is required (there's no root main package to fall back to); resolves to `services/<module>`/`libs/<module>` (or a full path) and runs `go run .` there. |

## Usage pattern

Every multi-module Taskfile task is a one-liner:

```yaml
build:
  cmds:
    - '{{.ROOT_DIR}}/scripts/task/run-each.sh "{{.CLI_ARGS}}" "go build -o ./bin/ ./..."'
```

`{{.CLI_ARGS}}` is whatever follows `--` on the command line, so:

```
task build                  # CLI_ARGS="" -> every module
task build -- deck          # CLI_ARGS="deck" -> only services/deck
task build -- services/deck # same, full path
```

`{{.ROOT_DIR}}` (Task's built-in var for the directory containing the root
`Taskfile.yml`) is used instead of a relative path so these resolve
correctly regardless of the directory `task` was invoked from.

## Conventions for new module-aware tasks

- Don't inline shell loops in `Taskfile.yml` — add/reuse a script here and
  call it as a one-liner, so the logic is testable (`./scripts/task/foo.sh
  args` directly) without going through `task`.
- Module resolution always goes through `resolve-module.sh` — don't
  re-implement the `services/`/`libs/` lookup elsewhere.
- Scripts are `set -euo pipefail` and resolve their own location via
  `BASH_SOURCE` so they work regardless of caller's cwd — keep new ones
  consistent with that.
