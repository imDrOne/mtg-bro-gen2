#!/usr/bin/env bash
# PostToolUse(Edit|Write): advisory golangci-lint on the touched package. Never blocks.
input=$(cat)
file=$(echo "$input" | jq -r '.tool_input.file_path // .tool_response.filePath // empty')
[[ "$file" == *.go ]] || exit 0
dir=$(dirname "$file")
[[ -d "$dir" ]] || exit 0

out=$(cd "$dir" && go tool golangci-lint run . 2>&1)
if [[ -n "$out" ]]; then
  echo "golangci-lint advisory ($dir):" >&2
  echo "$out" >&2
fi
exit 0
