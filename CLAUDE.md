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

Transport conventions (gRPC/REST, ADR-0002), database conventions
(Postgres/sqlc/pgx, ADR-0004, migrations-as-sidecar, ADR-0003), and
distributed-systems patterns (outbox/Kafka/etc.) load on demand as
path-scoped rules — [`.claude/rules/transport.md`](.claude/rules/transport.md),
[`.claude/rules/database.md`](.claude/rules/database.md),
[`.claude/rules/go-patterns.md`](.claude/rules/go-patterns.md) — when
Claude touches a matching file, instead of loading in every session.

## Keeping docs in sync

Docs in `docs/arch/` and `services/*/CLAUDE.md` are routing aids for future
agents, not historical records — a doc that still describes the old shape
of something is worse than no doc, because it sends the next reader
somewhere wrong with full confidence. Before calling anything done: if the
change added/renamed/removed a service or library, changed a Kafka
topic/event schema, changed a REST/gRPC contract, adopted a new
distributed-systems pattern, or changed a DB/migration or dev-workflow
convention — update the doc that states it as fact, in the same change.
`docs/arch/services.md` is the source of truth for the service registry;
`overview.md`/`roadmap.md` follow it, not the other way around (see
[docs/arch/README.md](docs/arch/README.md)).

This is enforced, not just advisory: a `Stop` hook
(`.claude/settings.json`) runs a docs-sync check on every turn that ended
with uncommitted changes and blocks if a touched convention looks
undocumented or stale. If it blocks, fix the named doc(s) rather than
arguing with it or re-running to dodge it.

Planning artifacts from `superpowers:brainstorming`/`writing-plans`
(`docs/superpowers/specs/`, `docs/superpowers/plans/`) are scratch, not
permanent docs — delete them before finishing a branch
(`superpowers:finishing-a-development-branch` doesn't do this for you; it
has no repo-specific awareness). The durable record of what shipped and
why is the doc(s) this section already requires you to update in the
same change, plus the commit history/PR description — not a separate
plan file frozen at a point before implementation diverged from it.

## Claude Code hooks

Project-level hooks live in `.claude/settings.json` + `.claude/hooks/*.sh`,
committed so every contributor/agent gets them on checkout, not just
whoever configured them locally. Full table of what's wired up and why —
[.claude/hooks/README.md](.claude/hooks/README.md). Short version: `gofmt`
and an advisory `golangci-lint` run after every Go edit, a deny on
destructive Bash (`rm -rf`, `git push --force`, `git reset --hard`,
`DROP TABLE`), a deny on editing generated files (`*.pb.go`, `mock_*.go`,
sqlc output, `.env*`, `go.sum`) that redirects to `task generate`/`buf
generate`, a `Stop` gate that blocks if any module fails to build (loops
every `services/*`/`libs/*` module, not just the root), and the docs-sync
`Stop` hook described above.

Adding a new one: one script, one responsibility, in `.claude/hooks/`;
wire it into `.claude/settings.json` under the right event/matcher; add
its row to `.claude/hooks/README.md`'s table in the same change — an
undocumented hook is exactly the kind of drift the docs-sync hook above
exists to catch.

## Claude Code plugins

Project-required plugins are pinned in `.claude/settings.json`'s
`enabledPlugins` so every contributor gets the same baseline on checkout,
not whatever they happened to install globally:

- `superpowers@claude-plugins-official` — brainstorming, TDD,
  systematic-debugging, subagent-driven development; the default process
  skills for any non-trivial change in this repo.
