# Claude Code hooks

Shell scripts wired into `.claude/settings.json` (`hooks.*`). All of them
read the hook's JSON payload from stdin (`input=$(cat)`) and exit `0`
regardless of outcome unless noted — a non-blocking hook that exits
non-zero would surface as a spurious tool error, not a clean advisory.

Every hook here is a cheap, deterministic, same-turn check (tens of
milliseconds, no module-wide build/lint, no subagent) — see root
[CLAUDE.md](../../CLAUDE.md#claude-code-hooks) for why build/lint/doc
verification is deliberately kept out of hooks and lives on-demand
instead (`task build`/`test`/`lint`, the `/docs-sync` skill).

| Script | Event / matcher | Blocks? | What it does |
|---|---|---|---|
| [`post-gofmt.sh`](post-gofmt.sh) | `PostToolUse` / `Edit\|Write` | no | Runs `gofmt -w` on the touched file if it's `*.go`. |
| [`pre-block-destructive-bash.sh`](pre-block-destructive-bash.sh) | `PreToolUse` / `Bash` | **yes** | Denies recursive forced `rm` (any flag order/form), `git push --force`, `git reset --hard`, `DROP TABLE` (case-insensitive) via `permissionDecision: deny`. Splits the command on `;`/`&&`/`\|\|`/`\|`/`&` and checks each segment's command name + flags — read-only tools (`grep`, `cat`, `sed`, …) are exempt, so e.g. a `grep` over a migrations directory for a SQL keyword is allowed. |
| [`pre-block-generated.sh`](pre-block-generated.sh) | `PreToolUse` / `Edit\|Write` | **yes** | Denies edits to generated/managed files (`*.pb.go`, `mock_*.go`, `*/mocks/*`, `*_sqlc.go`, `*/sqlc/*`, `go.sum`) and env files (`.env`, `.env.*`, `*.env`, `.envrc`) — redirects to `task generate`/`buf generate`. Tracked `*.dist`/`*.dist.*` templates (bootstrapped by `task setup`) are explicitly exempt and stay editable. |

The following previously ran on `Stop` (every turn end, including
pure-conversation ones with no code written) and were removed for cost —
see [CLAUDE.md](../../CLAUDE.md#claude-code-hooks):

- **`stop-build-gate.sh`** — built every module unconditionally; its only
  guard was anti-recursion (`stop_hook_active`), not "did this turn change
  anything". Replaced by running `task build`/`test`/`lint` on demand (see
  [Verifying a change](../../CLAUDE.md#verifying-a-change)).
- **A `Stop`-event hook of `type: "agent"`** — an LLM subagent that gated
  on documentation staying in sync with the diff, spawned unconditionally
  every turn. Replaced by the [`docs-sync`](../skills/docs-sync/SKILL.md)
  skill (`/docs-sync`), invoked on demand instead of gated automatically.
- **`pre-nudge-task.sh`** (`PreToolUse`/`Bash`) — a stderr reminder to use
  `task build`/`test`/`vet`/`up`. It exited `0` after writing to stderr;
  a `PreToolUse` hook needs exit `2` for that to reach the model, so the
  nudge never actually arrived on any turn. The same guidance already
  lives in [CLAUDE.md](../../CLAUDE.md#task-runner) and
  [`go-linting.md`](../rules/go-linting.md), so nothing replaces it.
- **`post-lint-advisory.sh`** (`PostToolUse`/`Edit\|Write`) — ran a full
  `golangci-lint` on every single Go edit with no debounce. Redundant
  with the pinned `gopls-lsp` plugin, GoLand MCP's
  `get_file_problems`/`lint_files`, and `task lint`.

## Conventions for new hooks here

- One script, one responsibility — matches one row in the table above.
- Read the hook payload with `input=$(cat)` + `jq -r`, never assume
  argv — hook input always arrives as JSON on stdin.
- Blocking hooks emit
  `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"..."}}`
  via `jq -n`; everything else just writes to stderr and exits `0`.
- `chmod +x` the script and reference it from `.claude/settings.json` as
  `"$CLAUDE_PROJECT_DIR/.claude/hooks/<name>.sh"` — don't hardcode an
  absolute path.
- If the hook blocks, ship a `<name>.test.sh` next to it (see
  `pre-block-destructive-bash.test.sh` / `pre-block-generated.test.sh` for
  the shape) and run it as `bash .claude/hooks/<name>.test.sh` — don't
  paste destructive test strings into a live Bash call, the hook will
  deny its own test.
