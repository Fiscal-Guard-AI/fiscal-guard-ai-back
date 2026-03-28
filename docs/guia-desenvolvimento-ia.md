# Guia de Desenvolvimento com IA — Fiscal Guard AI

Este guia documenta o workflow de desenvolvimento do projeto usando Claude Code com **spec-first** e **small batches**.

## Visao Geral do Workflow

```
Spec (definicao) --> Aprovacao --> Batch (implementacao) --> Code Review --> Done
```

O desenvolvimento segue um ciclo disciplinado: nada e implementado sem uma spec aprovada. Cada spec representa no maximo 1 dia de trabalho.

## Estrutura do `.claude/`

```
.claude/
├── CLAUDE.md              # Regras gerais do agente
├── specs/                 # Definicoes de features
│   ├── _template.md       # Template para novas specs
│   └── NNN-nome.md        # Specs numeradas sequencialmente
├── tasks/                 # Gestao de trabalho
│   ├── lessons.md         # Licoes aprendidas (acumulativo)
│   └── todo.md            # Checklist do batch atual (temporario)
├── commands/              # Slash commands
│   ├── new-spec.md        # /new-spec [nome]
│   ├── start-batch.md     # /start-batch [spec]
│   └── done.md            # /done
├── skills/                # Instrucoes step-by-step
│   ├── new-entity.md      # Criar entity de dominio
│   ├── new-port.md        # Criar port (interface ABC)
│   └── new-adapter.md     # Implementar adapter concreto
└── agents/                # Subagentes autonomos
    └── code-reviewer.md   # Revisao contra Clean Architecture
```

| Tipo | O que e | Quando usar |
|------|---------|-------------|
| **Commands** | Slash commands que orquestram o workflow | Iniciar/finalizar etapas |
| **Skills** | Receitas que o agente segue no contexto atual | Criar componentes padronizados |
| **Agents** | Subagentes isolados com contexto fresco | Delegacao de tarefas autonomas |

---

## Passo a Passo Completo

### 1. Criar uma Spec

```
voce: /new-spec postgres event repository
```

O agente cria `.claude/specs/002-postgres-event-repository.md` com o template preenchido:

```markdown
---
id: "002"
title: "Postgres Event Repository"
status: draft
created: 2026-03-28
author: "Tiago"
batch_size: "small"
depends_on: ["001"]
---

# Postgres Event Repository

## Contexto
> O EventRepository port ja existe. Precisamos da implementacao concreta
> usando PostgreSQL para persistir eventos.

## Objetivo
> Criar o adapter PostgresEventRepository, o ORM model EventModel,
> e registrar no container de DI.

## Fora de escopo
- Migrations (Flyway gerencia separadamente)
- Testes de integracao com banco real

## Design

### Camadas afetadas

| Camada | Arquivo | Acao |
|--------|---------|------|
| Infra | `src/infra/database/models/event_model.py` | CREATE |
| Adapter | `src/adapters/outbound/repositories/postgres_event_repository.py` | CREATE |
| Infra | `src/infra/container/container.py` | MODIFY |
| Tests | `tests/unit/adapters/outbound/repositories/test_postgres_event_repository.py` | CREATE |

### Contratos / Interfaces

(interfaces do adapter, conversoes entity <-> model)

## Criterios de aceite

- [ ] EventModel criado com SQLAlchemy
- [ ] PostgresEventRepository implementa EventRepository
- [ ] Conversao _to_entity / _to_model funcionando
- [ ] Registrado no container
- [ ] Testes unitarios com InMemory passando
- [ ] `make lint` passando
- [ ] `make test` passando
```

### 2. Revisar e Aprovar

Discuta o design com o agente. Quando estiver satisfeito:

```
voce: aprovar spec
```

O agente muda `status: draft` para `status: approved`.

### 3. Iniciar o Batch

```
voce: start-batch
```

O agente:
1. Verifica que a spec esta `approved`
2. Verifica que dependencias (`depends_on`) estao `done`
3. Muda a spec para `status: in-progress`
4. Cria `.claude/tasks/todo.md` com checklist granular
5. Revisa `lessons.md` para erros passados relevantes
6. Apresenta o plano e pede confirmacao

