# Fiscal Guard AI - Backend

## Visão Geral

Sistema de ingestão e processamento de dados abertos do governo federal brasileiro. O serviço consome dados via APIs REST e arquivos CSV, processa e armazena localmente com controle de duplicatas, versionamento e rastreabilidade.

**Fontes de dados:**
- [Portal da Transparência](https://api.portaldatransparencia.gov.br/swagger-ui/index.html#/)
- [API Datalake Tesouro](https://apidatalake.tesouro.gov.br/docs/custos/#api-_)

O serviço é composto por 3 processos principais:

| Processo | Responsabilidade |
|----------|-----------------|
| **CronJob** | Verifica periodicamente quais dados precisam ser baixados e dispara eventos na fila |
| **Worker** | Consome eventos da fila e processa: download de arquivos CSV, chamadas a APIs paginadas, persistência no PostgreSQL e exportação para S3 |
| **API** | Endpoint interno para configurar novas instruções de download, disparar reprocessamentos e controle de qualidade |

## Tech Stack

| Tecnologia | Finalidade |
|-----------|-----------|
| **Python 3.11+** | Linguagem principal |
| **FastAPI** | API REST com documentação Swagger |
| **PostgreSQL** | Banco de dados relacional |
| **Redis** | Cache distribuído e controle de rate limit |
| **AWS SQS** | Fila de mensagens |
| **AWS S3** | Armazenamento de arquivos Parquet |
| **Docker / Docker Compose** | Containerização e ambiente local |

## Pré-requisitos

- Python 3.11+
- Docker e Docker Compose
  - Redis
  - Localstack (SQS, S3)
  - Flyway
  - PostgreSQL
  - Mockserver
- Chaves de API para os portais de dados (para testes com dados reais)

## Documentação

| Documento | Descrição |
|-----------|-----------|
| [Visão Geral da Solução](docs/visao-geral-solucao.md) | Arquitetura, fluxos, estrutura de diretórios e desafios técnicos |
| [Exemplos - Clean Architecture](docs/exemplos.md) | Exemplos de código seguindo Clean Architecture em Python |

## Open Source and Community

This repository is released under the [MIT License](LICENSE), which allows reuse in commercial and government contexts provided attribution is preserved. Contributions from the community are welcome — review [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and reference the [Code of Conduct](Code%20of%20Conduct.md) when engaging with other contributors.
