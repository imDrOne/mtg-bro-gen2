#!/usr/bin/env bash
# Bootstrap machine-local config files from their tracked .dist templates.
# Never overwrites a file that already exists — local overrides are
# per-machine and may have been hand-edited. Pass --force to overwrite.
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$dir"

force=false
if [[ "${1:-}" == "--force" ]]; then
  force=true
fi

# "dist file:local file" pairs. Add new ones here, not by inventing a
# second naming convention.
pairs=(
  "docker-compose.dist.yml:docker-compose.local.yml"
  ".mcp.dist.json:.mcp.json"
)

for pair in "${pairs[@]}"; do
  src="${pair%%:*}"
  dst="${pair##*:}"

  if [[ ! -f "$src" ]]; then
    echo "skip: $src not found" >&2
    continue
  fi

  if [[ -f "$dst" && "$force" == false ]]; then
    echo "skip: $dst already exists (use --force to overwrite)"
    continue
  fi

  cp "$src" "$dst"
  echo "wrote: $dst (from $src)"
done

echo
echo "Note: .mcp.json's goland entry uses a placeholder port — GoLand writes" >&2
echo "its real MCP server port there once its MCP server starts for this" >&2
echo "project; adjust by hand if it doesn't get overwritten automatically." >&2

# git config, not a file — always (re-)applied, not gated by --force. This
# is a repo-wide convention (commit-msg Conventional Commits check, see
# CLAUDE.md), not a per-machine preference to leave alone once set.
git config core.hooksPath .githooks
echo "set: git config core.hooksPath .githooks (commit-msg Conventional Commits check)"
