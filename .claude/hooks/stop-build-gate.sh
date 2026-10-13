#!/usr/bin/env bash
# Stop: block "done" if the workspace doesn't build. Guards against self-certified completion.
input=$(cat)
active=$(echo "$input" | jq -r '.stop_hook_active // false')
[[ "$active" == "true" ]] && exit 0

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root" || exit 0

# go.work makes a plain `go build ./...` from the root stop at the root
# module (tool-only, nothing to build) — loop over every real module the
# same way `task build` does, or this gate silently never checks
# services/* or libs/*.
out=$(scripts/task/run-each.sh "" "go build -o /dev/null ./..." 2>&1)
if [[ $? -ne 0 ]]; then
  reason=$(printf 'go build failed in one or more modules — fix before claiming done:\n%s' "$out")
  jq -n --arg reason "$reason" '{decision:"block", reason:$reason}'
fi
exit 0