- `plannotator@plannotator` — browser-based plan/code-review annotation UI.
- `modern-go-guidelines@goland-claude-marketplace` — see
  [Go style](#go-style) below; mandatory for all Go writes.
- `gopls-lsp@claude-plugins-official` — Go language server for code
  intelligence/refactoring; fallback for when the [GoLand MCP](#goland-mcp)
  server isn't reachable, better than raw `grep`.
- `codex@openai-codex` — OpenAI's official Codex bridge; used by the
  `pr-review` skill (see [Code review](#code-review)) as the preferred
  review engine when installed and authenticated.

`claude-plugins-official` is Anthropic's built-in marketplace (no extra
registration needed); non-built-in ones (`plannotator`,
`goland-claude-marketplace`, `openai-codex`) are also listed in
`extraKnownMarketplaces` in the same file — without that, a plugin pinned
in `enabledPlugins` fails to resolve for anyone who hasn't manually added
that marketplace before.

Adding a required plugin: add it to `enabledPlugins`, and if its
marketplace isn't `claude-plugins-official`, add the marketplace's
`source` to `extraKnownMarketplaces` too, in the same change — an
`enabledPlugins` entry with no matching `extraKnownMarketplaces` entry
works for you and silently does nothing for everyone else.

## Code review

`/review [--base <ref>] [--pr <n>] [msg...]` (or just asking to review a
PR/MR/diff/branch — the `pr-review` skill self-triggers) runs a two-pass
review: a main pass and an always-second adversarial "skeptic" pass that
actively hunts for problems regardless of what the main pass found.

Both passes prefer Codex (via the `codex@openai-codex` plugin above) when
it's installed and authenticated, and fall back to a fresh, context-naive
Claude subagent otherwise — `pr-reviewer-fresh` for the main pass,
`pr-skeptic` for the skeptic pass (`.claude/agents/`). Findings from both
passes are merged and reported once via `ReportFindings`, most-severe
first. See [`.claude/skills/pr-review/SKILL.md`](.claude/skills/pr-review/SKILL.md)
for the full flow.

## Pull requests

Every PR gets these set at creation (`gh pr create -a ... -l ... -m ...`)
or via `gh pr edit` right after if it was created without them:

- **Assignee**: the PR author — `gh pr create -a @me` unless told
  otherwise.
- **Labels**: at least one from `gh label list` matching the change's
  nature (`bug`, `documentation`, `enhancement`, etc. — same
  overall-impact judgment call as picking a commit type); add more if
  several genuinely apply.
- **Milestone**: attach the matching one (`gh api repos/{owner}/{repo}/milestones`,
  or cross-check `gh issue view <n>` for the issue this PR closes) when
  one of these holds: the issue this PR closes already has a milestone
  (inherit it), the user names one directly, or the work maps cleanly to
  a roadmap milestone (`docs/arch/roadmap.md`, M0–M7). Otherwise leave it
  unset — don't guess a milestone onto dev-tooling/agent-config work that
  doesn't map to any of them.

`/merge-pr [pr-number-or-branch]` squash-merges a PR with a commit
message composed from its real commits — never GitHub's default
"concatenate every commit subject" squash message.

## Commit messages

Subject line: **[Conventional Commits](https://www.conventionalcommits.org/)**
— `<type>(<scope>)!: <description>`. Scope and `!` (breaking change) are
optional; description is lowercase imperative, no trailing period.

Pick the type by the **overall impact of the change**, not by which file
you happened to touch last — a doc tweak made *while* fixing a bug is
still `fix`, not `docs`; a config change that's really enabling a new
capability is `feat`, not `chore`.

| Type | Use for |
|---|---|
| `feat` | new feature |
| `fix` | bug fix |
| `docs` | documentation only |
| `style` | formatting, no code change |
| `refactor` | code change that's neither a feat nor a fix |
| `perf` | performance improvement |
| `test` | adding/fixing tests |
| `build` | build system / dependencies |
| `ci` | CI config |
| `chore` | everything else (tooling, config, repo housekeeping) |
| `revert` | revert a previous commit |

Scope, when used, is the touched module/area (`feat(deck): ...`,
`fix(authenticator): ...`) — not enforced against a fixed list, just a
convention.

Examples: `feat(deck): add outbox relay for deck.saved`, `fix: nil pointer
in card search`, `feat(auth)!: require PKCE on the authorization_code
flow`.

**Enforced, not advisory**: `.githooks/commit-msg` rejects any subject
that doesn't match `type(scope)!: description` with one of the types
above (merge/revert/fixup!/squash! commits are exempt — git/rebase
generate those, not us). This is a real git hook, not a Claude Code hook —
it applies to every commit, by anyone, not just this agent — but it only
runs once `core.hooksPath` points at `.githooks`, which `task setup` does
for you. Bypass with `git commit --no-verify` only when you've actually
decided the check is wrong for this commit, not to dodge writing a proper
message.

Adding a new type to the allowed set: add it to the table above *and* to
the `pattern` regex in `.githooks/commit-msg` in the same change — one
without the other means the hook and the docs disagree. `task changelog`
(`conventional-changelog`, `conventionalcommits` preset) regenerates `CHANGELOG.md`
from these types since the last tag.

## Task runner

Use [Taskfile](https://taskfile.dev/) (`Taskfile.yml`), not raw go/docker commands, when a task exists:

- `task setup` — bootstrap local-only config from `.dist` templates (first-time setup)
- `task run -- <module>` — run a service's `main` package
- `task build` — build all modules
- `task test` — run unit tests
- `task test:integration` — run integration tests (testcontainers, needs Docker)
- `task vet` — vet code
- `task lint` / `task lint:fix` — golangci-lint
- `task generate` — `go generate ./...` (mocks, etc)
- `task up` / `task down` — local docker-compose stack

`go.work` makes `./...` stop at module boundaries (it only sees the root
module, silently skipping every `services/*`/`libs/*`), so `build`/`test`/
`test:integration`/`vet`/`lint`/`lint:fix`/`generate` auto-discover every
module that has Go code (via `find . -name go.mod`, filtered to dirs with
at least one `*.go` file — this excludes the root `go.mod`, which is
tool-only per ADR-0001 and has nothing to build/test/vet/lint) and loop
over them — no edit needed when a module is added. With no args they run
against every module; pass a module name or path after `--` to scope to
one. `task run` always needs a module — there's no root main package:

```
task build                  # every module
task build -- deck          # only services/deck
task build -- services/deck # same, full path
task run -- deck            # go run ./services/deck
```

Underlying commands per module (if `task` unavailable):

- Run: `go run .` (from inside the module dir)
- Build: `go build -o ./bin/ ./...`
- Test: `go test ./...`
- Vet: `go vet ./...`
- Lint: `go tool golangci-lint run ./...`

Testing stack, linting, Go style, and Docker conventions load on demand as
path-scoped rules — [`.claude/rules/go-testing.md`](.claude/rules/go-testing.md),
[`.claude/rules/go-linting.md`](.claude/rules/go-linting.md),
[`.claude/rules/go-style.md`](.claude/rules/go-style.md),
[`.claude/rules/docker.md`](.claude/rules/docker.md) — instead of loading
in every session regardless of what's being touched.

## Agent config: skills and rules per module

Two mechanisms let a `services/<name>` (or `libs/<name>`) module carry its own
agent-facing config, committed to the repo so every contributor/agent gets it
automatically on checkout — no separate install step:

- **Nested skills**: a `services/<name>/.claude/skills/<skill>/SKILL.md` is
  auto-discovered the moment an agent works with a file under that module —
  it doesn't need registering anywhere else. Use this for module-specific
  workflows (e.g. a deck import-format skill) instead of growing that
  module's `CLAUDE.md` indefinitely.
- **Rules files**: `.claude/rules/*.md` (root or per-module) load
  path-scoped supplementary instructions without bloating the main
  `CLAUDE.md`. Reach for this once a module's `CLAUDE.md` grows unwieldy or
  a rule only applies to a glob within that module.

Root-level rules already live in [`.claude/rules/`](.claude/rules/)
(transport, database, patterns, testing, linting, Go style, Docker — all
path-scoped). No module has a nested skill or its own `.claude/rules/`
yet — add the first one when a module actually needs module-scoped agent
guidance beyond what its `CLAUDE.md` holds, not preemptively.

## GoLand MCP

**MUST USE** the `goland` MCP tools (when the MCP server is reachable, see `.mcp.json`) instead of raw `grep`/text search — it's IDE-index-backed, not a text scan, so it's cheaper on tokens and more precise:

- `search_symbol` — semantic lookup by identifier (classes/methods/fields), not string matching
- `analyze_calls` — real call hierarchy (incoming/outgoing), strongly preferred over usage/text search for "who calls X"
- `get_symbol_info` — quick-doc for a symbol at a file position
- `search_text` / `search_regex` / `search_file` — indexed search with match coordinates when symbol tools don't fit
- `get_file_problems`, `lint_files`, `rename_refactoring`, `apply_patch` — IDE-native alternatives to manual edits/diagnostics

Fall back to `gopls-lsp` (pinned, see [Claude Code plugins](#claude-code-plugins))
for semantic lookups when GoLand MCP is unreachable, and to `grep`/`Grep`
only below that.

**Don't reach for `serena` here even if it's connected** — it's a
user-level MCP server (not part of this project's `.mcp.json`/
`extraKnownMarketplaces`, so it's not guaranteed present for every
contributor), and its own project config
(`.serena/project.yml`) already notes it defers to the JetBrains backend
when one's available — i.e. to GoLand MCP, the tool above. Using both for
the same "find/understand code" job doesn't add coverage, it just burns
context on two overlapping tool-choice instructions and (if actually
invoked) a second index of the same codebase.

## Worktrees

Don't create git worktrees nested inside this repo (e.g. `.claude/worktrees/`). Create them one level up, as a sibling directory of the repo root instead. Reason: GoLand (and other IDEs) index/watch the whole repo tree — a nested worktree duplicates the monorepo's content inside itself, and as the monorepo grows (multiple services + libs) that duplication is enough to make the IDE hang.

## Ignoring files

`.gitignore` covers standard Go build/test artifacts plus any `*.local*` / `.local/` paths for local-only overrides — use that convention for machine-specific config instead of `.env`-only patterns.

Machine-specific files that need a sane starting point (not just an empty
gap) are tracked as `<name>.dist.<ext>` and bootstrapped by `task setup`
(`scripts/setup-local.sh`) into their real, gitignored name on first
checkout — e.g. `docker-compose.dist.yml` → `docker-compose.local.yml`,
`.mcp.dist.json` → `.mcp.json`. It never overwrites a file that already
exists (use `task setup -- --force` to force it). Adding a new one — see
[scripts/README.md](scripts/README.md).
