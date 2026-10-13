# Реестр сервисов

Источник правды о том, какие сервисы существуют. Правится в первую очередь при
добавлении/переименовании/выпиливании сервиса; `overview.md` и `roadmap.md`
следуют за этим файлом, не наоборот.

| Сервис | Зона ответственности | Схема БД | Kafka in | Kafka out | Статус |
|---|---|---|---|---|---|
| [deck](../../services/deck/CLAUDE.md) | Справочник карт (зеркало Scryfall) + сборка/хранение колод и библиотек пользователей | `deck` | — | `deck.saved` | Planned (M1–M2) |
| [limited-stats](../../services/limited-stats/CLAUDE.md) | Парсинг статистики limited-форматов с 17lands.com по расписанию | `limited_stats` | — | — | Planned (M3) |
| [article-parser](../../services/article-parser/CLAUDE.md) | Парсинг статей с draftsim.com (WordPress API), хранение raw+очищенного текста | `article` | — | `article.parsed` | Planned (M5) |
| [insight-provider](../../services/insight-provider/CLAUDE.md) | Вызовы LLM-вендоров: структурированные инсайты и эмбеддинги, векторный поиск (pgvector) | `insight` | `article.parsed` | `insight.ready` | Planned (M5) |
| [authenticator](../../services/authenticator/CLAUDE.md) | OAuth2/OIDC, JWKS, login-форма | `auth` | — | — | Planned (M4), OAuth2-подход открыт — [ADR-0008](adr/0008-oauth2-build-vs-buy.md) |
| [mcp-gateway](../../services/mcp-gateway/CLAUDE.md) | MCP-сервер, фасад tools поверх gRPC остальных сервисов | нет своей БД | — | — | Planned (M6) |

## Порты (локальная разработка)

Финализируется в M0 вместе с `docker-compose.local.yml`; ориентир — REST на `8xxx`, gRPC на `9xxx` по тому же индексу сервиса, чтобы не путать:

| Сервис | REST | gRPC |
|---|---|---|
| deck | 8081 | 9081 |
| limited-stats | 8082 | 9082 |
| article-parser | 8083 | 9083 |
| insight-provider | 8084 | 9084 |
| authenticator | 8085 | 9085 |
| mcp-gateway | 8086 | — (говорит MCP, не gRPC) |

## Общие библиотеки (`libs/`)

| Библиотека | Назначение |
|---|---|
| `libs/core` | config, slog-обёртка, graceful shutdown, healthz/readyz, доменные ошибки |
| `libs/httpx` | HTTP-клиент с retry+jitter, token-bucket rate limiter, circuit breaker, singleflight |
| `libs/scryfall` | SDK к Scryfall API — bulk-data эндпоинты и поиск |
| `libs/kafkax` | Обёртки producer/consumer, outbox-relay, DLQ-хелперы |
| `libs/obs` | Prometheus registry, TG-алертер, задел под OTel |
| `libs/authx` | Верификатор JWT по JWKS: HTTP middleware + gRPC interceptor |
| `libs/proto` | `.proto`-контракты и сгенерированные buf'ом стабы |
