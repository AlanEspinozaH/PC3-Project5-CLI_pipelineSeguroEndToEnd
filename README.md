# PC3 - Proyecto 5 — CLI pipeline **Seguro End-to-End** (12-Factor + Secrets + CI/CD)

## 📌 Objetivo 

Construir una **aplicación CLI** con arquitectura limpia (puertos/adaptadores) que:

1. Cargue **configuración** vía variables de entorno (12-Factor).
2. Maneje **secretos offline** con `age` y **rotación versionada**.
3. Firme datos con **Ed25519** y encadene registros en **SQLite** para detectar *tampering*.
4. Tenga **CI** con *gates* obligatorios: lint, tests (≥85% coverage), *secrets scan* y checks de IaC (Terraform + tfsec/tflint/OPA).

## 🧱 Arquitectura (hexagonal, resumida)

* `src/ports/`: interfaces (`ConfigPort`, `SecretsPort`, `SignerPort`, `LedgerPort`, `ClockPort`).
* `src/adapters/`:

  * `EnvConfigAdapter` (lee ENV),
  * `AgeSecretsAdapter` (cifra/rota secretos `*.age`),
  * `Ed25519SignerAdapter` (firma/verifica),
  * `SQLiteLedgerAdapter` (ledger con hash encadenado),
  * `SystemClockAdapter`.
* `src/core/`:

  * `config_facade.py` (valida y centraliza config),
  * `usecases/` (`issue_receipt.py`, `sign_receipt.py`, `append_ledger.py`),
  * `domain/models.py`.

## 🗂️ Estructura básica

```
src/
infra/
tests/
.github/workflows/
docs/
evidence/
secrets/
data/
Makefile
```

## 🔧 Requisitos

* WSL2 Ubuntu / Linux, Python 3.11, `make`
* (Opcional) Docker + docker compose v2
* Terraform ≥1.5
* Herramientas se instalan con `make tools` (pytest, ruff, isort, black, gitleaks, tfsec, tflint, conftest…)

## 🚀 Inicio rápido

```bash
git clone https://github.com/Juruju/PC3-Project5-CLI_pipelineSeguroEndToEnd.git
cd PC3-Project5-CLI_pipelineSeguroEndToEnd
make tools           # crea .venv si falta e instala deps
source .venv/bin/activate
make test            # corre tests
make cov             # gate de cobertura (≥85%)
```

### Variables de entorno (12-Factor)

Claves mínimas (ejemplo dev):

```
APP_ENV=dev                     # dev|stage|prod
DB_URL=sqlite:///data/pos.db
LEDGER_PATH=data/ledger.db
SECRETS_FILE=secrets/secrets.current.age
```

> **No** commitees `.env`. Usa `export` o carga en tu shell/CI.

### Secretos con `age` (offline)

```bash
# generar par de claves (se guarda fuera del repo)
age-keygen -o ~/.config/age/keys.txt
# cifrar secreto plano -> versión inicial
echo "API_KEY=xxxx" | age -R ~/.config/age/keys.txt -o secrets/secrets.v1.age
ln -sf secrets.v1.age secrets/secrets.current.age

# rotación posterior (v2)
echo "API_KEY=yyyy" | age -R ~/.config/age/keys.txt -o secrets/secrets.v2.age
ln -sf secrets.v2.age secrets/secrets.current.age
```

> En CI solo se usa el **cifrado** (`*.age`). Los planos jamás se suben.

### Makefile útil

* **Calidad**: `make fmt`, `make lint`, `make test`, `make cov`, `make ci`
* **Secrets**: `make secrets-scan` (gitleaks)
* **Terraform**: `make tf-fmt`, `make tf-validate`, `make tf-plan`, `make tf-opa`, `CONFIRM=yes make tf-apply`
* **Docker**: `make compose-up`, `make compose-down`

## 🌱 Flujo de ramas

* `main` (protegida) → estable
* `develop` → integración
* `feature/<usuario>/<id>-<slug>` → trabajo por tarea
  **PRs** de `feature/*` hacia `develop`. CI debe estar **verde**:
