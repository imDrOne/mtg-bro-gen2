# CLAUDE.md — insight-provider

Гайд для Claude Code при работе внутри `services/insight-provider`.
Общесистемный контекст — в [docs/arch/](../../docs/arch/README.md), корневые
правила — в [корневом CLAUDE.md](../../CLAUDE.md).

## Назначение и границы

Единственный сервис в системе, который говорит со сторонними LLM API
(Claude/ChatGPT/др., в перспективе — локальная модель на своих мощностях).
Потребляет тексты (статьи, статистику) из Kafka, прогоняет через LLM с
системным промптом, валидирует и публикует структурированный JSON-результат.
Отдельно считает эмбеддинги и держит `pgvector` для гибридного поиска.
Владение обосновано в [ADR-0007](../../docs/arch/adr/0007-embeddings-owned-by-insight-provider.md).

**Чем не владеет:** парсингом источников (это `article-parser`/`limited-stats`),
хранением карточных данных (`deck`), идентификацией пользователей.

## Данные

- Схема БД: `insight`, включая `pgvector`-таблицы
  ([ADR-0005](../../docs/arch/adr/0005-pgvector-over-qdrant.md)).
- Роли: `insight_migrator`, `insight_app`.
- Таблицы: `insights` (структурированный результат по `kind`), `article_chunks`
  (текст чанка + embedding-вектор + метаданные для гибридного поиска),
  `outbox`, `llm_usage` (для token-budget).
- `VectorStore` — Go-интерфейс поверх pgvector, чтобы смена реализации
  (см. критерии в ADR-0005) не требовала переписывать вызывающий код.

## Внешние зависимости

- **LLM-вендор(ы) API** — единственное место в системе, где живут эти ключи.
  Rate limit и token-budget — через `libs/httpx` + собственный
  token-leasing (ограничение расхода в окне, бюджет ≤5к/мес чувствителен к
  неконтролируемым вызовам).
- При недоступности вендора — сообщение остаётся неподтверждённым в Kafka
  (retry согласно политике консьюмера), после исчерпания ретраев — в DLQ.

## Контракты

- gRPC (внутрь): `InsightService.GetCardInsights(card_id)`,
  `InsightService.SearchSimilar(query, filters)` — для `deck` и `mcp-gateway`.
- Kafka in: `article.parsed`.
- Kafka out: `insight.ready` (через outbox).
- REST: не предоставляет — только gRPC и Kafka, наружу этот сервис не
  выставлен напрямую.

## Внутренняя раскладка (ориентир для M5)

```
internal/
  llm/           # клиенты LLM-вендоров, structured output + JSON Schema валидация
  chunking/      # разбиение текста на чанки перед эмбеддингом
  embeddings/    # вызов embedding-API
  vectorstore/   # интерфейс + pgvector-реализация
  budget/        # token-leasing
```

## Паттерны здесь

- **Token/budget leasing** — ключевой паттерн: ограничение трат на LLM API
  в окне (день/месяц), чтобы не выйти за бюджет проекта.
- **Circuit breaker** — на вызовы LLM-вендора.
- **Outbox** — публикация `insight.ready`.
- **Идемпотентность** — консьюмер `article.parsed` не обрабатывает повторно
  уже обработанный `article_id` (дедуп по `idempotency_key`).
- **DLQ** — статьи, на которых LLM стабильно падает (например, невалидный
  JSON после всех ретраев), уходят в `article.parsed.dlq`, не блокируют
  партицию.

Полное обоснование — [patterns.md](../../docs/arch/patterns.md).

## Локальный запуск

```
task up
go run ./cmd/migrate up
go run ./cmd/server
```

Требует API-ключ LLM-вендора в локальном `.env` (см. `.gitignore` — `*.local*`).

## Метрики и алерты

`llm_calls_total{vendor,status}`, `llm_call_duration_seconds`,
`llm_tokens_used_total{vendor,kind}` — последняя метрика напрямую питает
контроль бюджета. Алерт на приближение к месячному лимиту токенов —
добавляется вместе с реализацией token-budget в M5, не откладывается на M7.

## Инварианты домена

- Ни один LLM-ответ не публикуется в `insight.ready` без прохождения
  JSON Schema валидации — невалидный ответ = retry или DLQ, не best-effort
  публикация «как есть».
- Token-budget — hard limit, не soft warning: при исчерпании месячного
  бюджета новые LLM-вызовы блокируются до следующего окна, не уходят в
  перерасход.
- `article_id` из `article.parsed` обрабатывается не более одного раза за
  версию промпта/модели (переобработка при смене промпта — осознанное
  действие, не побочный эффект повторной доставки).
