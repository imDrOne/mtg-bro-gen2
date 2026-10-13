#!/usr/bin/env bash
# Test resolve-scope.sh. Run: bash .claude/skills/pr-review/scripts/resolve-scope.test.sh
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$dir/resolve-scope.sh"

fail=0

check() {
  local desc="$1" expected="$2"
  shift 2
  local actual
  actual="$("$script" "$@")"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: $desc"
    echo "  expected:"
    echo "$expected"
    echo "  actual:"
    echo "$actual"
    fail=1
  else
    echo "PASS: $desc"
  fi
}

check "no args -> empty range, empty msg" \
  $'DIFF_RANGE=\nMSG='

check "--base only -> range set, empty msg" \
  $'DIFF_RANGE=master...HEAD\nMSG=' \
  --base master

check "--base plus trailing msg -> both set" \
  $'DIFF_RANGE=master...HEAD\nMSG=check auth paths' \
  --base master check auth paths

exit "$fail"
