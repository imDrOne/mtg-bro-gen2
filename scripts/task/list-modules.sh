#!/usr/bin/env bash
# Every go.mod directory that actually has Go code: services/* + libs/* once
# they exist. Excludes tool-only go.mod's (e.g. the root one, which exists
# purely for golangci-lint/mockgen's `tool` directives per ADR-0001) since
# build/test/vet/lint/generate have nothing to do there. Uses `go list
# ./...` (not `find -name '*.go'`) so the check stays inside the module's
# own boundary instead of recursing into nested modules' directories. No
# edit needed when a module is added.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

find . -name 'go.mod' -not -path './.git/*' -exec dirname {} \; | sed 's|^\./||; s|^$|.|' | sort | while read -r d; do
  if [ -n "$(cd "$root/$d" && go list ./... 2>/dev/null)" ]; then
    printf '%s ' "$d"
  fi
done
