---
name: pr-review
description: Use when asked to review a PR, MR, branch, or diff in this repo — runs a Codex-backed review when available, falls back to a fresh context-naive subagent otherwise, and always runs a second adversarial skeptic pass on top. Reports findings via ReportFindings, most-severe first.
---

# PR/MR Review

Two-pass review: a **main pass** (Codex if available, else a fresh
context-naive subagent) and an **always-on skeptic pass** (Codex's
adversarial-review if available, else an adversarial subagent). Findings
from both passes merge into a single `ReportFindings` call.

## 1. Parse arguments

Arguments arrive as trailing text on this skill's invocation:
`[--base <ref>] [--pr <n>] [msg...]`.

```bash
out="$(.claude/skills/pr-review/scripts/resolve-scope.sh <args>)"
DIFF_RANGE="$(printf '%s\n' "$out" | sed -n 's/^DIFF_RANGE=//p')"
MSG="$(printf '%s\n' "$out" | sed -n 's/^MSG=//p')"
```

If this step errors (e.g. `--pr` given a bad number, or `gh` not
authenticated), surface the error to the user directly — do not silently
fall back to working-tree scope.

## 2. Probe Codex

```bash
out="$(.claude/skills/pr-review/scripts/probe-codex.sh)"
CODEX_SCRIPT="$(printf '%s\n' "$out" | sed -n 's/^CODEX_SCRIPT=//p')"
READY="$(printf '%s\n' "$out" | sed -n 's/^READY=//p')"
```

## 3. Main pass

- `READY=true`: run
  ```bash
  node "$CODEX_SCRIPT" review ${DIFF_RANGE:+--base "$DIFF_RANGE"} --wait
  ```
  (omit `--base` entirely when `DIFF_RANGE` is empty — plain working-tree
  review). Capture stdout. Read it yourself and extract findings into the
  shape below — Codex's own review output is free text, not JSON.
  If this process errors or times out, fall back to the subagent path
  below for this pass only; do not fall back for the skeptic pass too.
- `READY=false`: spawn a fresh agent via the `Agent` tool with
  `subagent_type: "pr-reviewer-fresh"` (not a fork — it must start with
  zero inherited context). Give it, in the prompt: the repo root path,
  the diff command (`git diff $DIFF_RANGE` if `DIFF_RANGE` is set, else
  plain `git diff`), and `$MSG` as extra context if non-empty. It returns
  findings already in the target shape (see Task 3's agent definition) —
  no extraction needed on your end.

Finding shape (for the Codex-output-extraction case): `{file, line,
summary, failure_scenario, category, short_summary}`.

## 4. Skeptic pass — always, after step 3, regardless of which path it took

Build the focus text:
```
FOCUS="Assume this change is broken. Hunt for edge cases, concurrency bugs, security holes, missed validation, and whether this is even the right approach."
if [[ -n "$MSG" ]]; then
  FOCUS="$FOCUS; focus: $MSG"
fi
```

- `READY=true`: run
  ```bash
  node "$CODEX_SCRIPT" adversarial-review ${DIFF_RANGE:+--base "$DIFF_RANGE"} --wait "$FOCUS"
  ```
  Extract findings the same way as the main pass. If this process errors
  or times out, fall back to the subagent path below for this pass only.
- `READY=false`: spawn `subagent_type: "pr-skeptic"` with the repo root
  path, the same diff command as step 3, and `$FOCUS` as the focus text.

## 5. Merge and report

- Collect findings from both passes into one list.
- For every finding sourced from the skeptic pass, ensure its `category`
  starts with `skeptic-` — prefix it if it doesn't already (Codex's free-text
  adversarial-review output won't have a `category` of its own; the
  `pr-skeptic` subagent already self-prefixes, so don't double-prefix
  there).
- Dedupe: when a main-pass and skeptic-pass finding share the same `file`
  and overlapping `line` and describe the same defect, keep one entry —
  prefer whichever has the more specific `failure_scenario`.
- Call `ReportFindings` once with the merged list, most-severe first.
  Empty array if nothing survived.
