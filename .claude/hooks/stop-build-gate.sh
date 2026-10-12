#!/usr/bin/env bash
# Stop: block "done" if the workspace doesn't build. Guards against self-certified completion.
input=$(cat)
active=$(echo "$input" | jq -r '.stop_hook_active // false')
[[ "$active" == "true" ]] && exit 0

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root" || exit 0

out=$(go build ./... 2>&1)
if [[ $? -ne 0 ]]; then
  reason=$(printf 'go build ./... failed — fix before claiming done:\n%s' "$out")
  jq -n --arg reason "$reason" '{decision:"block", reason:$reason}'
fi
exit 0
