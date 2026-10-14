#!/usr/bin/env bash
# Test pre-block-generated.sh. Run: bash .claude/hooks/pre-block-generated.test.sh
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$dir/pre-block-generated.sh"

fail=0

check() {
  local desc="$1" path="$2" want="$3"
  local payload out got
  payload=$(jq -n --arg f "$path" '{tool_input:{file_path:$f}}')
  out=$(printf '%s' "$payload" | bash "$script")
  if [[ -n "$out" ]]; then got=deny; else got=allow; fi
  if [[ "$got" != "$want" ]]; then
    echo "FAIL: $desc (path: $path) — want $want, got $got"
    fail=1
  else
    echo "PASS: $desc"
  fi
}

check ".env is denied"                 "/repo/.env"                              deny
check ".envrc is denied"               "/repo/.envrc"                            deny
check "local.env is denied"            "/repo/local.env"                         deny
check "nested .env.local is denied"    "/repo/services/x/.env.local"             deny
check ".env.dist is editable"          "/repo/.env.dist"                         allow
check "pb.go is denied"                "/repo/libs/proto/x.pb.go"                deny
check "mock_*.go is denied"            "/repo/services/x/mock_client.go"         deny
check "mocks dir is denied"            "/repo/services/x/mocks/client.go"        deny
check "sqlc dir is denied"             "/repo/services/x/sqlc/queries.sql.go"    deny
check "ordinary main.go is editable"   "/repo/services/x/main.go"                allow

exit "$fail"
