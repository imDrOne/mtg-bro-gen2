---
description: Squash-merge a PR with a concise commit message composed from its actual commits, not GitHub's default commit-list concatenation.
argument-hint: '[pr-number-or-branch]'
---

Squash-merge the PR for `$ARGUMENTS` (or the current branch's PR if no
argument) into its base branch.

1. Resolve the target and read its real commits — don't use GitHub's
   default squash message (every commit subject concatenated as a
   bullet list):
   ```bash
   gh pr view $ARGUMENTS --json number,title,baseRefName,commits
   ```
2. Compose the merge commit from `.commits[].messageHeadline` +
   `.commits[].messageBody`:
   - **Subject**: one Conventional Commits line (`type(scope):
     description`) capturing the PR's overall impact — same
     overall-impact judgment call as picking a commit type (see
     `CLAUDE.md`'s Commit messages section), not just the first or last
     commit's subject.
   - **Body**: a short, deduplicated summary grouped by theme (roughly
     2-6 bullets). Drop commits that are pure fixups of an earlier
     commit in the same PR (e.g. a `fix(review): ...` that corrects an
     issue a review caught two commits earlier in the same PR) into the
     bullet about that feature — don't give the fixup its own line.
3. Show the composed subject + body to the user before merging —
   squash-merging to the base branch is hard to reverse.
4. Merge:
   ```bash
   gh pr merge <number> --squash -t "<subject>" -b "<body>"
   ```
   Don't pass `--delete-branch` unless asked.
