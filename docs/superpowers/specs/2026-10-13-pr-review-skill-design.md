# PR/MR review skill — design

## Problem

No repo convention for AI-driven code review of a PR/MR diff. Want a
command/skill that:

1. Prefers Codex (via the official `codex-plugin-cc` plugin) for review
   quality, when available on the machine.
2. Falls back to a fresh, context-naive Claude subagent when Codex isn't
   installed/authenticated — one that reads the diff and `CLAUDE.md` cold,
   the way a new contributor would.
3. Always runs a second, adversarial ("skeptic") pass that actively hunts
   for problems, regardless of which engine did the main pass.
4. Reports findings through the existing `ReportFindings` tool contract
   (severity-ranked, most-severe first).

## Mechanism: how Codex is actually invoked

The official plugin's slash commands (`/codex:review`,
`/codex:adversarial-review`) are thin wrappers:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" review "$ARGUMENTS"
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" adversarial-review "$ARGUMENTS"
node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs" setup --json
```

`${CLAUDE_PLUGIN_ROOT}` is a template variable Claude Code substitutes only
while expanding that plugin's *own* command text — a skill running outside
that expansion doesn't get it for free. Our skill resolves the script path
itself:

```bash
CODEX_SCRIPT=$(find ~/.claude/plugins/cache -path '*/codex/*/plugins/codex/scripts/codex-companion.mjs' 2>/dev/null | head -1)
```

If found, run `node "$CODEX_SCRIPT" setup --json` to confirm Codex CLI is
installed and authenticated. If that reports not-ready (or the script
isn't found at all — plugin not installed), the skill falls back to Claude
subagents for both passes. No separate wrapper around the Codex CLI is
built — we call the plugin's own script, nothing more.

## Components

### Dependency

Add to `.claude/settings.json`:

- `enabledPlugins`: `"codex@openai-codex": true`
- `extraKnownMarketplaces.openai-codex.source`: `{"source": "github", "repo": "openai/codex-plugin-cc"}`

Document in `CLAUDE.md` under "Claude Code plugins", following the
existing convention (entry + marketplace in the same change).

### Skill — `.claude/skills/pr-review/SKILL.md`

Auto-discoverable; description written so it self-triggers whenever the
agent is asked to review a PR/MR/diff/branch. Body carries the full flow
below (scope resolution → Codex probe → main pass → skeptic pass → merge
→ `ReportFindings`).

### Command alias — `.claude/commands/review.md`

```
/review [--base <ref>] [--pr <n>]
```

Thin: "Invoke the `pr-review` skill with these arguments." Exists for a
deterministic, discoverable manual trigger — the skill's auto-invocation
covers the "agent just realizes it should review" path.

### Subagents

- `.claude/agents/pr-reviewer-fresh.md` — fresh general-purpose agent,
  zero inherited context. Given only: repo path, resolved diff command,
  instruction to read root + relevant module `CLAUDE.md` and review as a
  new contributor would. Fallback tier for the **main** pass.
- `.claude/agents/pr-skeptic.md` — adversarial mindset: assume the code is
  broken, actively hunt for edge cases, concurrency bugs, security holes,
  missed validation, wrong assumptions. Never praises, no scope creep into
  style nits. Fallback tier for the **skeptic** pass, and reused verbatim
  (same prompt framing, as Codex's `focus` argument text) when Codex is
  available — see below.

## Flow

1. **Resolve scope.**
   - No args → working-tree diff (staged + unstaged), matching Codex
     plugin's default "auto" scope.
   - `--base <ref>` → diff against that ref (`git diff <ref>...HEAD`).
   - `--pr <n>` → `gh pr view <n> --json baseRefName` to get the base ref,
     then same as `--base`.
2. **Probe Codex** via the `find` + `setup --json` steps above.
3. **Main pass.**
   - Codex ready → `node "$CODEX_SCRIPT" review --base <ref> --wait`,
     capture stdout.
   - Not ready → spawn `pr-reviewer-fresh` with the resolved scope.
4. **Skeptic pass — always runs, second, regardless of path taken above.**
   - Codex ready → `node "$CODEX_SCRIPT" adversarial-review --base <ref> --wait "<skeptic focus text>"`.
   - Not ready → spawn `pr-skeptic` with the resolved scope.
5. **Merge and report.**
   - Codex output is free-text; the orchestrating agent reads it and
     extracts findings into the `ReportFindings` shape itself.
   - Subagent output is already structured (subagents are instructed to
     return findings in the same shape, not call `ReportFindings`
     themselves — only the orchestrator calls it, once).
   - Dedupe overlapping findings between the two passes (same file/line,
     same defect). Keep the more specific `failure_scenario`.
   - Tag skeptic-sourced findings with a `skeptic-` category prefix (e.g.
     `skeptic-security`, `skeptic-concurrency`) so they're distinguishable
     in the UI without a schema change.
   - Call `ReportFindings` once with the merged list, most-severe first.

## Error handling

- `gh pr view <n>` fails (bad PR number, `gh` not authenticated) → surface
  the error to the user, don't silently fall back to working-tree scope.
- Codex script found but `setup --json` errors (e.g. not logged in) →
  treat as "not ready", fall back for both passes, no retry loop.
- Codex review/adversarial-review process itself errors or times out →
  fall back to the corresponding subagent for that pass only (main and
  skeptic fail independently).

## Out of scope

- No CI integration — this is an interactively-triggered skill/command,
  not a pipeline step.
- No auto-posting of findings as PR/MR comments — output stays in-session
  via `ReportFindings`. Posting comments is a separate, later capability
  if ever wanted.
- No persistence of past review runs (no `reports/` directory a la the
  reference repo) — `ReportFindings` output is the artifact for this
  session only.

## Docs updates in the same change

- `CLAUDE.md` → "Claude Code plugins" section: add the `codex@openai-codex`
  row + marketplace note.
- `CLAUDE.md` → new short "Code review" section: names `/review`, the
  `pr-review` skill, and the two fallback agents; states the Codex-first/
  Claude-fallback policy and that the skeptic pass always runs.
