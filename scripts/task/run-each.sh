#!/usr/bin/env bash
# Run CMD in every module (or just MODULE, if given), cd'd into each one.
# Usage: run-each.sh <module-or-empty> <cmd>
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$dir/../.."
module="${1:-}"
cmd="${2:?run-each.sh: missing CMD argument}"

targets="$("$dir/resolve-module.sh" "$module")"

cd "$root"
for m in $targets; do
  echo "==> $m: $cmd"
  (cd "$m" && eval "$cmd")
done
