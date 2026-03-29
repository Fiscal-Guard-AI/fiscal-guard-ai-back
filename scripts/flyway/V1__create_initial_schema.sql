-- ─────────────────────────────────────────────────────────────────────────────
--  V2 — Schema de download do Fiscal Guard AI
--
--  Tabelas:
--    download_config          → configurações de coleta periódica
--    download_extract_sources → mapeamento de arquivos dentro de ZIP/XLSX
--    upload_file_events       → rastreamento de upload de arquivos para S3
--    download_url_events      → rastreamento de download paginado via API
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Enums ────────────────────────────────────────────────────────────────────

CREATE TYPE source_type AS ENUM ('API', 'CSV', 'XLSX', 'ZIP');

CREATE TYPE period_type AS ENUM ('YEAR', 'MONTH');

CREATE TYPE file_origin AS ENUM ('URL', 'DATABASE');

CREATE TYPE event_status AS ENUM (
    'PENDING',      -- aguardando processamento
    'PROCESSING',   -- sendo processado pelo worker
    'DONE',         -- concluído com sucesso
    'FAILED',       -- falhou (ver error_message)
    'REQUEUE'       -- reenfileirado por rate limit ou erro transitório
);

-- ── download_config ──────────────────────────────────────────────────────────
-- Uma linha por fonte de dados monitorada pelo CronJob.

CREATE TABLE download_config (
    download_config_id  BIGSERIAL    PRIMARY KEY,                    -- identificador único sequencial da configuração
    cron_expression     VARCHAR(50)  NOT NULL,                       -- expressão cron para disparo pelo CronJob ex: "0 3 * * *" (diário às 03h)
    is_active           BOOLEAN      NOT NULL DEFAULT TRUE,          -- indica se a configuração está ativa para execução pelo CronJob
    last_run_at         TIMESTAMPTZ,                                 -- data/hora da última execução realizada
    next_run_at         TIMESTAMPTZ,                                 -- data/hora da próxima execução calculada a partir do cron_expression
    source_name         VARCHAR(50)  NOT NULL,                       -- identificador único legível da fonte (slug) ex: "contratos_mec"
    destiny_name        VARCHAR(40)  DEFAULT NULL,                   -- nome de destino para tabela e path S3 — NULL quando source_type é ZIP ou XLSX
    description         TEXT,                                        -- descrição livre da fonte de dados
    period_type         period_type  NOT NULL,                       -- granularidade do período: YEAR ou MONTH — define estrutura de pastas no S3 e sufixo da tabela
    source_type         source_type  NOT NULL,                       -- tipo da fonte: API, CSV, XLSX ou ZIP — determina o fluxo de processamento
    period              DATE         NOT NULL,                       -- data de referência do período sendo coletado
    url                 TEXT         NOT NULL,                       -- URL da fonte de dados (endpoint API ou link de download)
    http_method         VARCHAR(10)  NOT NULL DEFAULT 'GET',         -- método HTTP utilizado na requisição (GET, POST, etc.)
    params              JSONB        NOT NULL DEFAULT '{}',          -- query params fixos incluídos em todas as requisições
    headers             JSONB        NOT NULL DEFAULT '{}',          -- headers HTTP (sem valores de credenciais em produção)
    requires_auth       BOOLEAN      NOT NULL DEFAULT FALSE,         -- indica se a fonte exige autenticação para acesso
    last_modification   TIMESTAMP    DEFAULT NULL,                   -- data de última modificação informada pela fonte (header ou metadado)
    last_hash           VARCHAR(100) DEFAULT NULL,                   -- hash do último conteúdo baixado — usado para deduplicação entre execuções
    created_at          TIMESTAMPTZ  NOT NULL,                       -- data/hora de criação do registro
    updated_at          TIMESTAMPTZ  NOT NULL,                       -- data/hora da última atualização do registro

    UNIQUE (destiny_name),
    UNIQUE (source_name),
    UNIQUE (url, http_method, source_type)
);

-- CronJob: busca configs ativas com próximo run vencido
CREATE INDEX idx_config_next_run ON download_config (next_run_at) WHERE is_active = TRUE;

-- ── download_extract_sources ─────────────────────────────────────────────────
-- Mapeamento de arquivos dentro de ZIP ou abas de XLSX.

CREATE TABLE download_extract_sources (
    download_config_id  BIGINT      REFERENCES download_config (download_config_id) ON DELETE CASCADE, -- referência à configuração de download pai
    source_name         VARCHAR(50) NOT NULL,  -- nome do arquivo (zip) ou aba (xlsx) a ser extraído
    destiny_name        VARCHAR(50) NOT NULL,  -- nome do destino — usado como nome de tabela e path no S3

    PRIMARY KEY (destiny_name),
    UNIQUE (download_config_id, source_name)
);

-- ── upload_file_events ───────────────────────────────────────────────────────
-- Rastreamento de cada arquivo enviado para o S3.

