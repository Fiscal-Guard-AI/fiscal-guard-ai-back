# Skill: New Port

Cria uma interface (port) no domínio — contrato abstrato que define o que o sistema precisa, sem dizer como.

## Decidir o tipo

| Tipo | Quando usar | Pasta |
|------|-------------|-------|
| **Inbound** | Define como o mundo externo aciona o sistema (interface de use case) | `domain/ports/inbound/` |
| **Outbound** | Define como o sistema acessa recursos externos (repo, gateway, storage) | `domain/ports/outbound/` |

## Checklist

### 1. Criar o Port

Arquivo: `src/domain/ports/{inbound|outbound}/{nome_port}.py`

```python
# src/domain/ports/outbound/{nome}_repository.py
from abc import ABC, abstractmethod
from src.domain.entities.{entity} import {Entity}


class {Nome}Repository(ABC):
    """
    Port de saída para acesso a dados de {Entity}.
    Implementado por adapters concretos (ex: Postgres, InMemory).
    """

    @abstractmethod
    async def find_by_id(self, id: str) -> {Entity} | None:
        ...

    @abstractmethod
    async def find_all(self) -> list[{Entity}]:
        ...

    @abstractmethod
    async def save(self, entity: {Entity}) -> None:
        ...

    @abstractmethod
    async def delete(self, id: str) -> None:
        ...
```

**Regras:**
- Sempre usar `ABC` + `@abstractmethod`
- Métodos async por padrão (mesmo que implementação seja sync)
- Parâmetros e retornos usam **entities do domínio**, nunca models ORM ou DTOs
- Nunca importe nada de `adapters/` ou `infra/`
- Docstring explicando o propósito e quem implementa

### 2. Nomear corretamente

| Tipo de port | Convenção de nome | Exemplo |
|---|---|---|
| Repository (dados) | `{Entity}Repository` | `EventRepository` |
| Gateway (serviço externo) | `{Serviço}Gateway` | `StorageGateway`, `QueueGateway` |
| Client (API externa) | `{API}Client` | `TransparenciaClient` |

### 3. Exportar no `__init__.py`

Arquivo: `src/domain/ports/{inbound|outbound}/__init__.py`

```python
from .{nome}_repository import {Nome}Repository

__all__ = ["{Nome}Repository"]
```

### 4. Verificar

```bash
python -c "from src.domain.ports.outbound.{nome}_repository import {Nome}Repository; print('OK')"
python -m ruff check src/domain/ports/
```

### 5. Atualizar todo.md

Marcar item como `[x]` no `.claude/tasks/todo.md`.

> **Nota:** O port sozinho não faz nada — ele precisa de um adapter que o implemente. Use a skill `new-adapter` em seguida.
