# Tasks — Gestão de Trabalho

## Arquivos

| Arquivo | Propósito | Ciclo de vida |
|---------|-----------|---------------|
| `todo.md` | Checklist do batch atual | Criado a cada batch, descartado ao finalizar |
| `lessons.md` | Lições aprendidas | Acumulativo, nunca é resetado |

## Fluxo

1. **Spec aprovada** → `/start-batch [spec]` cria `todo.md`
2. **Durante o batch** → itens são marcados `[/]` (em progresso) e `[x]` (feito)
3. **Batch finalizado** → `/done` gera walkthrough e atualiza `lessons.md`
4. **`todo.md` é removido** (ou arquivado) — próximo batch cria um novo

## Formato do todo.md

```markdown
# Batch: [ID e título da spec]

- [ ] tarefa pendente
- [/] tarefa em progresso
- [x] tarefa concluída
  - sub-item se necessário
```

## Formato do lessons.md

```markdown
## [Data] — [Contexto]

**Erro**: o que aconteceu
**Causa raiz**: por que aconteceu
**Regra**: o que fazer diferente no futuro
```
