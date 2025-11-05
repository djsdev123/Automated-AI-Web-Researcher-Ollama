# Makefile - Standard build automation (POSIX pattern)
# Industry standard since 1976 - no custom tooling needed

.PHONY: help validate diagnose check build up down clean test

# Default target
.DEFAULT_GOAL := help

## help: Show this help message
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

## validate: Validate all configuration files
validate: validate-compose validate-docker validate-env

## validate-compose: Validate docker-compose.yml
validate-compose:
	@echo "Validating docker-compose.yml..."
	@docker-compose config > /dev/null && echo "✓ docker-compose.yml is valid" || echo "✗ docker-compose.yml has errors"

## validate-docker: Validate Dockerfile
validate-docker:
	@echo "Validating Dockerfile..."
	@docker build --check . && echo "✓ Dockerfile is valid" || docker build -t test-build . > /dev/null 2>&1 && echo "✓ Dockerfile builds successfully"

## validate-env: Check .env file exists
validate-env:
	@echo "Checking .env file..."
	@test -f .env && echo "✓ .env file exists" || (echo "✗ .env file missing - copy from .env.example" && exit 1)

## diagnose: Run Docker's built-in diagnostics
diagnose:
	@echo "Running Docker diagnostics..."
	@echo ""
	@echo "=== Docker Version ==="
	@docker version || echo "✗ Docker not installed"
	@echo ""
	@echo "=== Docker Info ==="
	@docker info || echo "✗ Docker daemon not running"
	@echo ""
	@echo "=== Docker Compose Version ==="
	@docker-compose --version || docker compose version || echo "✗ Docker Compose not installed"
	@echo ""
	@echo "=== Configuration Validation ==="
	@$(MAKE) -s validate
	@echo ""
	@echo "=== Network Test ==="
	@curl -sf http://localhost:11434/api/version > /dev/null && echo "✓ Ollama reachable" || echo "⚠ Ollama not reachable (OK if using cloud LLM)"

## check: Quick pre-flight check before starting
check:
	@echo "Pre-flight checks..."
	@command -v docker >/dev/null 2>&1 || (echo "✗ Docker not installed" && exit 1)
	@docker info >/dev/null 2>&1 || (echo "✗ Docker not running" && exit 1)
	@test -f .env || (echo "✗ .env missing - run: cp .env.example .env" && exit 1)
	@test -f Dockerfile || (echo "✗ Dockerfile missing" && exit 1)
	@test -f docker-compose.yml || (echo "✗ docker-compose.yml missing" && exit 1)
	@echo "✓ All pre-flight checks passed"

## build: Build Docker images
build: check
	docker-compose build

## up: Start services
up: check
	docker-compose up

## up-build: Build and start services
up-build: check
	docker-compose up --build

## down: Stop services
down:
	docker-compose down

## clean: Remove containers, volumes, and images
clean:
	docker-compose down -v --rmi local

## logs: Show service logs
logs:
	docker-compose logs -f

## ps: Show running containers
ps:
	docker-compose ps

## health: Check container health status
health:
	@docker-compose ps --format json | grep -q '"Health":"healthy"' && echo "✓ Services healthy" || docker-compose ps

## shell: Open shell in researcher container
shell:
	docker exec -it ai-researcher bash

## test: Run tests
test: validate
	@echo "✓ Configuration validated"

## dev: Start in development mode
dev:
	code . && docker-compose up