CREATE TABLE upload_file_events (
    upload_file_event_id  BIGSERIAL    PRIMARY KEY,                                                    -- identificador único sequencial do evento de upload
    download_config_id    BIGINT       NOT NULL REFERENCES download_config (download_config_id) ON DELETE CASCADE, -- referência à configuração de download que originou este upload
    content_hash          CHAR(64),                                                                    -- SHA-256 do payload (64 hex chars) — garante deduplicação entre execuções
    metadata              JSONB        NOT NULL DEFAULT '{}',                                           -- metadados capturados do arquivo ou headers da requisição — salvos junto ao Parquet
    correlation_id        VARCHAR(60)  NOT NULL,                                                        -- agrupa todos os eventos de uma mesma execução de download
    s3_key                TEXT,                                                                         -- caminho completo (bucket + objeto) do Parquet no S3 após processamento
    origin                file_origin  NOT NULL DEFAULT 'URL',                                          -- origem do arquivo: URL (download direto) ou DATABASE (gerado a partir de dados do banco)
    table_name            VARCHAR(50)  DEFAULT NULL,                                                    -- nome da tabela PostgreSQL onde o conteúdo foi persistido
    status                event_status NOT NULL DEFAULT 'PENDING',                                      -- estado atual do evento: PENDING, PROCESSING, DONE, FAILED ou REQUEUE
    error_message         TEXT,                                                                         -- mensagem de erro quando status = FAILED
    retry_count           INTEGER      NOT NULL DEFAULT 0,                                              -- quantidade de tentativas de processamento realizadas
    processed_at          TIMESTAMPTZ,                                                                  -- data/hora em que o processamento foi concluído (sucesso ou falha)
    created_at            TIMESTAMPTZ  NOT NULL,                                                        -- data/hora de criação do registro
    updated_at            TIMESTAMPTZ  NOT NULL                                                         -- data/hora da última atualização do registro
);

CREATE INDEX idx_upload_events_status       ON upload_file_events (status);              -- worker busca pendentes
CREATE INDEX idx_upload_events_config_id    ON upload_file_events (download_config_id);   -- consultas por config
CREATE INDEX idx_upload_events_correlation  ON upload_file_events (correlation_id);       -- rastreabilidade
CREATE INDEX idx_upload_events_content_hash ON upload_file_events (content_hash);         -- deduplicação por hash

-- ── download_url_events ──────────────────────────────────────────────────────
-- Rastreamento de cada página baixada via API.

CREATE TABLE download_url_events (
    download_url_event_id  BIGSERIAL    PRIMARY KEY,                                                    -- identificador único sequencial do evento de download
    download_config_id     BIGINT       NOT NULL REFERENCES download_config (download_config_id) ON DELETE CASCADE, -- referência à configuração de download que originou este evento
    status                 event_status NOT NULL DEFAULT 'PENDING',                                      -- estado atual do evento: PENDING, PROCESSING, DONE, FAILED ou REQUEUE
    page                   INTEGER      NOT NULL DEFAULT 1,                                              -- número da página sendo processada neste evento
    params                 JSONB        NOT NULL DEFAULT '{}',                                            -- query params da requisição — pode conter placeholders ex: {"page": "$page$"}
    table_name             VARCHAR(50)  NOT NULL,                                                         -- nome da tabela PostgreSQL de destino onde o conteúdo da página é salvo
    total_pages            INTEGER      DEFAULT NULL,                                                     -- total de páginas disponíveis — NULL quando o endpoint não informa
    headers                JSONB        NOT NULL DEFAULT '{}',                                            -- headers HTTP para a requisição desta página
    correlation_id         VARCHAR(60)  NOT NULL,                                                         -- agrupa todas as páginas de uma mesma execução de download
    s3_key                 TEXT,                                                                          -- caminho completo (bucket + objeto) do Parquet no S3 após consolidação
    error_message          TEXT,                                                                          -- mensagem de erro quando status = FAILED
    retry_count            INTEGER      NOT NULL DEFAULT 0,                                               -- quantidade de tentativas de processamento realizadas
    processed_at           TIMESTAMPTZ,                                                                   -- data/hora em que o processamento foi concluído (sucesso ou falha)
    created_at             TIMESTAMPTZ  NOT NULL,                                                         -- data/hora de criação do registro
    updated_at             TIMESTAMPTZ  NOT NULL                                                          -- data/hora da última atualização do registro
);

CREATE INDEX idx_download_events_status       ON download_url_events (status);          -- worker busca pendentes
CREATE INDEX idx_download_events_config_id    ON download_url_events (download_config_id); -- consultas por config
CREATE INDEX idx_download_events_correlation  ON download_url_events (correlation_id);   -- rastreabilidade
CREATE INDEX idx_download_events_processed_at ON download_url_events (processed_at);     -- auditoria por data de processamento
