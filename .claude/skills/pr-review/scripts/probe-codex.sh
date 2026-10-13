#!/usr/bin/env bash
# Detect whether the Codex plugin's CLI bridge (codex-companion.mjs) is
# installed and ready to use. Prints two lines to stdout:
#   CODEX_SCRIPT=<path, or empty if not found>
#   READY=true|false
# Set CODEX_SCRIPT_OVERRIDE to skip the `find` and point at a specific
# script directly (used by tests, and as a manual escape hatch).
set -uo pipefail

script_path="${CODEX_SCRIPT_OVERRIDE:-}"
if [[ -z "$script_path" ]]; then
  script_path="$(find "${HOME}/.claude/plugins/cache" -path '*/codex/*/plugins/codex/scripts/codex-companion.mjs' 2>/dev/null | head -1)"
fi

ready=false
if [[ -n "$script_path" && -f "$script_path" ]]; then
  output="$(node "$script_path" setup --json 2>/dev/null)"
  if [[ -n "$output" ]]; then
    if node -e 'const d=JSON.parse(require("fs").readFileSync(0,"utf8")); process.exit(d.ready?0:1)' <<< "$output" 2>/dev/null; then
      ready=true
    fi
  fi
fi

printf 'CODEX_SCRIPT=%s\n' "$script_path"
printf 'READY=%s\n' "$ready"
