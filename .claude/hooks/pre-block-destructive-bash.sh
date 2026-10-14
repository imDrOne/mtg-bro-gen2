#!/usr/bin/env bash
# PreToolUse(Bash): deny destructive commands outright.
# Checks each ;/&&/||/|/& segment separately, keyed on the segment's
# command name and its flag tokens — not a substring grep over the whole
# command, which both missed split flags (`rm -r -f`) and false-positived
# on commands that merely mention a pattern (`grep -r "drop table" x/`).
set -eo pipefail
# No `set -u`: macOS ships bash 3.2, where "${arr[@]}" on an empty array
# throws "unbound variable" even though the array is legitimately empty.
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[[ -n "$cmd" ]] || exit 0

deny() {
  jq -n --arg reason "Blocked destructive command ($1). Ask the user to run it manually if it's really needed." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
}

has_token() {
  local needle="$1"
  shift
  local t
  for t in "$@"; do
    [[ "$t" == "$needle" ]] && return 0
  done
  return 1
}

# Read-only tools: their *arguments* are data, not commands to evaluate.
# This is what keeps `grep -r "drop table" migrations/` allowed.
is_readonly_tool() {
  case "$1" in
    grep|egrep|fgrep|rg|ag|ack|cat|head|tail|less|more|awk|sed|echo|printf|jq|yq|wc|sort|uniq|diff|ls|tree|bat|man) return 0 ;;
    *) return 1 ;;
  esac
}

segments=$(printf '%s' "$cmd" | sed -E 's/(\|\||&&|[;|&])/\n/g')

while IFS= read -r seg; do
  [[ -n "${seg//[[:space:]]/}" ]] || continue
  read -ra toks <<< "$seg"
  [[ ${#toks[@]} -gt 0 ]] || continue

  # Skip leading VAR=val assignments and transparent wrappers.
  i=0
  while [[ $i -lt ${#toks[@]} ]]; do
    case "${toks[$i]}" in
      *=*|sudo|command|env|time|nohup|xargs) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  [[ $i -lt ${#toks[@]} ]] || continue
  argv0=$(basename -- "${toks[$i]}")
  args=("${toks[@]:$((i + 1))}")

  if is_readonly_tool "$argv0"; then
    continue
  fi

  if [[ "$argv0" == rm ]]; then
    rec=0 force=0
    for a in "${args[@]}"; do
      case "$a" in
        --recursive) rec=1 ;;
        --force) force=1 ;;
        --*) ;;
        -*)
          [[ "$a" == *r* || "$a" == *R* ]] && rec=1
          [[ "$a" == *f* ]] && force=1
          ;;
      esac
    done
    [[ $rec -eq 1 && $force -eq 1 ]] && deny "recursive forced rm"
  fi

  if [[ "$argv0" == git ]]; then
    if has_token push "${args[@]}" && { has_token --force "${args[@]}" || has_token -f "${args[@]}"; }; then
      deny "git push --force"
    fi
    if has_token reset "${args[@]}" && has_token --hard "${args[@]}"; then
      deny "git reset --hard"
    fi
  fi

  if printf '%s' "$seg" | grep -qiE 'drop[[:space:]]+table'; then
    deny "DROP TABLE"
  fi
done <<< "$segments"

exit 0
