# Scripts

| Path | Used by | What |
|---|---|---|
| [`setup-local.sh`](setup-local.sh) | `task setup` | Bootstraps machine-local, gitignored config files from their tracked `.dist` templates (`docker-compose.dist.yml` → `docker-compose.local.yml`, `.mcp.dist.json` → `.mcp.json`). Never overwrites an existing local file unless called with `--force`. |
| [`task/`](task/) | `Taskfile.yml` | Module-resolution helpers behind the multi-module `task build`/`test`/`vet`/`lint`/`generate`/`run` targets — see [`task/README.md`](task/README.md). |

## Dist → local convention

A few config files are machine-specific and gitignored (`*.local.*`,
`.mcp.json` — see [CLAUDE.md](../CLAUDE.md#ignoring-files)) but still need
a sane starting point for a new checkout. Each one is tracked as a
`<name>.dist.<ext>` file; `setup-local.sh` copies the dist file to its
local counterpart the first time, and leaves it alone afterwards so
per-machine edits aren't clobbered.

Adding a new dist/local pair: add the file as `<name>.dist.<ext>`, add its
`<name>.<ext>` (or whatever the real filename is) to `.gitignore`, and add
the `"dist:local"` pair to the `pairs=(...)` array in `setup-local.sh`.
