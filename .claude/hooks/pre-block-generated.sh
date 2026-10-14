#!/usr/bin/env bash
# PreToolUse(Edit|Write): deny edits to generated/managed files, redirect to the regen command.
input=$(cat)
file=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[[ -n "$file" ]] || exit 0
base=$(basename "$file")

reason=""
case "$file" in
  *.pb.go) reason="Generated protobuf stub — regenerate via 'buf generate', don't hand-edit." ;;
  *_sqlc.go) reason="Generated sqlc file — regenerate via 'task generate', don't hand-edit." ;;
  */go.sum|go.sum) reason="go.sum is managed by 'go mod tidy'/'go build', don't hand-edit." ;;
esac

if [[ -z "$reason" ]]; then
  case "$base" in
    mock_*.go) reason="Generated mock — regenerate via 'task generate' (mockgen), don't hand-edit." ;;
    # Tracked templates (task setup bootstraps these) stay editable —
    # must come before the env arm below, case takes the first match.
    *.dist|*.dist.*) ;;
    .env|.env.*|*.env|.envrc|.envrc.*) reason="Env file — not managed by agent edits." ;;
  esac
fi

if [[ -z "$reason" ]]; then
  case "$file" in
    */mocks/*) reason="Generated mocks directory — regenerate via 'task generate', don't hand-edit." ;;
    */sqlc/*) reason="sqlc-managed directory — regenerate via 'task generate', don't hand-edit." ;;
  esac
fi

if [[ -n "$reason" ]]; then
  jq -n --arg reason "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
fi
exit 0
