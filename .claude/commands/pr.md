---
description: Confirm the work is approved and open a PR against the parent branch.
argument-hint: '[base-branch]'
---

Work is approved — all good, go ahead and open a pull request.

Base branch: use `$ARGUMENTS` if given, otherwise `master` (this repo's
features branch from `master` — see `CLAUDE.md`'s Repo shape section).

Use the `superpowers:finishing-a-development-branch` skill, going straight
to "Push and create a Pull Request" against that base branch — don't
re-present the options menu or ask which option, the user already decided
by running this command. Still verify tests pass first (the skill's own
Step 1) before pushing.
