#!/usr/bin/env bash
# Resolve a module argument to one or more module dirs, relative to repo root.
# "" -> every module (see list-modules.sh). Otherwise accepts a full module
# path ("services/deck") or a bare name ("deck") under services/ or libs/.
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$dir/../.."
module="${1:-}"

cd "$root"

if [[ -z "$module" ]]; then
  "$dir/list-modules.sh"
elif [[ -f "$module/go.mod" ]]; then
  echo "$module"
elif [[ -f "services/$module/go.mod" ]]; then
  echo "services/$module"
elif [[ -f "libs/$module/go.mod" ]]; then
  echo "libs/$module"
else
  echo "Unknown module: $module (not a module dir, and no services/libs match)" >&2
  exit 1
fi
