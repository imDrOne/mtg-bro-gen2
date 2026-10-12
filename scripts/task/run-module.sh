#!/usr/bin/env bash
# Run a service's main package. There's no root placeholder — the root
# go.mod is tool-only (golangci-lint/mockgen, per ADR-0001), nothing to run.
# Usage: run-module.sh <module>
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$dir/../.."
module="${1:-}"

cd "$root"

if [[ -z "$module" ]]; then
  echo "Usage: task run -- <module>  (e.g. task run -- deck)" >&2
  exit 1
elif [[ -f "$module/go.mod" ]]; then
  (cd "$module" && go run .)
elif [[ -f "services/$module/go.mod" ]]; then
  (cd "services/$module" && go run .)
elif [[ -f "libs/$module/go.mod" ]]; then
  (cd "libs/$module" && go run .)
else
  echo "Unknown module: $module" >&2
  exit 1
fi
