# Exemplos - Clean Architecture (Python)

## Ports (`domain/ports/`)

Interfaces (abstrações) — contratos que definem **o que** o sistema precisa, sem dizer **como**.

### Outbound Port (Repository)

```python
# domain/ports/outbound/upload_file_event_repository.py
from abc import ABC, abstractmethod
from src.domain.entities.upload_file_event import UploadFileEvent

class UploadFileEventRepository(ABC):
    @abstractmethod
    async def find_by_id(self, id: int) -> UploadFileEvent | None: ...

    @abstractmethod
    async def find_pending(self) -> list[UploadFileEvent]: ...

    @abstractmethod
    async def save(self, event: UploadFileEvent) -> None: ...

    @abstractmethod
    async def update_status(self, id: int, status: str) -> None: ...
```

```python
# domain/ports/outbound/download_url_event_repository.py
from abc import ABC, abstractmethod
from src.domain.entities.download_url_event import DownloadUrlEvent

class DownloadUrlEventRepository(ABC):
    @abstractmethod
    async def find_by_id(self, id: int) -> DownloadUrlEvent | None: ...

    @abstractmethod
    async def find_pending(self) -> list[DownloadUrlEvent]: ...

    @abstractmethod
    async def save(self, event: DownloadUrlEvent) -> None: ...

    @abstractmethod
    async def update_status(self, id: int, status: str) -> None: ...
```

### Implementação concreta do Port

```python
# adapters/outbound/repositories/postgres_upload_file_event_repository.py
class PostgresUploadFileEventRepository(UploadFileEventRepository):
    async def find_pending(self) -> list[UploadFileEvent]:
        # aqui sim usa SQLAlchemy, conhece o banco
        ...
```

**Inbound ports** = interfaces dos use cases (como o mundo externo aciona o sistema)
**Outbound ports** = interfaces de repositórios, gateways, storage (como o sistema acessa recursos externos)

---

## Use Cases (`use_cases/`)

Regras de negócio da aplicação — orquestram o fluxo. Cada use case faz **uma coisa**. Dependem apenas de ports, nunca de implementações concretas.

```python
# use_cases/dispatch_download.py
class DispatchDownloadUseCase:
    def __init__(
        self,
        config_repo: ConfigRepository,                  # port
        url_event_repo: DownloadUrlEventRepository,     # port
        upload_event_repo: UploadFileEventRepository,   # port
        extract_sources_repo: ExtractSourcesRepository, # port
        api_client: ApiClientGateway,                   # port
        storage: StorageGateway,                        # port
        hash_generator: HashGenerator,                  # service
    ):
        ...

    async def execute(self, config_id: int) -> None:
        config = await self._config_repo.find_by_id(config_id)

        match config.source_type:
            case "API":
                event = DownloadUrlEvent(config_id=config.id, page=1, ...)
                await self._url_event_repo.save(event)
            case "CSV":
                content = await self._api_client.download(config.url)
                content_hash = self._hash_generator.generate(content)
                if content_hash != config.last_hash:
                    # salva no banco, cria upload_file_event
                    ...
            case "ZIP" | "XLSX":
                content = await self._api_client.download(config.url)
                sources = await self._extract_sources_repo.find_by_config_id(config.id)
                for source in sources:
                    # extrai, salva no banco, cria upload_file_event
                    ...
```

```python
# use_cases/process_event.py
class ProcessEventUseCase:
    def __init__(
        self,
        url_event_repo: DownloadUrlEventRepository,   # port
        upload_event_repo: UploadFileEventRepository,  # port
        data_repo: DataRepository,                     # port
        storage: StorageGateway,                       # port
        queue: QueueGateway,                           # port
        api_client: ApiClientGateway,                  # port
        rate_limiter: TokenBucketRateLimiter,          # service
    ):
        ...

    async def execute(self, event_id: int) -> None:
        event = await self._url_event_repo.find_by_id(event_id)
        if not await self._rate_limiter.acquire(event.config_id):
            await self._queue.requeue(event)
            return

        data = await self._api_client.fetch(event.url, event.params, event.page)
        await self._data_repo.batch_insert(event.table_name, data.rows)

        if data.has_next:
            next_event = event.next_page_event()
            await self._url_event_repo.save(next_event)
        else:
            # finaliza: gera parquet e cria upload_file_event
            ...
```

