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

	@echo "==> Instalando herramientas de Python..."
	@$(ACT) && $(PIP) install -U pytest pytest-cov ruff black isort pre-commit coverage

	@echo "==> Verificando binarios de DevSecOps..."

	# ----- gitleaks (instala desde Releases, no desde main/install.sh) -----
	@if ! command -v gitleaks >/dev/null; then \
	  echo "[gitleaks] instalando última versión..."; \
	  OS=$$(uname -s | tr '[:upper:]' '[:lower:]'); \
	  ARCH=$$(uname -m); \
	  case "$$ARCH" in x86_64|amd64) ARCH="x64";; aarch64|arm64) ARCH="arm64";; *) ARCH="x64";; esac; \
	  VER=$$(curl -fsSL https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep -Po '"tag_name":\s*"\K[^"]+'); \
	  VER_NOV=$${VER#v}; \
	  URL="https://github.com/gitleaks/gitleaks/releases/download/$$VER/gitleaks_$${VER_NOV}_$${OS}_$${ARCH}.tar.gz"; \
	  echo "[gitleaks] $$URL"; \
	  curl -fsSL "$$URL" -o /tmp/gitleaks.tgz; \
	  tar -xzf /tmp/gitleaks.tgz -C /tmp gitleaks || { echo "Fallo al extraer gitleaks"; exit 1; }; \
	  if command -v sudo >/dev/null; then sudo install -m 0755 /tmp/gitleaks /usr/local/bin/gitleaks; \
	  else mkdir -p $$HOME/.local/bin && install -m 0755 /tmp/gitleaks $$HOME/.local/bin/gitleaks && echo '>> Añade $$HOME/.local/bin al PATH'; fi; \
	  rm -f /tmp/gitleaks /tmp/gitleaks.tgz; \
	fi
	# Docs oficiales: Releases/README. (brew/docker/go también valen)
	# https://github.com/gitleaks/gitleaks  :contentReference[oaicite:2]{index=2}

	# ----- tfsec (script oficial linux, requiere bash) -----
	@if ! command -v tfsec >/dev/null; then \
	  echo "[tfsec] instalando..."; \
	  curl -fsSL https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash; \
	fi
	# https://aquasecurity.github.io/tfsec/... (brew/choco/scoop/go también)  :contentReference[oaicite:3]{index=3}

	# ----- tflint (script oficial linux) -----
	@if ! command -v tflint >/dev/null; then \
	  echo "[tflint] instalando..."; \
	  curl -fsSL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash; \
	fi
	# https://github.com/terraform-linters/tflint  :contentReference[oaicite:4]{index=4}

	# ----- conftest (OPA) - última versión desde Releases -----
	@if ! command -v conftest >/dev/null; then \
	  echo "[conftest] instalando última versión..."; \
	  VER=$$(curl -fsSL https://api.github.com/repos/open-policy-agent/conftest/releases/latest | grep -Po '"tag_name":\s*"\K[^"]+'); \
	  OS=$$(uname -s | tr '[:upper:]' '[:lower:]'); \
	  ARCH=$$(uname -m); \
	  case "$$ARCH" in x86_64|amd64) ARCH="x86_64";; aarch64|arm64) ARCH="arm64";; *) ARCH="x86_64";; esac; \
	  URL="https://github.com/open-policy-agent/conftest/releases/download/$$VER/conftest_$${VER#v}_$${OS}_$${ARCH}.tar.gz"; \
	  echo "[conftest] $$URL"; \
	  curl -fsSL "$$URL" -o /tmp/conftest.tgz; \
	  tar -xzf /tmp/conftest.tgz -C /tmp conftest || { echo "Fallo al extraer conftest"; exit 1; }; \
	  if command -v sudo >/dev/null; then sudo install -m 0755 /tmp/conftest /usr/local/bin/conftest; \
	  else mkdir -p $$HOME/.local/bin && install -m 0755 /tmp/conftest $$HOME/.local/bin/conftest && echo '>> Añade $$HOME/.local/bin al PATH'; fi; \
	  rm -f /tmp/conftest /tmp/conftest.tgz; \
	fi
	# https://www.conftest.dev/install/ y Releases  :contentReference[oaicite:5]{index=5}

	@echo "==> Instalando pre-commit hooks..."
	@if git rev-parse --git-dir >/dev/null 2>&1; then $(ACT) && pre-commit install; fi

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
