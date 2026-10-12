# Git hooks (`core.hooksPath`)

These are real git hooks (run by `git` itself for every commit, by anyone —
human or agent), not Claude Code hooks (`.claude/hooks/`, which only run
inside a Claude Code session). `.git/hooks/` isn't version-controlled, so
git has to be told to look here instead: `task setup` runs `git config
core.hooksPath .githooks` for you; manually it's the same command.

| Hook | What |
|---|---|
| [`commit-msg`](commit-msg) | Rejects a commit subject that isn't `type(scope)!: description` (Conventional Commits). See [CLAUDE.md#commit-messages](../CLAUDE.md#commit-messages) for the type list and rationale. Merge/revert/fixup!/squash! subjects are exempt. Bypass with `git commit --no-verify` (ask why first). |

Adding a hook here: same rule as `.claude/hooks/` — one script, one
responsibility, documented in this table and in CLAUDE.md if it encodes a
convention (not just a mechanical check).
