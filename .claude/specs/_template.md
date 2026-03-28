---
id: "NNN"
title: ""
status: draft          # draft | review | approved | in-progress | done | rejected
created: YYYY-MM-DD
author: ""
batch_size: "small"    # small (≤ meio dia) | medium (≤1 dia)
depends_on: []         # IDs de specs que precisam estar done
---

# [Título da Spec]

## Contexto

> Por que essa mudança é necessária? Qual problema resolve?

## Objetivo

> O que vai ser construído? Escopo claro e limitado.

## Fora de escopo

> O que NÃO será feito nesta spec (evita scope creep).

- ...

## Design

> Como será implementado? Quais camadas são afetadas?

### Camadas afetadas

| Camada | Arquivo | Ação |
|--------|---------|------|
| Domain | `src/domain/entities/...` | CREATE |
| Ports  | `src/domain/ports/outbound/...` | CREATE |
| Adapters | `src/adapters/outbound/...` | CREATE |

### Contratos / Interfaces

```python
# Cole aqui as interfaces/contratos principais
```

## Critérios de aceite

- [ ] ...
- [ ] ...
- [ ] Lint passando (`make lint`)
- [ ] Testes unitários passando(`make test`)
- [ ] Análise de segurança (`make security`)
- [ ]  Removes __pycache__ and pyc files (`make clean-py`)

## Notas

> Decisões, trade-offs, referências.
