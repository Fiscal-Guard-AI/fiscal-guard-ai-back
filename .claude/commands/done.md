Finalize o batch atual.

## Instruções

1. Leia `.claude/tasks/todo.md` e verifique que todos os itens estão `[x]`
   - Se houver itens pendentes, liste-os e pergunte se devem ser descartados ou completados
2. Execute verificações:
   - `make clean-py` — deve passar sem erros
   - `make security` — deve passar sem erros
   - `make lint` — deve passar sem erros
   - `make test` — todos os testes devem passar
3. Atualize a spec correspondente (em `.claude/specs/`) para `status: done`
4. Pergunte ao usuário:
   - "Houve algum erro, surpresa ou lição durante este batch?"
   - Se sim, adicione a lição em `.claude/tasks/lessons.md` no formato padrão
5. Gere um resumo do que foi feito (walkthrough):
   - Arquivos criados/modificados
   - Decisões tomadas
   - Testes adicionados
6. Remova `.claude/tasks/todo.md` (o batch está encerrado)
7. Informe: "Batch finalizado. Pronto para a próxima spec."

## Input esperado

O usuário deve fornecer: `/done`
