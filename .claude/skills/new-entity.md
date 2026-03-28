# Skill: New Entity

Cria uma entidade de domínio pura, sem dependência de frameworks.

## Checklist

### 1. Criar a Entity

Arquivo: `src/domain/entities/{nome_entity}.py`

```python
# src/domain/entities/{nome}.py
from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class {Nome}:
    """
    {Descrição curta da entidade e seu papel no domínio.}
    """
    id: str
    # ... campos do domínio

    created_at: datetime = field(default_factory=datetime.utcnow)
    updated_at: datetime | None = None
```

**Regras:**
- Use `@dataclass` — sem Pydantic, sem SQLAlchemy, sem framework
- Propriedades computadas via `@property`
- Lógica de negócio como métodos da entity (ex: `has_next_page`, `is_expired`)
- Validações de domínio no `__post_init__` se necessário
- Nunca importe nada de `adapters/`, `infra/`, ou `use_cases/`

### 2. Exportar no `__init__.py`

Arquivo: `src/domain/entities/__init__.py`

```python
from .{nome} import {Nome}

__all__ = ["{Nome}"]
```

### 3. Criar testes unitários

Arquivo: `tests/unit/domain/entities/test_{nome}.py`

```python
# tests/unit/domain/entities/test_{nome}.py

from src.domain.entities.{nome} import {Nome}


class Test{Nome}:
    def test_create(self):
        entity = {Nome}(id="1", ...)
        assert entity.id == "1"

    def test_propriedade_computada(self):
        """Testar cada @property e método de negócio."""
        ...

    def test_validacao_dominio(self):
        """Testar regras de __post_init__ se existirem."""
        ...
```

**Regras de teste:**
- Testar criação com campos obrigatórios
- Testar cada `@property` e método de negócio
- Testar validações de domínio (se existirem)
- Sem mocks — entity é pura, não depende de nada externo

### 4. Verificar

```bash
python -m pytest tests/unit/domain/entities/test_{nome}.py -v
python -m ruff check src/domain/entities/{nome}.py
```

### 5. Atualizar todo.md

Marcar item como `[x]` no `.claude/tasks/todo.md`.
