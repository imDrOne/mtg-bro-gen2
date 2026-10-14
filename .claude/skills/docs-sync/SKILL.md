---
name: docs-sync
description: Use when finishing a change in this repo, or when asked whether docs are up to date — checks the diff against docs/arch/*.md, docs/arch/adr/*.md, root CLAUDE.md and services/*/CLAUDE.md, and updates whatever the change made stale. Replaces the old automatic Stop-hook docs gate.
---

# Docs sync

There is no automatic gate for this anymore — a `Stop` hook used to run this
check on every turn, including conversation-only ones, which was exactly the
cost problem that got it removed (see root `CLAUDE.md`'s "Claude Code hooks"
section). This skill is the on-demand replacement: invoke it yourself before
calling a change done, or it self-triggers when asked whether docs are
current.

## 1. Resolve scope

Scope is **what this change touched**, not what's currently uncommitted —
that distinction was the old hook's bug; a dirty mid-feature tree is not the
same thing as "changed by this turn".

- No arguments: the working tree.
  ```bash
  git status --porcelain
  git diff HEAD
  ```
- `--base <ref>`: the whole branch since it diverged.
  ```bash
  git diff <ref>...HEAD --stat
  git diff <ref>...HEAD
  ```
- Explicit `paths...`: narrow either of the above to just those paths.

## 2. Early exit

If the diff is empty, or every changed file is test-only, comment-only, or
already under `docs/`, say "docs in sync" in one line and stop. Don't read
the architecture docs just to confirm a no-op.

## 3. The doc map

| If the change… | the doc that states it as fact is |
|---|---|
| adds / renames / removes a service or library | `docs/arch/services.md` — **registry source of truth, check first**; `overview.md`/`roadmap.md` follow it, never the reverse |
| adds or changes a Kafka topic, key, or event schema | `docs/arch/messaging.md` |
| adds or changes a REST/gRPC endpoint, version, or error shape | `docs/arch/api-contracts.md` |
| adopts a new distributed-systems pattern (outbox, DLQ, saga…) | `docs/arch/patterns.md` |
| changes a DB schema, role, sqlc layout, or migration convention | `docs/arch/persistence.md` |
| changes a Taskfile target, hook, plugin, or dev-workflow convention | root `CLAUDE.md` (+ `.claude/hooks/README.md` / `.githooks/README.md` if a hook changed) |
| changes service-specific business logic, contracts, or invariants | that service's `services/<name>/CLAUDE.md` |
| makes or reverses an architectural decision | a new or superseding `docs/arch/adr/NNNN-*.md` |

`docs/arch/README.md` holds the authoritative file→topic map — if a changed
area isn't in the table above (e.g. observability, security, deployment),
consult it rather than guessing.

**`docs/arch/` prose is in Russian — match the surrounding document's
language.** Don't inject English paragraphs into a Russian doc.

## 4. Act, don't report

Unlike the dying hook, which could only block with a list of stale files,
this skill makes the edits in the same turn, then prints one line per
changed doc. The standard to meet is the repo's own principle (root
`CLAUDE.md`, "Keeping docs in sync"): a doc that still describes the old
shape of something is worse than no doc — it sends the next reader
somewhere wrong with full confidence.

Planning artifacts under `docs/superpowers/` are scratch, not docs — delete
them if found stale, don't try to sync them.