Os use cases não sabem se o storage é S3 ou filesystem, se a fila é SQS ou RabbitMQ — só conhecem os contratos.

---

## Services (`adapters/services/`)

Lógicas transversais reutilizáveis que não são regras de negócio puras (domínio) nem orquestração (use case). Ficam nos adaptadores porque geralmente dependem de infra (Redis, I/O).

## Aws Client
```python
# src/adapters/outbound/storage/s3_gateway.py

import boto3
from src.infra.config.settings import get_settings

def make_s3_client():
    cfg = get_settings()
    return boto3.client(
        "s3",
        endpoint_url=cfg.aws_endpoint_url,       # None = AWS real | URL = LocalStack
        aws_access_key_id=cfg.aws_access_key_id,
        aws_secret_access_key=cfg.aws_secret_access_key,
        region_name=cfg.aws_default_region,
    )
```

### Rate Limiter

```python
# adapters/services/rate_limiter.py
class TokenBucketRateLimiter:
    def __init__(self, cache: CacheGateway):
        self._cache = cache

    async def acquire(self, key: str, max_requests: int) -> bool:
        current = await self._cache.increment(key)
        return current <= max_requests
```

### Hash Generator

```python
# adapters/services/hash_generator.py
class HashGenerator:
    def generate(self, content: bytes) -> str:
        return hashlib.blake2b(content, digest_size=64).hexdigest()
```

---

## Container (`infra/container/`)

Injeção de dependências — o lugar onde você **conecta tudo**. Decide qual implementação concreta satisfaz cada port.

### Produção

```python
# infra/container/container.py
class Container:
    def __init__(self, settings: Settings):
        # Outbound (infraestrutura real)
        self.config_repo = PostgresConfigRepository(settings.database_url)
        self.upload_event_repo = PostgresUploadFileEventRepository(settings.database_url)
        self.url_event_repo = PostgresDownloadUrlEventRepository(settings.database_url)
        self.extract_sources_repo = PostgresExtractSourcesRepository(settings.database_url)
        self.data_repo = PostgresDataRepository(settings.database_url)
        self.cache = RedisCacheGateway(settings.redis_url)
        self.queue = SQSQueueGateway(settings.sqs_url)
        self.storage = S3StorageGateway(settings.s3_url)
        self.api_client = HttpApiClientGateway(settings.api_timeout)

        # Services
        self.rate_limiter = TokenBucketRateLimiter(self.cache)
        self.hash_generator = HashGenerator()

        # Use Cases (recebem ports, não implementações concretas)
        self.dispatch_download = DispatchDownloadUseCase(
            config_repo=self.config_repo,
            url_event_repo=self.url_event_repo,
            upload_event_repo=self.upload_event_repo,
            extract_sources_repo=self.extract_sources_repo,
            api_client=self.api_client,
            storage=self.storage,
            hash_generator=self.hash_generator,
        )
        self.process_event = ProcessEventUseCase(
            url_event_repo=self.url_event_repo,
            upload_event_repo=self.upload_event_repo,
            data_repo=self.data_repo,
            storage=self.storage,
            queue=self.queue,
            api_client=self.api_client,
            rate_limiter=self.rate_limiter,
        )
        self.schedule_download = ScheduleDownloadUseCase(
            config_repo=self.config_repo,
            queue=self.queue,
        )
```

### Testes (troca por mocks sem alterar use cases)

```python
# tests
container.config_repo = InMemoryConfigRepository()
container.upload_event_repo = InMemoryUploadFileEventRepository()
container.url_event_repo = InMemoryDownloadUrlEventRepository()
container.queue = FakeQueueGateway()
```

---

## Entities vs Models vs DTOs/Schemas

Cada camada possui seus próprios objetos de dados com responsabilidades distintas.

```
Domínio (Entities)      →  Regra de negócio pura, sem framework
Infra (Models)           →  Representação no banco (ORM)
Adapters (DTOs/Schemas)  →  Formato de entrada/saída de cada integração
```

### Entity (Domínio — pura, sem dependência)

