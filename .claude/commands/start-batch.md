Inicie um novo batch de trabalho a partir de uma spec aprovada.

## Instruções

1. Leia a spec indicada pelo usuário em `.claude/specs/[spec].md`
2. Verifique que o `status` é `approved`. Se não for, avise o usuário e pare
3. Verifique se as specs em `depends_on` estão com status `done`. Se não, avise
4. Atualize o status da spec para `in-progress`
5. Crie `.claude/tasks/todo.md` com:
   - Título do batch referenciando a spec
   - Checklist detalhado derivado dos critérios de aceite e do design da spec
   - Itens granulares (um por arquivo/componente a criar/modificar)
6. Leia `.claude/tasks/lessons.md` e revise lições relevantes
7. Apresente o todo.md ao usuário e peça confirmação antes de começar a implementar

## Input esperado

O usuário deve fornecer: `/start-batch [nome-ou-número-da-spec]`

Exemplo: `/start-batch 001-event-entity`