Exemplo de `todo.md` gerado:

```markdown
# Batch: 002 — Postgres Event Repository

> Spec: `.claude/specs/002-postgres-event-repository.md`

## Checklist

### ORM Model: `src/infra/database/models/event_model.py`
- [ ] Criar EventModel com colunas: id, url, status, source_type, page, ...
- [ ] Exportar no __init__.py

### Adapter: `src/adapters/outbound/repositories/postgres_event_repository.py`
- [ ] Implementar PostgresEventRepository(EventRepository)
- [ ] Metodo find_by_id
- [ ] Metodo find_pending
- [ ] Metodo save
- [ ] Metodo update_status
- [ ] Conversao _to_entity / _to_model

### Container: `src/infra/container/container.py`
- [ ] Registrar PostgresEventRepository

### Tests
- [ ] Criar InMemoryEventRepository para testes
- [ ] Testar find_by_id, save, find_pending, update_status

### Verificacao
- [ ] `make lint` passando
- [ ] `make test` passando
```

### 4. Implementar

```
voce: pode comecar
```

O agente implementa seguindo o checklist, marcando progresso em `todo.md`. Ele usa **skills** para componentes padronizados:

- **`new-entity`** — cria entity + testes (dataclass pura, sem framework)
- **`new-port`** — cria interface ABC async no dominio
- **`new-adapter`** — cria adapter concreto + schema + registro no container + testes

### 5. Code Review

Antes de fechar, rode o reviewer:

```
voce: code-reviewer
```

O agente delega para um **subagente isolado** que revisa contra Clean Architecture:

```markdown
## Code Review — Batch 002

### Aprovados
- postgres_event_repository.py: imports corretos, herda do port

### Avisos (nao bloqueantes)
- event_model.py:15: considerar adicionar index na coluna status

### Violacoes (bloqueantes)
- (nenhuma)

### Resultado: APROVADO
```

### 6. Finalizar

```
voce: /done
```

O agente:
1. Verifica que todos os itens do `todo.md` estao `[x]`
2. Roda `make clean-py`, `make security`, `make lint`, `make test`
3. Muda a spec para `status: done`
4. Pergunta se houve licoes aprendidas
5. Gera walkthrough das mudancas
6. Remove `todo.md`

---

## Arquitetura Clean — Regras de Dependencia

```
adapters --> domain <-- use_cases
infra --> adapters, domain, use_cases
```

| Camada | Pode importar de | NAO pode importar de |
|--------|-------------------|----------------------|
| `domain/entities/` | stdlib, domain/exceptions | adapters, infra, use_cases |
| `domain/ports/` | domain/entities | adapters, infra, use_cases |
| `use_cases/` | domain (entities + ports) | adapters, infra |
| `adapters/` | domain, infra | use_cases, outros adapters |
| `infra/` | qualquer camada | — |

### Nomenclatura

| Componente | Convencao | Exemplo |
|------------|-----------|---------|
| Entity | PascalCase, sem sufixo | `Event` |
| Port (repo) | `{Entity}Repository` | `EventRepository` |
| Port (gateway) | `{Servico}Gateway` | `StorageGateway` |
| Port (client) | `{API}Client` | `TransparenciaClient` |
| Adapter | prefixo de tecnologia | `PostgresEventRepository` |
| ORM Model | sufixo `Model` | `EventModel` |
| Schema | sufixo descritivo | `EventMessage` |

---

## Exemplos Praticos por Componente

### Entity (dominio puro)

```python
# src/domain/entities/event.py
from dataclasses import dataclass, field
from datetime import UTC, datetime

from src.domain.exceptions.event_exceptions import InvalidEventStatusError

VALID_STATUSES = frozenset({"pending", "processing", "done", "failed"})

@dataclass
class Event:
    id: str
    url: str
    status: str
    source_type: str
    page: int | None = None
    created_at: datetime = field(default_factory=lambda: datetime.now(UTC))
    updated_at: datetime | None = None

    def __post_init__(self) -> None:
        if self.status not in VALID_STATUSES:
            raise InvalidEventStatusError(f"Invalid status '{self.status}'")

    @property
    def is_pending(self) -> bool:
        return self.status == "pending"

    def mark_processing(self) -> None:
        self._transition_to("processing")
```

