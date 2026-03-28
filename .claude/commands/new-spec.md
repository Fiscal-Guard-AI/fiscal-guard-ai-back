Crie uma nova spec a partir do template `.claude/specs/_template.md`.

## Instruções

1. Leia o template em `.claude/specs/_template.md`
2. Liste as specs existentes em `.claude/specs/` para determinar o próximo número sequencial (formato `NNN`)
3. Crie o arquivo `.claude/specs/[NNN]-[nome-kebab-case].md` com o template preenchido:
   - `id`: número sequencial
   - `created`: data de hoje
   - `status`: `draft`
4. Preencha os campos **Contexto** e **Objetivo** com base na descrição fornecida pelo usuário
5. Deixe os demais campos para o usuário completar ou peça informações adicionais
6. Mostre o arquivo criado e pergunte se o usuário quer ajustar algo

## Input esperado

O usuário deve fornecer: `/new-spec [nome descritivo da feature]`

Exemplo: `/new-spec event entity and repository port`
