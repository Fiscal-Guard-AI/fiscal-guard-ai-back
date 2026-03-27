# ─────────────────────────────────────────────────────────────────────────────
#  Fiscal Guard AI — Makefile
#  Requirements: Docker, Docker Compose v2, Python 3.11+
#
#  Quick usage:
#    make setup      → brings up infra and applies migrations
#    make run-api    → runs the API locally (Python directly)
#    make api-up     → brings up the API in Docker container
# ─────────────────────────────────────────────────────────────────────────────

.DEFAULT_GOAL := help

COMPOSE     := docker compose
PROFILE_APP := $(COMPOSE) --profile app

# Prevents __pycache__ and .pyc generation in local make executions
export PYTHONDONTWRITEBYTECODE := 1

# ── Help ──────────────────────────────────────────────────────────────────────

.PHONY: help
help: ## Displays this help menu
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		sort | awk 'BEGIN {FS = ":.*?## "}; \
		{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ── Complete setup ────────────────────────────────────────────────────────────

.PHONY: setup
setup: infra-up migrate ## ⚡ Brings up all infra and applies migrations (entry point)

# ── Infrastructure ────────────────────────────────────────────────────────────

.PHONY: infra-up
infra-up: ## Brings up postgres, redis, localstack and mockserver (without the application)
	$(COMPOSE) up -d postgres redis localstack mockserver

.PHONY: infra-down
infra-down: ## Stops and removes all containers
	$(COMPOSE) down

.PHONY: infra-restart
infra-restart: infra-down infra-up ## Stops and brings up infra again

.PHONY: infra-clean
infra-clean: ## ⚠️  Removes containers, networks and volumes (deletes local data)
	$(COMPOSE) down -v --remove-orphans

.PHONY: infra-ps
infra-ps: ## Status of containers
	$(COMPOSE) ps

.PHONY: infra-logs
infra-logs: ## Logs of all infra (Ctrl+C to exit)
	$(COMPOSE) logs -f --tail=100 postgres redis localstack mockserver

# ── Migrations (Flyway) ───────────────────────────────────────────────────────

.PHONY: migrate
migrate: ## Applies pending migrations
	$(COMPOSE) run --rm flyway migrate

.PHONY: migrate-info
migrate-info: ## Shows the status of each migration
	$(COMPOSE) run --rm flyway info

.PHONY: migrate-repair
migrate-repair: ## Repairs checksums of migration history
	$(COMPOSE) run --rm flyway repair

.PHONY: migrate-clean
migrate-clean: ## ⚠️  DANGEROUS: deletes entire schema and reapplies (dev only)
	$(COMPOSE) run --rm -e FLYWAY_CLEAN_DISABLED=false flyway clean migrate

# ── API in Docker ─────────────────────────────────────────────────────────────

.PHONY: api-build
api-build: ## Builds the API image
	$(PROFILE_APP) build api

.PHONY: api-build-no-cache
api-build-no-cache: ## Builds the API image without cache
	$(PROFILE_APP) build --no-cache api

.PHONY: api-up
api-up: ## Brings up the API in Docker container (requires infra running)
	$(PROFILE_APP) up -d api

.PHONY: api-down
api-down: ## Stops the API container
	$(PROFILE_APP) stop api

.PHONY: api-restart
api-restart: ## Restarts the API container
	$(PROFILE_APP) restart api

.PHONY: api-logs
api-logs: ## Real-time API logs
	$(COMPOSE) logs -f api

.PHONY: api-shell
api-shell: ## Opens shell inside the API container
	$(COMPOSE) exec api bash

# ── Python dependencies ────────────────────────────────────────────────────────

.PHONY: install
install: ## Installs project dependencies (requirements.txt)
	pip install -r requirements.txt

.PHONY: install-dev
install-dev: ## Installs dev dependencies (lint, test, security)
	pip install -r requirements-dev.txt

# ── Lint & Test ───────────────────────────────────────────────────────────────

.PHONY: lint
lint: ## Runs ruff linter and format check
	python -m ruff check .
	python -m ruff format --check .

.PHONY: lint-fix
lint-fix: ## Runs ruff linter and formatter with auto-fix
	python -m ruff check --fix .
	python -m ruff format .

.PHONY: test
test: ## Runs unit tests with coverage
	python -m pytest tests/ -v --cov=src --cov-report=term

.PHONY: security
security: ## Runs bandit security analysis
	python -m bandit -r src/ -c pyproject.toml

.PHONY: clean-py
clean-py: ## Removes __pycache__ and .pyc files from the project
	python -c "import shutil, pathlib; [shutil.rmtree(p) for p in pathlib.Path('.').rglob('__pycache__')]"

# ── Local execution (Python directly, without Docker) ─────────────────────────

.PHONY: run-api
run-api: install ## Runs the API locally against Docker infra (ensures deps are installed)
	python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# ── Individual logs ────────────────────────────────────────────────────────────

.PHONY: logs-postgres
logs-postgres: ## Postgres logs
	$(COMPOSE) logs -f postgres

.PHONY: logs-redis
logs-redis: ## Redis logs
	$(COMPOSE) logs -f redis

.PHONY: logs-localstack
logs-localstack: ## LocalStack logs
	$(COMPOSE) logs -f localstack

.PHONY: logs-mockserver
logs-mockserver: ## Mockserver logs
	$(COMPOSE) logs -f mockserver
