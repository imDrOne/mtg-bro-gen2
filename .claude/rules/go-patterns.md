---
paths:
  - "**/*.go"
---

# Distributed-systems patterns

Patterns (rate limiting, circuit breaker, outbox, singleflight, task leasing,
token budgets, DLQ, etc.) are adopted only where a service has a concrete
need for them — never added just for practice. The full map, with the
specific problem each pattern solves and what's deliberately *not* used, is
[docs/arch/patterns.md](../../docs/arch/patterns.md). Check it before reaching for
a pattern in new code.

Outbox/Kafka specifically: `patterns.md` only says *that* outbox is used and
why — the actual contract (topic names, event envelope, idempotency-key
semantics, DLQ naming/retries/retention) is
[docs/arch/messaging.md](../../docs/arch/messaging.md). Read both before touching
any Kafka producer/consumer code, not just `patterns.md`.
