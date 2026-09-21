# Контейнерная диаграмма (C4 L2)

```mermaid
flowchart TB
    subgraph clients["Клиенты"]
        web["Web/mobile front\n(вне этого репо)"]
        mcpclient["MCP-клиент\n(Claude, ChatGPT)"]
    end

    subgraph mtgbro["MTG-Bro"]
        auth["authenticator\nOAuth2/OIDC, JWKS"]
        deck["deck\nсправочник карт + колоды"]
        stats["limited-stats\nпарсер 17lands"]
        article["article-parser\nпарсер draftsim"]
        insight["insight-provider\nLLM, эмбеддинги, pgvector"]
        mcp["mcp-gateway\nMCP-фасад"]
    end

    subgraph infra["Инфраструктура"]
        pg[("PostgreSQL\nсхема на сервис")]
        redis[("Redis\nкэш")]
        kafka[["Kafka\nтопики событий"]]
    end

    subgraph ext["Внешние системы"]
        scryfall["Scryfall API"]
        lands17["17lands.com"]
        draftsim["draftsim.com"]
        llm["LLM-вендор"]
        tg["Telegram"]
    end

    web -- "REST" --> deck
    web -- "REST" --> auth
    mcpclient -- "MCP" --> mcp
    mcpclient -- "OAuth2 redirect" --> auth

    mcp -- "gRPC" --> deck
    mcp -- "gRPC" --> stats
    mcp -- "gRPC" --> insight
    mcp -- "проверка токена" --> auth

    deck -- "HTTPS bulk-data" --> scryfall
    deck --> pg
    deck --> redis

    stats -- "HTTPS, по расписанию" --> lands17
    stats --> pg
    stats -- "алерты" --> tg

    article -- "HTTPS WP API" --> draftsim
    article --> pg
    article -- "publish: article.parsed" --> kafka

    kafka -- "consume: article.parsed" --> insight
    insight -- "HTTPS" --> llm
    insight --> pg
    insight -- "publish: insight.ready" --> kafka

    auth --> pg
```

## Правила взаимодействия

- **Внутри системы — gRPC.** Сервис-сервис вызовы (`mcp-gateway → deck`, проверка токена и т.п.) идут через gRPC с контрактами из `libs/proto`. Обоснование и детали — [api-contracts.md](api-contracts.md), [ADR-0002](adr/0002-grpc-internal-rest-external.md).
- **Наружу — REST+OpenAPI.** Веб/мобильный фронт и прямые интеграции — REST. MCP-клиент говорит с `mcp-gateway` по протоколу MCP, не REST и не gRPC.
- **Асинхронно — Kafka.** Пайплайн статей → инсайтов асинхронный от начала до конца: `article-parser` ничего не ждёт от `insight-provider` синхронно. Детали — [messaging.md](messaging.md).
- **Каждый сервис владеет своей схемой БД.** Ни один сервис не читает чужую схему напрямую — только через gRPC. Исключение обсуждается отдельно, если возникнет.
- **JWKS раздаёт `authenticator`.** Остальные сервисы верифицируют JWT локально через `libs/authx`, не ходят в `authenticator` на каждый запрос (кроме первичной загрузки/ротации ключей).