**Regras:**
- `@dataclass`, nunca Pydantic
- Validacoes no `__post_init__`
- Logica de negocio como metodos
- Zero imports de frameworks

### Port (interface abstrata)

```python
# src/domain/ports/outbound/event_repository.py
from abc import ABC, abstractmethod
from src.domain.entities.event import Event


class EventRepository(ABC):
    @abstractmethod
    async def find_by_id(self, id: str) -> Event | None: ...

    @abstractmethod
    async def find_pending(self) -> list[Event]: ...

    @abstractmethod
    async def save(self, event: Event) -> None: ...
```

**Regras:**
- `ABC` + `@abstractmethod`
- Sempre async
- Parametros e retornos sao entities do dominio

### Adapter (implementacao concreta)

```python
# src/adapters/outbound/repositories/postgres_event_repository.py
from src.domain.entities.event import Event
from src.domain.ports.outbound.event_repository import EventRepository
from src.infra.database.models.event_model import EventModel


class PostgresEventRepository(EventRepository):
    def __init__(self, session_factory):
        self._session_factory = session_factory

    async def find_by_id(self, id: str) -> Event | None:
        async with self._session_factory() as session:
            model = await session.get(EventModel, id)
            return self._to_entity(model) if model else None

    async def save(self, event: Event) -> None:
        async with self._session_factory() as session:
            session.add(self._to_model(event))
            await session.commit()

    def _to_entity(self, model: EventModel) -> Event:
        return Event(id=model.id, url=model.url, status=model.status, ...)

    def _to_model(self, entity: Event) -> EventModel:
        return EventModel(id=entity.id, url=entity.url, status=entity.status, ...)
```

**Regras:**
- Herda do port
- Dependencias via construtor (DI)
- `_to_entity()` / `_to_model()` para conversao
- Pode importar de `domain/` e `infra/`, nunca de `use_cases/`

### Testes (entity — sem mocks)

```python
# tests/unit/domain/entities/test_event.py
import pytest
from src.domain.entities.event import Event
from src.domain.exceptions.event_exceptions import InvalidEventStatusError


class TestEventCreation:
    def test_create_valid_event(self):
        event = Event(id="1", url="https://example.com", status="pending", source_type="file")
        assert event.status == "pending"

    def test_invalid_status_raises(self):
        with pytest.raises(InvalidEventStatusError):
            Event(id="1", url="https://example.com", status="unknown", source_type="file")


class TestStatusTransitions:
    def test_mark_processing(self):
        event = Event(id="1", url="https://example.com", status="pending", source_type="file")
        event.mark_processing()
        assert event.status == "processing"

    def test_invalid_transition(self):
        event = Event(id="1", url="https://example.com", status="pending", source_type="file")
        with pytest.raises(InvalidEventStatusError):
            event.mark_done()  # pending -> done nao e permitido
```

---

## Licoes Aprendidas

O arquivo `.claude/tasks/lessons.md` e acumulativo e nunca e resetado. Sempre que algo der errado durante um batch, o agente registra:

```markdown
## 2026-03-28 — Batch 001

**Erro**: import no final do arquivo para evitar circular dependency
**Causa raiz**: nao havia dependencia circular, foi precaucao desnecessaria
**Regra**: verificar se a dependencia circular realmente existe antes de usar workarounds
```

O agente consulta esse arquivo no inicio de cada batch para evitar repetir erros.

---

## Comandos Uteis

| Comando | O que faz |
|---------|-----------|
| `make lint` | Roda ruff check + format |
| `make test` | Roda pytest com coverage |
| `make security` | Roda bandit (analise de seguranca) |
| `make clean-py` | Remove `__pycache__` e `.pyc` |

---

## Git — Regras

O agente **nunca** executa comandos de escrita no git. Apenas comandos de leitura sao permitidos (`git status`, `git diff`, `git log`). O usuario e responsavel por commits, pushes e merges.
