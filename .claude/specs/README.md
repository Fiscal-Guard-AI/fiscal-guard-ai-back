# Specs — Spec-First Development

## O que é uma Spec?

Uma spec é um documento curto que descreve **o que** vai ser construído, **por que**, e **como** — antes de escrever qualquer código.

## Processo

1. **Criar**: copie `_template.md` ou use `/new-spec [nome]`
2. **Escrever**: preencha todos os campos obrigatórios
3. **Revisar**: peça feedback do time ou do Claude
4. **Aprovar**: marque `status: approved` no frontmatter
5. **Implementar**: use `/start-batch [spec]` para criar o todo.md

## Regras

- **Uma spec = um small batch** (1-2 dias de trabalho máximo)
- Se a feature é grande, quebre em múltiplas specs sequenciais
- Specs rejeitadas ficam com `status: rejected` e o motivo no campo `notes`
- Nunca delete specs — elas são histórico de decisão

## Nomenclatura

```
.claude/specs/
├── _template.md
├── README.md
├── 001-event-entity.md
├── 002-event-repository-port.md
├── 003-postgres-event-repository.md
└── ...
```

Prefixo numérico sequencial + nome descritivo em kebab-case.

## Status possíveis

| Status | Significado |
|--------|-------------|
| `draft` | Em elaboração |
| `review` | Aguardando revisão |
| `approved` | Aprovada, pronta para implementar |
| `in-progress` | Implementação em andamento |
| `done` | Implementada e verificada |
| `rejected` | Rejeitada (manter para histórico) |
