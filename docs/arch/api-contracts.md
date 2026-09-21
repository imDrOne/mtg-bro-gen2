# Контракты: REST наружу, gRPC внутрь

Обоснование выбора — [ADR-0002](adr/0002-grpc-internal-rest-external.md).

## REST наружу

- Каждый сервис с внешней поверхностью (deck, limited-stats, authenticator)
  публикует `api/openapi.yaml` (OpenAPI 3.1) в своей директории.
- Спека — источник правды для клиентского кода фронта; серверная сторона в Go
  пишется руками поверх generated request/response DTO (`oapi-codegen`,
  types-only режим — не генерируем роутинг, чтобы не терять контроль над
  middleware-цепочкой).
- Формат ошибки везде одинаковый:

  ```json
  {
    "error": {
      "code": "deck_limit_exceeded",
      "message": "человекочитаемое сообщение",
      "details": {}
    }
  }
  ```

- `mcp-gateway` REST не отдаёт — с ним говорят только по протоколу MCP.

## gRPC внутрь

- Все `.proto` — в `libs/proto`, структура `libs/proto/<domain>/v1/*.proto`.
- Генерация — через `buf generate`, `buf.yaml`/`buf.gen.yaml` в корне
  `libs/proto`. Стабы кладутся в тот же модуль и импортируются сервисами.
- **Версионирование пакетов**: breaking-изменение — новый пакет `v2` рядом со
  старым, оба обслуживаются, пока последний консьюмер не переедет. Non-breaking
  (добавление optional-поля) — в рамках текущей версии.
- **Коды ошибок**: используем стандартные `google.rpc.Code`, не текст в
  сообщении. Маппинг в REST-обёртках (где gRPC-вызов проксируется наружу через
  REST, например будущий BFF) — по таблице:

  | gRPC | HTTP |
  |---|---|
  | `NOT_FOUND` | 404 |
  | `INVALID_ARGUMENT` | 400 |
  | `ALREADY_EXISTS` | 409 |
  | `PERMISSION_DENIED` | 403 |
  | `UNAUTHENTICATED` | 401 |
  | `RESOURCE_EXHAUSTED` | 429 |
  | `UNAVAILABLE` | 503 |
  | остальное | 500 |

- **Identity в метаданных**: вызывающий сервис прокидывает верифицированный JWT
  (или производные claims) в gRPC-метаданных `authorization` /
  `x-user-id`; принимающий сервис не доверяет `x-user-id` без валидного JWT —
  см. [security.md](security.md).
- **Deadline propagation**: каждый исходящий gRPC-вызов наследует дедлайн
  входящего запроса минус запас на собственную обработку — не бесконечные
  контексты. Обеспечивается `libs/httpx`/interceptor'ами в `libs/core`.
- **Обратная совместимость proto**: не переиспользовать номера полей,
  не менять тип существующего поля, новые поля — только `optional`
  (proto3 explicit presence). Линтуется `buf breaking` в CI (заводится вместе
  с пайплайном, отдельная итерация).
