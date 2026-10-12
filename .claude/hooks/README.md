# Claude Code hooks

Shell scripts wired into `.claude/settings.json` (`hooks.*`). All of them
read the hook's JSON payload from stdin (`input=$(cat)`) and exit `0`
regardless of outcome unless noted — a non-blocking hook that exits
non-zero would surface as a spurious tool error, not a clean advisory.

| Script | Event / matcher | Blocks? | What it does |
|---|---|---|---|
| [`post-gofmt.sh`](post-gofmt.sh) | `PostToolUse` / `Edit\|Write` | no | Runs `gofmt -w` on the touched file if it's `*.go`. |
| [`post-lint-advisory.sh`](post-lint-advisory.sh) | `PostToolUse` / `Edit\|Write` | no | Runs `golangci-lint run .` in the touched file's directory; prints findings to stderr as an advisory, never fails the turn. |
| [`pre-block-destructive-bash.sh`](pre-block-destructive-bash.sh) | `PreToolUse` / `Bash` | **yes** | Denies `rm -rf`, `git push --force`, `git reset --hard`, `DROP TABLE` (case-insensitive) via `permissionDecision: deny`. |
| [`pre-nudge-task.sh`](pre-nudge-task.sh) | `PreToolUse` / `Bash` | no | Prints a stderr reminder to use `task build`/`test`/`vet`/`up` instead of bare `go build`/`go test`/`docker compose` (skipped for commands containing `cmd/migrate`). |
| [`pre-block-generated.sh`](pre-block-generated.sh) | `PreToolUse` / `Edit\|Write` | **yes** | Denies edits to generated/managed files (`*.pb.go`, `mock_*.go`, `*/mocks/*`, `*_sqlc.go`, `*/sqlc/*`, `.env*`, `go.sum`) and redirects to `task generate`/`buf generate`. |
| [`stop-build-gate.sh`](stop-build-gate.sh) | `Stop` | **yes** | Runs `go build ./...` from `$CLAUDE_PROJECT_DIR`; blocks (`decision: block`) if the workspace doesn't build. Checks `stop_hook_active` first to avoid looping. |

There's also a `Stop`-event hook of `type: "agent"` configured directly in
`.claude/settings.json` (no script — it's a harness-run LLM prompt, see
that file) that gates on documentation staying in sync with the diff; see
[CLAUDE.md](../../CLAUDE.md#keeping-docs-in-sync).

## Conventions for new hooks here

- One script, one responsibility — matches one row in the table above.
- Read the hook payload with `input=$(cat)` + `jq -r`, never assume
  argv — hook input always arrives as JSON on stdin.
- Blocking hooks emit `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"..."}}`
  (`PreToolUse`) or `{"decision":"block","reason":"..."}` (`Stop`) via
  `jq -n`; everything else just writes to stderr and exits `0`.
- `chmod +x` the script and reference it from `.claude/settings.json` as
  `"$CLAUDE_PROJECT_DIR/.claude/hooks/<name>.sh"` — don't hardcode an
  absolute path.
