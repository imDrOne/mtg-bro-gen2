#!/usr/bin/env bash
# Bootstrap the user-level prerequisites for the telegram@claude-plugins-official
# channel plugin: checks `bun` (the plugin's MCP server runtime), then writes
# TELEGRAM_BOT_TOKEN to ~/.claude/channels/telegram/.env with safe permissions.
#
# This only covers what CAN be scripted — plugin install, pairing, and
# access-policy lockdown happen inside an interactive `claude` session and a
# Telegram chat with BotFather/your bot. See README.md in this directory for
# the full walkthrough.
set -euo pipefail

STATE_DIR="${TELEGRAM_STATE_DIR:-$HOME/.claude/channels/telegram}"
ENV_FILE="$STATE_DIR/.env"

echo "== Telegram bot setup for Claude Code =="
echo

# --- 1. bun ---
if command -v bun >/dev/null 2>&1; then
  echo "[ok] bun found: $(bun --version)"
else
  echo "[missing] bun not found on PATH — the telegram plugin's MCP server runs on it." >&2
  echo "  Install: curl -fsSL https://bun.sh/install | bash" >&2
  echo "  Then re-run this script." >&2
  exit 1
fi

# --- 2. claude CLI (sanity check, not a hard requirement to run this script) ---
if command -v claude >/dev/null 2>&1; then
  echo "[ok] claude CLI found: $(claude --version 2>/dev/null || echo present)"
else
  echo "[warn] claude CLI not found on PATH — fine for this script, but you'll need it for the remaining manual steps." >&2
fi

# --- 3. token ---
echo
if [[ -f "$ENV_FILE" ]] && grep -q '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" 2>/dev/null; then
  echo "[skip] $ENV_FILE already has a token. Delete it or edit by hand to rotate — not overwriting automatically."
else
  echo "Paste the bot token BotFather gave you (looks like 123456789:AAHfiqksKZ8...)."
  echo "Input is hidden; nothing is echoed back."
  read -rsp "Token: " token
  echo
  if [[ -z "$token" ]]; then
    echo "[error] empty token, nothing written." >&2
    exit 1
  fi
  if [[ ! "$token" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
    echo "[warn] that doesn't look like a BotFather token (expected <digits>:<token>) — writing it anyway, double check it." >&2
  fi

  mkdir -p "$STATE_DIR"
  chmod 700 "$STATE_DIR"
  printf 'TELEGRAM_BOT_TOKEN=%s\n' "$token" > "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "[ok] wrote $ENV_FILE (chmod 600)"
fi

cat <<'EOF'

== Remaining manual steps ==

1. Install the plugin (inside a `claude` session):
     /plugin install telegram@claude-plugins-official
     /reload-plugins

2. Relaunch with the channel enabled — the server won't connect without this:
     claude --channels plugin:telegram@claude-plugins-official

3. DM your bot on Telegram. It replies with a 6-character pairing code.
   Back in the claude session:
     /telegram:access pair <code>

4. Lock it down so strangers can't pair:
     /telegram:access policy allowlist

Full details, groups, mention rules: README.md in this directory.
EOF
