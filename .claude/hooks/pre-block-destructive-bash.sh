#!/usr/bin/env bash
# PreToolUse(Bash): deny destructive commands outright.
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty')

if echo "$cmd" | grep -Eqi 'rm[[:space:]]+(-[a-z]*r[a-z]*f[a-z]*|-[a-z]*f[a-z]*r[a-z]*)[[:space:]]|git[[:space:]]+push[[:space:]]+(--force|-f)\b|git[[:space:]]+reset[[:space:]]+--hard|drop[[:space:]]+table'; then
  reason="Blocked destructive command ('rm -rf' / 'git push --force' / 'git reset --hard' / 'DROP TABLE'). Ask the user to run it manually if it's really needed."
  jq -n --arg reason "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
fi
exit 0
