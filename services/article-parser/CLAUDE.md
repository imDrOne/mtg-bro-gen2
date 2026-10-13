# CLAUDE.md — article-parser

Гайд для Claude Code при работе внутри `services/article-parser`. Общесистемный
контекст — в [docs/arch/](../../docs/arch/README.md), корневые правила — в
[корневом CLAUDE.md](../../CLAUDE.md).

## Назначение и границы

Парсит статьи об MTG с draftsim.com через их WordPress REST API по ключевым
словам, хранит raw и очищенный текст. Публикует событие о новой распарсенной
статье для дальнейшей AI-обработки.

**Чем не владеет:** никакой работой с LLM — ни инсайтами, ни эмбеддингами.
Это осознанная граница, см. [ADR-0007](../../docs/arch/adr/0007-embeddings-owned-by-insight-provider.md).
Сервис не хранит и не видит ключи LLM-вендоров.

Название — `article-parser`, не `draftism-parser`: сервис спроектирован под
источник-агностичный парсинг статей, draftsim — первый и пока единственный
источник, но не смысловая граница сервиса.

## Данные

- Схема БД: `article`.
- Роли: `article_migrator`, `article_app`.
- Таблицы: `articles` (raw HTML, очищенный текст, метаданные: url, title,
  set_code, published_at), `outbox` (см. паттерн ниже).

## Внешние зависимости

- **draftsim.com WordPress REST API** — поиск статей по ключевым словам,
  получение содержимого. Rate limit — консервативный token-bucket через
  `libs/httpx`, честный User-Agent.

## Контракты

- REST: минимальный, в основном для внутренней диагностики
  (`GET /articles/{id}`, `GET /articles?search=`) — основной интерфейс
  потребления данных этого сервиса — Kafka, не REST.
- Kafka out: `article.parsed` (через outbox — см. [messaging.md](../../docs/arch/messaging.md)).
- Kafka in: нет.

## Внутренняя раскладка (ориентир для M5)

```
internal/
  wordpress/   # клиент WordPress REST API draftsim
  cleaner/     # HTML -> очищенный текст
  storage/     # articles + outbox
```

## Паттерны здесь

- **Outbox** — публикация `article.parsed` атомарно с записью статьи в БД.
- **Retry + backoff** — на вызовы к draftsim.
- **Token-bucket** — вежливость к источнику.

Полное обоснование — [patterns.md](../../docs/arch/patterns.md).

## Локальный запуск

```
task up
go run ./cmd/migrate up
go run ./cmd/server
```

## Метрики и алерты

Фоновый процесс — алерты обязательны с первого дня, как и в `limited-stats`:
`job_runs_total`, `job_duration_seconds`, `job_last_success_timestamp`.
TG-алерты на старт/финиш/провал прогона поиска статей.

## Инварианты домена

- Одна и та же статья (по url) не дублируется в БД при повторном парсинге —
  upsert по url, повторная публикация в outbox использует тот же
  `idempotency_key`, что и в прошлый раз, если текст не изменился (не плодим
  события без реального изменения).
- Raw-текст никогда не перезаписывается без сохранения истории значимых
  правок (на будущее — если draftsim обновит статью) — на первой итерации
  достаточно хранить `updated_at`, полноценная история — по необходимости.
