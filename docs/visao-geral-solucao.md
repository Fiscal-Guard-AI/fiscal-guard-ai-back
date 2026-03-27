# Visão Geral da Solução

## Sobre o Projeto

Serviço de processamento de dados que consome e processa dados do governo federal, armazenando-os em bases locais através de rotinas automatizadas. Isso possibilita consultas eficientes para análise de dados, controle de qualidade, aplicações frontend e sistemas de IA.

### O que o sistema faz

- Consome e processa dados do governo federal via APIs REST e arquivos CSV
- Armazena dados em PostgreSQL e exporta para S3 em formato Parquet
- Controle de duplicatas via hash de 64 bytes
- Processamento paginado com controle de estado
- Rate limiting via Token Bucket (1 req/s público | 700 req/s autenticado)

### O que o sistema NÃO faz

- Alterações nos dados originais
- Disponibilização de APIs públicas sem restrição
- Geração de eventos após armazenamento

## Processos

O serviço é composto por três processos principais:

- **CronJob**: Inicia o processo de verificação dos arquivos a serem baixados. Para cada processo, recebe via tabela de eventos: URL, periodicidade, última data de modificação.

- **Worker**: Recebe eventos pendentes, lê a tabela de eventos pendentes para identificar se é arquivo ou API. Para arquivos: realiza download, gera um hash único de 64 bytes, salva como Parquet com metadados apontando para o arquivo original, e armazena o conteúdo em tabela PostgreSQL. Para APIs: dispara chamadas, captura conteúdo e salva no banco. Para endpoints paginados, a tabela de eventos inclui um campo para o último ID pendente; o worker verifica novas páginas e gera novos eventos na fila. Por fim, os dados do banco são carregados e salvos no S3 com metadados e hash em formato Parquet.

- **API**: Gerencia novas configurações, como instruções para novos downloads.

## Arquitetura

### Clean Architecture

O projeto segue o padrão **Clean Architecture** em Python, garantindo baixo acoplamento, alta testabilidade e independência de frameworks e infraestrutura.

