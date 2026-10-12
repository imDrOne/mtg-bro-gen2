# Telegram bot (remote access to a Claude Code session)

Lets you keep working with Claude Code from a Telegram chat instead of a
terminal — message your bot, Claude replies in the same chat. Backed by the
official `telegram@claude-plugins-official` plugin (a Bun-run MCP server
that bridges Telegram ↔ your `claude` session).

**This is personal, user-level setup, not a team convention.** The bot
token and pairing state live under `~/.claude/channels/telegram/` on your
own machine — nothing here is committed to the repo, and each teammate who
wants this sets up their own bot. [`setup.sh`](setup.sh) only writes to
your home directory.

A Telegram bot is just the *interface* — the `claude` process it talks to
still has to be running somewhere (your laptop staying awake, or a
long-running session on a server). This doesn't give you a session that
runs itself; it gives you a way to talk to one that's already running.

## Quick start

```
./scripts/telegram-bot/setup.sh
```

Checks `bun` is installed (the plugin's MCP server runtime) and prompts
for your bot token, writing it to `~/.claude/channels/telegram/.env`
(`chmod 600`). Or via Task: `task telegram:setup`.

What it can't do for you — these steps are inherently interactive (a
Telegram conversation with BotFather, a live `claude` session, a pairing
code that only exists for a few minutes):

### 1. Create the bot

DM [@BotFather](https://t.me/BotFather) on Telegram, send `/newbot`.
It asks for:
- **Name** — display name in chat headers, anything.
- **Username** — unique handle ending in `bot` (e.g. `my_assistant_bot`) → `t.me/my_assistant_bot`.

BotFather replies with a token (`123456789:AAHfiqksKZ8...`) — this is what
`setup.sh` asks for.

### 2. Install the plugin

Inside a `claude` session:

```
/plugin install telegram@claude-plugins-official
/reload-plugins
```

### 3. Run setup.sh (if you haven't)

```
task telegram:setup
```

### 4. Relaunch with the channel enabled

The server won't connect without this flag — exit and restart:

```
claude --channels plugin:telegram@claude-plugins-official
```

### 5. Pair

DM your bot on Telegram. It replies with a 6-character code. Back in the
`claude` session:

```
/telegram:access pair <code>
```

Your next DM reaches the assistant.

### 6. Lock it down

Pairing mode is open — once you're paired, switch to allowlist so a
stranger who finds your bot's username can't trigger a pairing reply:

```
/telegram:access policy allowlist
```

## Notes

- **No message history.** Telegram's Bot API exposes neither history nor
  search — the bot only sees messages as they arrive. If Claude needs
  earlier context, it'll ask you to paste it.
- **Multiple bots on one machine**: set `TELEGRAM_STATE_DIR` to a
  different directory per instance (`setup.sh` respects it) — separate
  tokens, separate allowlists.
- **Groups** are off by default; see the plugin's own `ACCESS.md`
  (`~/.claude/plugins/marketplaces/claude-plugins-official/external_plugins/telegram/ACCESS.md`)
  for group opt-in, mention rules, and the full `access.json` schema —
  this README only covers the single-user DM flow.
- **Rotating the token**: delete `~/.claude/channels/telegram/.env` and
  re-run `setup.sh`.
