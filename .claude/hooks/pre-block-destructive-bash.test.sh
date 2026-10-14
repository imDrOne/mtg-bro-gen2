#!/usr/bin/env bash
# Test pre-block-destructive-bash.sh. Run: bash .claude/hooks/pre-block-destructive-bash.test.sh
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$dir/pre-block-destructive-bash.sh"

fail=0

check() {
  local desc="$1" cmd="$2" want="$3"
  local payload out got
  payload=$(jq -n --arg c "$cmd" '{tool_input:{command:$c}}')
  out=$(printf '%s' "$payload" | bash "$script")
  if [[ -n "$out" ]]; then got=deny; else got=allow; fi
  if [[ "$got" != "$want" ]]; then
    echo "FAIL: $desc (cmd: $cmd) — want $want, got $got"
    fail=1
  else
    echo "PASS: $desc"
  fi
}

check "plain recursive forced rm"            'rm -rf build'                           deny
check "split flags: -r -f"                   'rm -r -f dir'                           deny
check "long flags: --recursive --force"      'rm --recursive --force dir'             deny
check "rm -rf as last segment, no trailing space" 'cd x && rm -rf'                      deny
check "rm -r without force stays allowed"    'rm -r dir'                              allow
check "grep mentioning drop table is allowed" 'grep -r "drop table" migrations/'        allow
check "psql running DROP TABLE is denied"    'psql -c "drop table users"'              deny
check "git push --force via -C flag"         'git -C sub push --force'                deny
check "git push --force-with-lease allowed"  'git push --force-with-lease'            allow
check "git reset --hard"                     'git reset --hard HEAD'                  deny
check "piped through xargs"                  'echo hi | xargs rm -rf'                 deny
check "harmless git status"                  'git status'                            allow
check "harmless ls"                          'ls -la'                                 allow

exit "$fail"