```
┌─────────────────────────────────────────────────────────────────┐
│                        Infraestrutura                          │
│  (Frameworks, Drivers, DB, Queue, S3, Cache, HTTP clients)     │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                      Adaptadores                        │   │
│  │  (Controllers, Gateways, Repositories, Presenters)      │   │
│  │                                                         │   │
│  │  ┌─────────────────────────────────────────────────┐   │   │
│  │  │               Casos de Uso                      │   │   │
│  │  │  (Regras de negócio da aplicação)               │   │   │
│  │  │                                                 │   │   │
│  │  │  ┌─────────────────────────────────────────┐   │   │   │
│  │  │  │             Domínio                     │   │   │   │
│  │  │  │  (Entidades, Value Objects, Interfaces) │   │   │   │
│  │  │  └─────────────────────────────────────────┘   │   │   │
│  │  │                                                 │   │   │
│  │  └─────────────────────────────────────────────────┘   │   │
│  │                                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Regra de dependência:** as camadas internas nunca conhecem as externas. Dependências apontam sempre de fora para dentro.

| Camada | Responsabilidade | Exemplos |
|--------|-----------------|----------|
| **Domínio** | Entidades, interfaces (ports) e regras de negócio puras | `Event`, `Config`, `EventRepository` (interface) |
| **Casos de Uso** | Orquestração das regras de negócio da aplicação | `ProcessEventUseCase`, `ScheduleDownloadUseCase` |
| **Adaptadores** | Implementações concretas das interfaces do domínio | `PostgresEventRepository`, `SQSQueueGateway`, `S3StorageGateway` |
| **Infraestrutura** | Frameworks, drivers e configuração externa | FastAPI, SQLAlchemy, boto3, Redis client, Docker |

### Estrutura de diretórios

```
src/
├── domain/                          # Camada de Domínio (núcleo)
│   ├── entities/                    # Entidades e Value Objects
│   ├── ports/                       # Interfaces / abstrações (Ports)
│   │   ├── inbound/                 # Ports de entrada (use cases interfaces)
│   │   └── outbound/               # Ports de saída (repositories, gateways)
│   └── exceptions/                  # Exceções de domínio
│
├── use_cases/                       # Camada de Casos de Uso
│   ├── process_event.py
│   ├── schedule_download.py
│   └── ...
│
├── adapters/                        # Camada de Adaptadores
│   ├── inbound/                     # Como o sistema é acionado (entrada)
│   │   ├── api/                     # Endpoints HTTP (FastAPI / Swagger)
│   │   ├── consumers/              # Consumers de filas SQS (Workers)
│   │   └── cronjobs/               # Agendadores de tarefas periódicas
│   │
│   ├── outbound/                    # Como o sistema se conecta (saída)
│   │   ├── repositories/           # Acesso a dados (PostgreSQL)
│   │   ├── storage/                # Download e upload de arquivos (S3, filesystem)
│   │   ├── queue/                  # Publicação de mensagens (SQS)
│   │   ├── cache/                  # Cache distribuído (Redis)
│   │   ├── crawler/               # Web scraping / raspagem de dados
│   │   └── api_clients/           # Clients HTTP para APIs governamentais
│   │
│   └── services/                    # Serviços transversais
│       ├── rate_limiter.py          # Token Bucket com Redis
│       └── hash_generator.py        # Geração de hash 64 bytes
│
├── infra/                           # Camada de Infraestrutura
│   ├── config/                      # Configurações da aplicação
│   ├── database/                    # Conexão e migrations (SQLAlchemy)
│   ├── logging/                     # Log estruturado (JSON)
│   └── container/                   # Injeção de dependências
│
├── main.py                          # Bootstrap da aplicação
├── scripts/
│   ├── mockserver/                  # Mock de APIs externas
│   ├── tests/                       # Dados de teste, dataset, yamls
│   ├── flyway/                      # Migração de banco de dados
│   ├── terraform/                   # IaC por ambiente
│   │   ├── local/
│   │   └── prod/
│   ├── helm/
│   │   └── prod/                    # Helm por Ambiente
│   └── docker/                      # Dockerfile
│
└── docker-compose.yml               # docker-compose para teste local
```

**Mapeamento dos processos na estrutura:**

| Processo | Localização | Descrição |
|----------|------------|-----------|
| **CronJob** | `adapters/inbound/cronjobs/` | Agendadores que disparam verificação de downloads pendentes |
| **Consumer (Worker)** | `adapters/inbound/consumers/` | Listeners de fila SQS que processam eventos |
| **API** | `adapters/inbound/api/` | Endpoints REST internos (FastAPI) |
| **Storage** | `adapters/outbound/storage/` | Download de CSVs, upload de Parquet para S3 |
| **WebCrawler** | `adapters/outbound/crawler/` | Raspagem de dados de páginas web |
| **API Clients** | `adapters/outbound/api_clients/` | Chamadas às APIs do Portal da Transparência e Datalake |

### Log Estruturado

Logging em formato **JSON estruturado** em todas as camadas, facilitando:
- Observabilidade e rastreamento de eventos
- Integração com ferramentas de monitoramento
- Correlação entre processos (CronJob, Worker, API) via `correlation_id`

### Diagrama de fluxo

```mermaid
flowchart TB
    cron["CronJob"] --> configService["Config Service"]
    api["API Interna"] --> configService

    configService --> tableConfig[("Table Config")]
    configService --> eventDispatcher["Event Dispatcher"]
    eventDispatcher --> tableEvents[("Table Events")]
    eventDispatcher -- "envia mensagem" --> queue["SQS Queue"]

    queue -- "consome evento" --> worker["Worker"]
    worker --> processor["Processor"]

    processor -- "carrega evento pendente" --> tableEvents
    processor --> rateLimiter["Rate Limiter - Token Bucket"]
    rateLimiter --> cache[("Redis Cache")]

    rateLimiter --> decision{"Limite atingido?"}
    decision -- "Sim: requeue com TTL" --> queue
    decision -- "Não: processa" --> apiGov["APIs Governo Federal"]

    apiGov -- "salva dados" --> postgres[("PostgreSQL")]
    postgres --> pagination{"Próxima página?"}
    pagination -- "Sim" --> tableEvents
    pagination -- "Sim: novo evento" --> queue
    pagination -- "Não" --> s3["S3 - Parquet + Metadados"]
    s3 --> done["Fim do Processamento"]
```

## Estratégia de Desenvolvimento

- Utilização de interfaces e mocks para independência da infraestrutura durante desenvolvimento e testes
- Consumo de dados via APIs REST com execução diária em horários fixos
- Banco de dados: a estrutura PostgreSQL e modelagem de dados serão finalizadas durante o desenvolvimento

## Desafios

- Endpoints sem ID explícito — estratégia de deduplicação por coleção
- Rate limit de **1 req/s** (público) e **700 req/s** (autenticado)
- Campos com dados sensíveis não podem ser expostos em produção
- Testes de integração com APIs externas sem sandbox
- Uso de mocks e containers locais enquanto a esteira DevOps não está pronta
- Dependências de recursos de infraestrutura (Redis/SQS, banco de dados)
- Uso de chaves API pessoais durante testes

## Evolução Futura

- Traces e métricas (OpenTelemetry)
- Monorepo
