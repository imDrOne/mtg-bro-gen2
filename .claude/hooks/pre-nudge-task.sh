#!/usr/bin/env bash
# PreToolUse(Bash): advisory reminder to use Taskfile targets. Never blocks.
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty')

if echo "$cmd" | grep -Eq '(^|[;&|[:space:]])(go[[:space:]]+(build|test|vet)|docker[[:space:]]+compose)([[:space:]]|$)'; then
  if ! echo "$cmd" | grep -q 'cmd/migrate'; then
    echo "Reminder: prefer 'task build'/'task test'/'task vet'/'task up' over raw go/docker commands (see CLAUDE.md)." >&2
  fi
fi
exit 0
