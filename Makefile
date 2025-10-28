# ==== Configuración base ====
PY ?= python3
PIP ?= pip
VENV ?= .venv
ACT ?= . $(VENV)/bin/activate

# ==== Ayuda ====
.PHONY: help
help:
	@echo "targets:"
	@echo "  venv, tools, fmt, lint, test, cov, ci, secrets-scan"
	@echo "  compose-up, compose-down"
	@echo "  tf-fmt, tf-validate, tf-plan, tf-opa, tf-apply, tf-destroy"
	@echo ""
	@echo "Notas:"
	@echo "  - Usa 'CONFIRM=yes make tf-apply' para aplicar el plan."
	@echo "  - Usa 'CONFIRM=yes make tf-destroy' para destruir (peligroso)."

# ==== Entorno virtual (idempotente) ====
.PHONY: venv
venv:
	@test -d $(VENV) || $(PY) -m venv $(VENV)
	@$(ACT) && $(PIP) install -U pip

# ==== Herramientas y hooks ====
.PHONY: tools
tools: venv
	# Asegura repo git (necesario para pre-commit install)
	@git rev-parse --git-dir >/dev/null 2>&1 || git init -b main
	# Python tooling
	@$(ACT) && $(PIP) install -U pytest pytest-cov ruff black isort pre-commit conftest
	@$(ACT) && $(PIP) install -U coverage
	# CLI scanners/linters (instala solo si faltan)
	@if ! command -v gitleaks >/dev/null; then curl -sSL https://raw.githubusercontent.com/gitleaks/gitleaks/master/scripts/install.sh | bash; fi
	@if ! command -v tfsec >/dev/null; then curl -sSfL https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | sh; fi
	@if ! command -v tflint >/dev/null; then curl -sSfL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash; fi
	# Hook de pre-commit (solo si hay .git)
	@if git rev-parse --git-dir >/dev/null 2>&1; then pre-commit install; fi

# ==== Calidad de código ====
.PHONY: fmt
fmt:
	isort .
	black .

.PHONY: lint
lint:
	ruff check src tests
	isort --check-only .
	black --check .

# ==== Tests ====
.PHONY: test
test:
	$(ACT) && pytest -vv --maxfail=1

.PHONY: cov
cov:
	$(ACT) && pytest -vv --cov=src --cov-report=term-missing --cov-fail-under=85

# ==== CI quick ====
.PHONY: ci
ci: fmt lint cov secrets-scan

# ==== Secrets ====
.PHONY: secrets-scan
secrets-scan:
	@if command -v gitleaks >/dev/null; then gitleaks detect --source . -v --redact; else echo "gitleaks no instalado"; fi

# ==== Docker Compose (opcional) ====
.PHONY: compose-up
compose-up:
	docker compose -f infra/docker/docker-compose.yml up -d

.PHONY: compose-down
compose-down:
	docker compose -f infra/docker/docker-compose.yml down -v

# ==== Terraform ====
TF_DIR := infra/terraform/stacks/local

.PHONY: tf-fmt
tf-fmt:
	@test -d $(TF_DIR) || mkdir -p $(TF_DIR)
	cd $(TF_DIR) && terraform fmt -recursive

.PHONY: tf-validate
tf-validate:
	cd $(TF_DIR) && terraform init -upgrade && terraform validate && tflint && tfsec .

.PHONY: tf-plan
tf-plan:
	cd $(TF_DIR) && terraform plan -out=plan.bin && terraform show -json plan.bin > plan.json

.PHONY: tf-opa
tf-opa:
	cd $(TF_DIR) && conftest test -p conftest/ plan.json

# ==== Operaciones protegidas ====
.PHONY: tf-apply
tf-apply:
	@if [ "$(CONFIRM)" = "yes" ]; then \
		cd $(TF_DIR) && terraform apply plan.bin; \
	else \
		echo "Protegido. Ejecuta: CONFIRM=yes make tf-apply"; \
		exit 1; \
	fi

.PHONY: tf-destroy
tf-destroy:
	@if [ "$(CONFIRM)" = "yes" ]; then \
		cd $(TF_DIR) && terraform destroy; \
	else \
		echo "Peligroso. Ejecuta: CONFIRM=yes make tf-destroy"; \
		exit 1; \
	fi
