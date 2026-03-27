# Exemplos - Clean Architecture (Python)

## Ports (`domain/ports/`)

Interfaces (abstrações) — contratos que definem **o que** o sistema precisa, sem dizer **como**.

### Outbound Port (Repository)

```python
# domain/ports/outbound/event_repository.py
from abc import ABC, abstractmethod

class EventRepository(ABC):
    @abstractmethod
    async def find_pending(self) -> list[Event]:
        ...

    @abstractmethod
    async def save(self, event: Event) -> None:
        ...
```

### Implementação concreta do Port

```python
# adapters/outbound/repositories/postgres_event_repository.py
class PostgresEventRepository(EventRepository):  # implementa o port
    async def find_pending(self) -> list[Event]:
        # aqui sim usa SQLAlchemy, conhece o banco
        ...
```

**Inbound ports** = interfaces dos use cases (como o mundo externo aciona o sistema)
**Outbound ports** = interfaces de repositórios, gateways, storage (como o sistema acessa recursos externos)

---

## Use Cases (`use_cases/`)

Regras de negócio da aplicação — orquestram o fluxo. Cada use case faz **uma coisa**. Dependem apenas de ports, nunca de implementações concretas.

```python
# use_cases/process_event.py
class ProcessEventUseCase:
    def __init__(
        self,
        event_repo: EventRepository,       # port, não implementação
        storage: StorageGateway,            # port
        queue: QueueGateway,                # port
    ):
        self._event_repo = event_repo
        self._storage = storage
        self._queue = queue

    async def execute(self, event_id: str) -> None:
        event = await self._event_repo.find_by_id(event_id)
        data = await self._storage.download(event.url)
        await self._event_repo.save_data(event, data)

        if event.has_next_page:
            await self._queue.publish(event.next_page_event())
```

O use case não sabe se o storage é S3 ou filesystem, se a fila é SQS ou RabbitMQ — ele só conhece os contratos.

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
        self.event_repo = PostgresEventRepository(settings.database_url)
        self.cache = RedisCacheGateway(settings.redis_url)
        self.queue = SQSQueueGateway(settings.sqs_url)
        self.storage = S3StorageGateway(settings.s3_url)

        # Services
        self.rate_limiter = TokenBucketRateLimiter(self.cache)

        # Use Cases (recebem ports, não implementações concretas)
        self.process_event = ProcessEventUseCase(
            event_repo=self.event_repo,
            storage=self.storage,
            queue=self.queue,
        )
```

### Testes (troca por mocks sem alterar use cases)

```python
# tests
container.event_repo = InMemoryEventRepository()
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
# domain/entities/event.py
class Event:
    def __init__(self, id: str, url: str, status: str, page: int | None):
        self.id = id
        self.url = url
        self.status = status
        self.page = page

    @property
    def has_next_page(self) -> bool:
        return self.page is not None

    def next_page_event(self) -> "Event":
        return Event(id=self.id, url=self.url, status="pending", page=self.page + 1)
```

### ORM Model (Infra — conhece SQLAlchemy)

```python
# infra/database/models/event_model.py
from sqlalchemy import Column, String, Integer
from infra.database.base import Base

class EventModel(Base):
    __tablename__ = "events"
    id = Column(String, primary_key=True)
    url = Column(String, nullable=False)
    status = Column(String, nullable=False)
    page = Column(Integer, nullable=True)
```

### Conversão Entity <-> Model (no Repository)

```python
# adapters/outbound/repositories/postgres_event_repository.py
class PostgresEventRepository(EventRepository):
    def _to_entity(self, model: EventModel) -> Event:
        return Event(id=model.id, url=model.url, status=model.status, page=model.page)

    def _to_model(self, entity: Event) -> EventModel:
        return EventModel(id=entity.id, url=entity.url, status=entity.status, page=entity.page)
```

### Queue Schema (Mensagem de fila)

```python
# adapters/outbound/queue/schemas/event_message.py
from dataclasses import dataclass

@dataclass
class EventMessage:
    event_id: str
    ttl: int
    retry_count: int

    def to_dict(self) -> dict:
        return {"event_id": self.event_id, "ttl": self.ttl, "retry_count": self.retry_count}

    @classmethod
    def from_dict(cls, data: dict) -> "EventMessage":
        return cls(event_id=data["event_id"], ttl=data["ttl"], retry_count=data["retry_count"])
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
    url: str
    schedule: str
    source_type: str  # "file" | "api"

class ConfigResponse(BaseModel):
    id: str
    url: str
    status: str
```

### Estrutura com schemas

```
src/
├── domain/
│   ├── entities/                        # Objetos de negócio puros
│   │   ├── event.py
│   │   ├── config.py
│   │   └── cost_record.py
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
| **Entity** | `domain/entities/` | `Event`, `Config` | Não |
| **Port** | `domain/ports/` | `EventRepository` (ABC) | Não |
| **ORM Model** | `infra/database/models/` | `EventModel` (SQLAlchemy) | Sim |
| **Queue Schema** | `adapters/outbound/queue/schemas/` | `EventMessage` | Não (dataclass) |
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
