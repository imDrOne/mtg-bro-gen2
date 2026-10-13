#!/usr/bin/env bash
# Resolve /review-style arguments into a diff range and a free-text focus
# message. Usage: resolve-scope.sh [--base <ref>] [--pr <n>] [msg words...]
# Prints two lines to stdout:
#   DIFF_RANGE=<git diff range, or empty for working-tree scope>
#   MSG=<trailing free text, or empty>
set -euo pipefail

base=""
pr=""
msg_parts=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      base="$2"
      shift 2
      ;;
    --pr)
      pr="$2"
      shift 2
      ;;
    *)
      msg_parts+=("$1")
      shift
      ;;
  esac
done

if [[ -n "$pr" ]]; then
  base="$(gh pr view "$pr" --json baseRefName --jq .baseRefName)"
fi

diff_range=""
if [[ -n "$base" ]]; then
  diff_range="${base}...HEAD"
fi

msg="${msg_parts[*]-}"

printf 'DIFF_RANGE=%s\n' "$diff_range"
printf 'MSG=%s\n' "$msg"
