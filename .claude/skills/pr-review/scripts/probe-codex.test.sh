#!/usr/bin/env bash
# Test probe-codex.sh. Run: bash .claude/skills/pr-review/scripts/probe-codex.test.sh
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$dir/probe-codex.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0

make_stub() {
  local path="$1" json="$2"
  cat > "$path" <<EOF
#!/usr/bin/env node
console.log(JSON.stringify($json));
EOF
}

check_ready() {
  local desc="$1" expected="$2" stub_json="$3"
  local stub="$tmp/codex-companion.mjs"
  make_stub "$stub" "$stub_json"
  local out ready
  out="$(CODEX_SCRIPT_OVERRIDE="$stub" "$script")"
  ready="$(printf '%s\n' "$out" | sed -n 's/^READY=//p')"
  if [[ "$ready" != "$expected" ]]; then
    echo "FAIL: $desc (expected READY=$expected, got READY=$ready)"
    fail=1
  else
    echo "PASS: $desc"
  fi
}

check_ready "ready true" "true" '{"ready": true}'
check_ready "ready false" "false" '{"ready": false}'

out="$(CODEX_SCRIPT_OVERRIDE="$tmp/does-not-exist.mjs" "$script")"
ready="$(printf '%s\n' "$out" | sed -n 's/^READY=//p')"
if [[ "$ready" != "false" ]]; then
  echo "FAIL: missing script -> not ready (got READY=$ready)"
  fail=1
else
  echo "PASS: missing script -> not ready"
fi

exit "$fail"
