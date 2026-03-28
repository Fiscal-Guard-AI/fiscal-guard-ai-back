# Skill: New Adapter

Implementa um adapter concreto que satisfaz um port do domínio.

## Decidir o tipo

| Tipo | Pasta | Exemplo |
|------|-------|---------|
| Repository (banco) | `adapters/outbound/repositories/` | `PostgresEventRepository` |
| Storage (arquivos) | `adapters/outbound/storage/` | `S3StorageGateway` |
| Queue (mensageria) | `adapters/outbound/queue/` | `SQSQueueGateway` |
| Cache | `adapters/outbound/cache/` | `RedisCacheGateway` |
| Crawler | `adapters/outbound/crawler/` | `TransparenciaCrawler` |
| API Client | `adapters/outbound/api_clients/` | `TransparenciaApiClient` |
| API (inbound) | `adapters/inbound/api/` | Router FastAPI |
| Consumer (inbound) | `adapters/inbound/consumers/` | Listener SQS |
| CronJob (inbound) | `adapters/inbound/cronjobs/` | Agendador |

## Checklist

### 1. Verificar que o Port existe

O adapter **implementa** um port. Confirme que o port existe em `src/domain/ports/`.
Se não existir, use a skill `new-port` primeiro.

### 2. Criar Schema (se necessário)

Arquivo: `src/adapters/{inbound|outbound}/{tipo}/schemas/{nome}_schema.py`

```python
# src/adapters/outbound/queue/schemas/event_message.py
from dataclasses import dataclass


@dataclass
class EventMessage:
    """Schema específico da integração — não é entity de domínio."""
    event_id: str
    ttl: int
    retry_count: int

    def to_dict(self) -> dict:
        return {"event_id": self.event_id, "ttl": self.ttl, "retry_count": self.retry_count}

    @classmethod
    def from_dict(cls, data: dict) -> "EventMessage":
        return cls(**data)
```

**Regras de schema:**
- `@dataclass` para schemas simples (queue, cache, crawler)
- `Pydantic BaseModel` apenas para schemas de API HTTP (request/response)
- Sempre incluir `to_dict()` / `from_dict()` para serialização
- Schema pertence ao adapter, **nunca** ao domínio

### 3. Criar o Adapter

Arquivo: `src/adapters/outbound/{tipo}/{nome_adapter}.py`

```python
# src/adapters/outbound/repositories/postgres_event_repository.py
from src.domain.entities.event import Event
from src.domain.ports.outbound.event_repository import EventRepository
from src.infra.database.models.event_model import EventModel


class PostgresEventRepository(EventRepository):
    """Implementação concreta do EventRepository usando PostgreSQL."""

    def __init__(self, session_factory):
        self._session_factory = session_factory

    async def find_by_id(self, id: str) -> Event | None:
        async with self._session_factory() as session:
            model = await session.get(EventModel, id)
            return self._to_entity(model) if model else None

    async def save(self, entity: Event) -> None:
        async with self._session_factory() as session:
            model = self._to_model(entity)
            session.add(model)
            await session.commit()

    # ── Conversão Entity <-> Model ──

    def _to_entity(self, model: EventModel) -> Event:
        return Event(id=model.id, url=model.url, status=model.status, page=model.page)

    def _to_model(self, entity: Event) -> EventModel:
        return EventModel(id=entity.id, url=entity.url, status=entity.status, page=entity.page)
```

**Regras do adapter:**
- Herda do port (`class XAdapter(XPort)`)
- Métodos `_to_entity()` e `_to_model()` para conversão nos repositories
- Dependências de infra recebidas via construtor (injeção)
- Pode importar de `domain/` e `infra/`, mas **nunca** de `use_cases/` ou outros adapters

### 4. Criar ORM Model (se repository)

Arquivo: `src/infra/database/models/{nome}_model.py`

```python
# src/infra/database/models/event_model.py
from sqlalchemy import Column, String, Integer
from src.infra.database.base import Base


class EventModel(Base):
    __tablename__ = "events"
    id = Column(String, primary_key=True)
    url = Column(String, nullable=False)
    status = Column(String, nullable=False)
    page = Column(Integer, nullable=True)
```

### 5. Registrar no Container

Arquivo: `src/infra/container/container.py`

```python
self.event_repo = PostgresEventRepository(session_factory)
```

### 6. Criar testes

Arquivo: `tests/unit/adapters/outbound/{tipo}/test_{nome_adapter}.py`

Para testes unitários, crie uma implementação **InMemory** do port:

```python
# tests/unit/adapters/outbound/repositories/test_postgres_event_repository.py
# Ou para testes isolados:

# tests/helpers/in_memory_event_repository.py
class InMemoryEventRepository(EventRepository):
    def __init__(self):
        self._store: dict[str, Event] = {}

    async def find_by_id(self, id: str) -> Event | None:
        return self._store.get(id)

    async def save(self, entity: Event) -> None:
        self._store[entity.id] = entity
```

### 7. Verificar

```bash
python -m pytest tests/unit/adapters/ -v
python -m ruff check src/adapters/
```

### 8. Atualizar todo.md

Marcar item como `[x]` no `.claude/tasks/todo.md`.