```python
# domain/entities/download_url_event.py
from dataclasses import dataclass

@dataclass
class DownloadUrlEvent:
    id: int | None
    config_id: int
    status: str
    page: int
    params: dict
    table_name: str
    total_pages: int | None
    headers: dict
    correlation_id: str
    s3_key: str | None = None
    error_message: str | None = None
    retry_count: int = 0

    @property
    def has_next_page(self) -> bool:
        return self.total_pages is None or self.page < self.total_pages

    def next_page_event(self) -> "DownloadUrlEvent":
        return DownloadUrlEvent(
            id=None, config_id=self.config_id, status="PENDING",
            page=self.page + 1, params=self.params, table_name=self.table_name,
            total_pages=self.total_pages, headers=self.headers,
            correlation_id=self.correlation_id,
        )
```

### ORM Model (Infra — conhece SQLAlchemy)

```python
# infra/database/models/download_url_event_model.py
from sqlalchemy import Column, BigInteger, Integer, String, JSON, DateTime
from infra.database.base import Base

class DownloadUrlEventModel(Base):
    __tablename__ = "download_url_events"
    download_url_event_id = Column(BigInteger, primary_key=True, autoincrement=True)
    download_config_id = Column(BigInteger, nullable=False)
    status = Column(String, nullable=False, default="PENDING")
    page = Column(Integer, nullable=False, default=1)
    params = Column(JSON, nullable=False, default={})
    table_name = Column(String(50), nullable=False)
    total_pages = Column(Integer, nullable=True)
    headers = Column(JSON, nullable=False, default={})
    correlation_id = Column(String(60), nullable=False)
    s3_key = Column(String, nullable=True)
    error_message = Column(String, nullable=True)
    retry_count = Column(Integer, nullable=False, default=0)
    processed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False)
    updated_at = Column(DateTime(timezone=True), nullable=False)
```

### Conversão Entity <-> Model (no Repository)

```python
# adapters/outbound/repositories/postgres_download_url_event_repository.py
class PostgresDownloadUrlEventRepository(DownloadUrlEventRepository):
    def _to_entity(self, model: DownloadUrlEventModel) -> DownloadUrlEvent:
        return DownloadUrlEvent(
            id=model.download_url_event_id, config_id=model.download_config_id,
            status=model.status, page=model.page, params=model.params,
            table_name=model.table_name, total_pages=model.total_pages,
            headers=model.headers, correlation_id=model.correlation_id,
            s3_key=model.s3_key, error_message=model.error_message,
            retry_count=model.retry_count,
        )

    def _to_model(self, entity: DownloadUrlEvent) -> DownloadUrlEventModel:
        return DownloadUrlEventModel(
            download_config_id=entity.config_id, status=entity.status,
            page=entity.page, params=entity.params, table_name=entity.table_name,
            total_pages=entity.total_pages, headers=entity.headers,
            correlation_id=entity.correlation_id, s3_key=entity.s3_key,
            error_message=entity.error_message, retry_count=entity.retry_count,
        )
```

### Queue Schema (Mensagens de fila)

```python
# adapters/outbound/queue/schemas/config_dispatch_message.py
from dataclasses import dataclass

@dataclass
class ConfigDispatchMessage:
    config_id: int
    correlation_id: str

    def to_dict(self) -> dict:
        return {"config_id": self.config_id, "correlation_id": self.correlation_id}

    @classmethod
    def from_dict(cls, data: dict) -> "ConfigDispatchMessage":
        return cls(config_id=data["config_id"], correlation_id=data["correlation_id"])
```

```python
# adapters/outbound/queue/schemas/event_message.py
from dataclasses import dataclass

@dataclass
class EventMessage:
    event_id: int
    event_type: str  # "download_url" | "upload_file"
    retry_count: int

    def to_dict(self) -> dict:
        return {"event_id": self.event_id, "event_type": self.event_type, "retry_count": self.retry_count}

    @classmethod
    def from_dict(cls, data: dict) -> "EventMessage":
        return cls(event_id=data["event_id"], event_type=data["event_type"], retry_count=data["retry_count"])
```

### API Client Response (Resposta de API externa)

```python
# adapters/outbound/api_clients/schemas/transparencia_response.py
@dataclass
class TransparenciaResponse:
    data: list[dict]
    has_next: bool
    next_page: int | None
```

### Cache Entry (Representação no cache)

```python
# adapters/outbound/cache/schemas/rate_limit_entry.py
@dataclass
class RateLimitEntry:
    key: str
    current_count: int
    window_start: float
```

