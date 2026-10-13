#!/usr/bin/env bash
# Resolve /review-style arguments into a diff range, a Codex-compatible
# base ref, and a free-text focus message. Usage:
#   resolve-scope.sh [--base <ref>] [--pr <n>] [msg words...]
# Prints three lines to stdout:
#   DIFF_RANGE=<git diff range, or empty for working-tree scope>
#   BASE_REF=<ref to pass to Codex's --base, or empty for working-tree scope>
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
    --*)
      echo "resolve-scope.sh: unrecognized flag: $1" >&2
      exit 1
      ;;
    *)
      msg_parts+=("$1")
      shift
      ;;
  esac
done

diff_range=""
base_ref=""

if [[ -n "$pr" ]]; then
  read -r base_branch head_branch <<< "$(gh pr view "$pr" --json baseRefName,headRefName --jq '[.baseRefName, .headRefName] | @tsv')"
  git fetch origin "$base_branch" "$head_branch"
  diff_range="origin/${base_branch}...origin/${head_branch}"
  base_ref="origin/${base_branch}"
elif [[ -n "$base" ]]; then
  diff_range="${base}...HEAD"
  base_ref="$base"
fi

msg="${msg_parts[*]-}"

printf 'DIFF_RANGE=%s\n' "$diff_range"
printf 'BASE_REF=%s\n' "$base_ref"
printf 'MSG=%s\n' "$msg"
