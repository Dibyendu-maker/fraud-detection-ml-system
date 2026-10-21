# Real-Time Fraud Detection ML System

A Python project for transaction screening with reproducible model training, calibrated fraud probabilities, deterministic business rules, SHAP explanations, an audit trail, and a Streamlit analyst dashboard.

## What is included

- Synthetic transaction generation and chronological train/validation/test splits.
- Logistic Regression, Random Forest, and XGBoost benchmarking; validation PR-AUC selects the champion.
- Platt probability calibration and validation threshold selection by expected cost subject to a precision floor.
- Shared offline and online feature engineering, including account velocity windows.
- FastAPI single and batch screening, readiness, metrics, audit search, and analyst alert review endpoints.
- SQLite for local use and PostgreSQL for Docker Compose.
- Streamlit operations view for metrics, pending alerts, review notes, and audit history.

## Local setup

Requires Python 3.11 or newer.

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -e ".[dev]"
Copy-Item .env.example .env
```

Set a private random value for `API_AUTH_TOKEN` in `.env`. Local SQLite is the default. Generate data if needed, train and save the model/calibrator, then start the API:

```powershell
python scripts/train_models.py --num-transactions 20000 --seed 42
python scripts/serve_api.py
```

The training command creates the synthetic data when it is missing. You can use `--data-path`, `--output-dir`, `--fraud-rate`, or `--no-generate-if-missing` to control that behavior. Generated CSVs and model artifacts are intentionally git-ignored; a fresh checkout should run the training command before starting inference.

In a second terminal, activate the same environment and run:

```powershell
streamlit run dashboard/app.py
```

The dashboard reads `API_BASE_URL` and `API_AUTH_TOKEN` from `.env`. Open <http://localhost:8501>; the API docs are at <http://localhost:8000/docs>.

## Docker Compose

Copy `.env.example` to `.env`, set long random URL-safe values for `POSTGRES_PASSWORD` and `API_AUTH_TOKEN`, then run:

```powershell
docker compose up --build
```

Compose starts PostgreSQL, the API, and the dashboard. On first start, the API creates the synthetic dataset and trains model artifacts into persistent volumes. That first start can take several minutes. Open <http://localhost:8501> for the dashboard and <http://localhost:8000/docs> for the API docs.

## API

Except for health, `/api/v1/*` endpoints require `Authorization: Bearer <API_AUTH_TOKEN>` when `API_AUTH_TOKEN` is configured.

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/v1/health` | API, model, rule engine, and database readiness |
| `POST` | `/api/v1/predict` | Score one transaction |
| `POST` | `/api/v1/predict-batch` | Score up to 500 transactions |
| `GET` | `/api/v1/metrics` | Process metrics and audit record count |
| `GET` | `/api/v1/audit-logs` | Paginated audit search by decision, account, and time |
| `GET` | `/api/v1/alerts` | Paginated analyst queue; defaults to pending alerts |
| `PATCH` | `/api/v1/alerts/{alert_id}` | Mark a pending alert confirmed or dismissed, with notes |

Example request (PowerShell):

```powershell
$token = (Get-Content .env | Where-Object { $_ -match '^API_AUTH_TOKEN=' } | Select-Object -First 1) -replace '^API_AUTH_TOKEN=', ''
$headers = @{ Authorization = "Bearer $token" }
$body = Get-Content data/sample_payloads/normal_transaction.json -Raw
Invoke-RestMethod -Uri http://localhost:8000/api/v1/predict -Method Post -Headers $headers -ContentType 'application/json' -Body $body
```

Dynamic velocity fields (`tx_count_last_1h`, `tx_count_last_24h`, trailing amount totals, historical average/ratios, and time since last transaction) are computed from earlier transactions when omitted. Explicit values are accepted when an upstream feature service supplies them. Recent audit records warm the per-process cache on startup; the included Compose deployment runs one API process. A horizontally scaled deployment should replace the local cache with a shared store such as Redis.

`API_RATE_LIMIT_PER_MINUTE` sets an in-process per-client limit for single and batch inference (default: 120). Put a shared rate limiter at the gateway when running multiple API instances. Compose binds the API and dashboard to localhost; terminate TLS and restrict access before exposing either service to a network.

Audit responses exclude the raw request payload. Treat account IDs and transaction details as sensitive operational data; protect the API token and database accordingly.

## Training and evaluation

```powershell
python scripts/train_models.py --num-transactions 20000 --seed 42
```

The trainer uses a time-aware split. It fits probability calibrators on the validation window, selects the champion by validation PR-AUC, tunes the operating threshold on validation cost/precision constraints, then reports final metrics on the untouched test window. Artifacts are written under `models/`, including `evaluation_metrics.json`, the selected champion, feature pipeline, SHAP explainer, and probability calibrator.

## Tests and lint

```powershell
python -m pytest
ruff check src dashboard scripts tests --select E4,E7,E9,F --ignore E402
```

## Benchmarking and verification

```powershell
python scripts/benchmark_api.py
python scripts/show_responses.py
```

The CI workflow generates a small synthetic training set, runs the test suite and lint checks, and builds the Docker image.

## Project layout

```text
configs/                 Runtime and business-rule configuration
dashboard/                Streamlit operator dashboard
scripts/                  Data generation, training, benchmarking, container startup
src/api/                  FastAPI application, schemas, and dependencies
src/data/                 Synthetic data generator and loader
src/features/             Offline and online feature engineering
src/models/               Training, calibration, evaluation, prediction
src/rules/                Deterministic decision rules
src/storage/              SQLAlchemy database and audit/alert models
src/explainability/       SHAP reason codes
tests/                    Unit and API integration tests
Dockerfile                Container image
docker-compose.yml        PostgreSQL, API, and dashboard stack
```

## License

MIT. See [LICENSE](LICENSE).