* Lint ok (ruff/isort/black)
* Tests ok + **coverage ≥85%**
* `gitleaks` sin secretos
* IaC: `fmt/validate/tflint/tfsec` + `plan` + `OPA` sin High

Al final del sprint, **PR `develop` → `main`**.  

---  
## **Explicación de las ramas, flujo de trabajo, PRs y hooks**. 
### 1️⃣ Ramas y flujo de trabajo: `feature/* -> develop -> main`

Esto se refiere a un **flujo de trabajo git “tipo Git Flow”**.

### Main ideas:

* **`main`** (o `master` en algunos repos)

  * Es la rama “estable” o de producción.
  * Solo contiene código que ya está probado y listo para release.

* **`develop`**

  * Es la rama de integración.
  * Todas las nuevas funcionalidades terminadas se mezclan aquí primero, para probar que todo funcione antes de ir a `main`.

* **`feature/*`**

  * Ramas de desarrollo de funcionalidades específicas.
  * Normalmente se crean a partir de `develop`.
  * Ejemplo: `feature/login` → contiene solo el desarrollo de la pantalla de login.

### Flujo típico:

```text
feature/login
      |
      v
develop
      |
      v
main
```

💡 Nota: Las “flechas” que viste (`feature/* -> develop -> main`) significan “merge hacia”, es decir: **primero trabajas en feature, luego la fusionas (merge) en develop, y finalmente develop se fusiona en main**.  Este flujo es correcto.   

---

## 2️⃣ Mensajería: Conventional Commits

* Esta una **convención para escribir mensajes de commit claros**.
* Ejemplo:

```text
feat: agregar login de usuarios
fix: corregir validación de email
docs: actualizar README
```

Sirve para generar changelogs automáticos y entender la historia del proyecto fácilmente.

---

## 3️⃣ PRs (Pull Requests)

* Se usan para **fusionar una rama en otra** (normalmente `feature/*` → `develop` o `develop` → `main`).
* Checklist típico:

  * Al menos 1 aprobación (o 2 si el módulo es sensible).
  * Cumplir convenciones de commits y pruebas.
* Plantilla: muchas empresas agregan un PR template con preguntas, checklist de pruebas, etc.

---

## 4️⃣ Hooks

Git permite ejecutar scripts en ciertas acciones. Aquí se mencionan **hooks iniciales y no bloqueantes**:

* **Formato / Lint**: revisa estilo de código automáticamente.
* **Mensaje de commit**: verifica que siga Conventional Commits.
* **Detección básica de secretos**: evita subir contraseñas o claves por error.

> “No bloqueantes” significa que si fallan, el commit no se detiene, solo te avisan.  
---

## 🧪 Pruebas

* Unit: `tests/unit/*` (parametrize, monkeypatch, autospec)
* Contract: `tests/contract/*` (puertos/adaptadores)
* Integration/E2E: `tests/integration/*`, `tests/e2e/*`

## 🛡️ CI (GitHub Actions)

Matriz Linux/Mac, Python 3.11. Jobs:

* **build-test**: lint + pytest + coverage gate 85%
* **security-iac**: gitleaks + terraform fmt/validate/tflint/tfsec + plan + conftest (OPA)

## 📁 Evidencias por sprint

Guarda en `evidence/sprint-*/`:

* Capturas tablero (Status→Done, Sum(Estimate), burndown)
* Logs de CI y reportes (coverage, gitleaks, tfsec, tflint, OPA)
* Video 4–6 min

## 🧭 Convenciones

* Commits: `feat|fix|chore|docs|test|refactor|ci: mensaje`
* Python: `ruff`, `black`, `isort`
* No subir: `.venv/`, `__pycache__/`, `*.tfstate`, `plan.bin/plan.json`, secretos planos.
* Versionar: `.terraform.lock.hcl`

## 🆘 Problemas comunes

* **CRLF**: ya mitigado con `.gitattributes` (`eol=lf`).
* **“dubious ownership”**: usa Git **dentro de WSL** (no Git Bash sobre `\\wsl.localhost`).