### API DTOs (Request/Response da API interna)

```python
# adapters/inbound/api/schemas/config_request.py
from pydantic import BaseModel

class CreateConfigRequest(BaseModel):
    source_name: str
    destiny_name: str | None = None
    url: str
    source_type: str  # "API" | "CSV" | "ZIP" | "XLSX"
    period_type: str  # "YEAR" | "MONTH"
    period: str       # "2026-01-01"
    cron_expression: str
    http_method: str = "GET"
    params: dict = {}
    headers: dict = {}
    requires_auth: bool = False

class ConfigResponse(BaseModel):
    id: int
    source_name: str
    source_type: str
    is_active: bool
    next_run_at: str | None
```

### Estrutura com schemas

```
src/
├── domain/
│   ├── entities/                        # Objetos de negócio puros
│   │   ├── download_config.py
│   │   ├── upload_file_event.py
│   │   ├── download_url_event.py
│   │   └── download_extract_sources.py
│   ├── ports/
│   │   ├── inbound/
│   │   └── outbound/
│   └── exceptions/
│
├── use_cases/
│
├── adapters/
│   ├── inbound/
│   │   ├── api/
│   │   │   └── schemas/                 # Request/Response DTOs (Pydantic)
│   │   ├── consumers/
│   │   └── cronjobs/
│   │
│   ├── outbound/
│   │   ├── repositories/
│   │   ├── storage/
│   │   │   └── schemas/                 # Metadados de arquivo (Parquet)
│   │   ├── queue/
│   │   │   └── schemas/                 # Mensagens de fila
│   │   ├── cache/
│   │   │   └── schemas/                 # Entries de cache
│   │   ├── crawler/
│   │   │   └── schemas/                 # Dados raspados
│   │   └── api_clients/
│   │       └── schemas/                 # Responses de APIs externas
│   │
│   └── services/
│
├── infra/
│   ├── config/
│   ├── database/
│   │   └── models/                      # Modelos ORM (SQLAlchemy)
│   ├── logging/
│   └── container/
│
├── scripts/
│   ├── mockserver/                      # Mock de APIs externas
│   ├── tests/                           # Dados de teste, dataset, yamls
│   ├── flyway/                          # Migração de banco de dados
|   ├── terraform/                       # IaC por ambiente
|   |   ├── local/
|   |   └── prod/
│   ├── helm/
|   |   └── prod/                        # Helm por Ambiente
│   └── docker/                          # Dockerfile
│
├── main.py
└── docker-compose.yml
```

### Tabela resumo

| Objeto | Camada | Exemplo | Conhece framework? |
|--------|--------|---------|-------------------|
| **Entity** | `domain/entities/` | `DownloadConfig`, `UploadFileEvent`, `DownloadUrlEvent` | Não |
| **Port** | `domain/ports/` | `ConfigRepository`, `UploadFileEventRepository` (ABC) | Não |
| **ORM Model** | `infra/database/models/` | `DownloadConfigModel`, `DownloadUrlEventModel` (SQLAlchemy) | Sim |
| **Queue Schema** | `adapters/outbound/queue/schemas/` | `ConfigDispatchMessage`, `EventMessage` | Não (dataclass) |
| **API Response** | `adapters/outbound/api_clients/schemas/` | `TransparenciaResponse` | Não (dataclass) |
| **Cache Entry** | `adapters/outbound/cache/schemas/` | `RateLimitEntry` | Não (dataclass) |
| **API DTO** | `adapters/inbound/api/schemas/` | `CreateConfigRequest` | Sim (Pydantic) |

> A entidade do domínio **nunca muda** por causa de banco, fila ou API externa. Cada adapter converte entre seu schema específico e a entidade do domínio.

---

## Resumo visual do fluxo de dependência

```
CronJob / Consumer / API  (inbound adapters)
        │
        ▼
    Use Cases  ←── dependem de ──→  Ports (interfaces)
        │                              ▲
        │                              │
        │                     implementados por
        │                              │
        ▼                              │
    Container  ──── conecta ────→  Adapters (outbound)
                                   Services
```

Tudo aponta para dentro: adapters conhecem ports, ports não conhecem ninguém. O container é o único lugar que conhece tudo — é o "mapa de fiação" da aplicação.
