# Наблюдаемость

Текущий этап: **метрики + алерты в Telegram**, без сборщика/дашбордов и без
трейсов. Сбор в Grafana/VictoriaMetrics и OTel-трейсинг — веха M7, когда будет
ясно, что реально нужно смотреть — заводить дашборды заранее под несуществующие
проблемы смысла нет.

## Метрики — обязательный минимум на сервис

Экспортируются в формате Prometheus на `/metrics` (`libs/obs`), scrape-конфиг
появится вместе со сборщиком в M7 — до этого метрики просто отдаются и никто
их не тянет, это ок, они дёшевы.

### RED-метрики (все REST/gRPC-сервисы)

- `http_requests_total{method,path,status}` / `grpc_requests_total{service,method,code}`
- `http_request_duration_seconds{method,path}` (histogram) / grpc-аналог
- `http_requests_in_flight`

### Домен-специфика

- **limited-stats, article-parser** (фоновые парсеры): `job_runs_total{job,status}`,
  `job_duration_seconds{job}`, `job_last_success_timestamp{job}`,
  `scheduler_lease_holders{job}` (сколько инстансов реально держат аренду задачи).
- **insight-provider**: `llm_calls_total{vendor,status}`, `llm_call_duration_seconds`,
  `llm_tokens_used_total{vendor,kind=prompt|completion}` (нужно для token-budget).
- **deck**: `import_operations_total{source,status}` (txt/csv/json/Moxfield/TCGPlayer).

## Health-checks

Каждый сервис отдаёт:

- `GET /healthz` — жив ли процесс (для контейнер-оркестрации).
- `GET /readyz` — готов ли принимать трафик (проверка соединения с БД/Kafka).

Реализация — общий хелпер в `libs/core`, сервис регистрирует свои
health-пробы (БД, брокер, внешний API при необходимости).

## Алерты в Telegram

- Единый Telegram-бот/канал на всю систему, отправка через `libs/obs`
  (простой HTTP-клиент к Bot API, без отдельного alertmanager — правила
  алертинга пока пишутся в коде сервиса, не декларативно).
- **Обязательные алерты для парсеров** (limited-stats, article-parser) —
  требование зафиксировано с самого начала, не откладывается:
  - старт планового прогона;
  - успешное завершение прогона (с кратким summary: сколько записей);
  - провал прогона (с текстом ошибки);
  - прогон не запустился в ожидаемое окно (пропущенный шедул).
- **Остальные сервисы**: алерт на `readyz`, ушедший в fail дольше N минут;
  алерт на всплеск `5xx`/`INTERNAL` кодов выше порога.
- Формат сообщения: `[env] [service] <emoji> <короткое описание>` +
  ссылка/id для дальнейшего разбора, без стектрейсов целиком (чтобы не
  захламлять канал) — полный текст ошибки только в логах сервиса.

## Трейсы — задел

`libs/obs` с самого начала прокидывает `context.Context` через все вызовы так,
чтобы OTel SDK можно было подключить в M7 без рефакторинга call chain'ов —
никакого преждевременного инструментирования сейчас, только дисциплина по
контексту.
