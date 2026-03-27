## Descrição

<!-- Descreva de forma clara o que foi feito e por quê. -->

## Tipo de mudança

- [ ] Bug fix
- [ ] Nova feature
- [ ] Refatoração
- [ ] Documentação
- [ ] Configuração / Infra
- [ ] Teste

## Como testar

<!-- Passos para o reviewer validar a mudança. -->

1.
2.
3.

## Checklist antes de submeter

Execute os comandos abaixo e confirme que todos passaram:

```bash
make lint        # Ruff linter + format check
make test        # Testes unitários com cobertura
make security    # Análise de segurança (Bandit)
```

- [ ] `make lint` passou sem erros
- [ ] `make test` passou sem falhas
- [ ] `make security` passou sem alertas críticos
- [ ] Código segue os padrões do projeto (Clean Architecture, naming conventions)
- [ ] Testes adicionados/atualizados para cobrir a mudança
- [ ] Sem secrets, credenciais ou dados sensíveis no código
- [ ] Documentação atualizada (se aplicável)
- [ ] Migrations de banco revisadas (se aplicável)

## Screenshots / Logs

<!-- Se aplicável, adicione evidências visuais ou logs relevantes. -->

## Observações para o reviewer

<!-- Algo que o reviewer precisa saber? Pontos de atenção, trade-offs, débitos técnicos? -->
