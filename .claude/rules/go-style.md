---
paths:
  - "**/*.go"
---

# Go style

**MUST USE** the `modern-go-guidelines` plugin skill (`use-modern-go`) for all Go code writes/edits/refactors — it encodes [JetBrains: Help AI coding agents write up-to-date Go](https://blog.jetbrains.com/go/2026/08/24/help-ai-coding-agents-write-up-to-date-code-with-modern-golang-skills/): favor current stdlib idioms over outdated patterns an LLM may default to (e.g. `slog` over third-party loggers, `min`/`max` builtins, range-over-func where fitting, current error-handling conventions).
