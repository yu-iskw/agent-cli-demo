# 01 — Local mesh

## Prerequisites

- `agents-cli` 0.5.x (`uv tool install google-agents-cli`)
- Python 3.11+
- GCP auth for Vertex AI eval (optional for unit tests only)

## Unit tests (no GCP)

```bash
cd src/flight-researcher && uv run pytest tests/unit/ -q
cd src/hotel-researcher && uv run pytest tests/unit/ -q
cd src/trip-planner && uv run pytest tests/unit/ -q
```

## Local orchestration (mock delegates)

Default: `USE_MESH_MOCKS=true` — trip-planner uses auth-gated mock delegates (no A2A servers required).

```bash
export MESH_USER_PERSONA=mesh-full-user
cd src/trip-planner
agents-cli install
agents-cli run "Plan a trip from NYC to San Francisco with flights and hotels."
```

### Test governance personas

```bash
# Flight-only user — hotel delegation returns AUTH_ERROR
export MESH_USER_PERSONA=mesh-flight-user
agents-cli run "Plan NYC to San Francisco with flights and hotels."

# Denied at trip-planner
export MESH_USER_PERSONA=mesh-deny-user
agents-cli run "Plan a trip."
```

## Full local A2A (three terminals)

```bash
# Terminal 1 — flight (port 8001)
cd src/flight-researcher && uv run uvicorn app.fast_api_app:app --port 8001

# Terminal 2 — hotel (port 8002)
cd src/hotel-researcher && uv run uvicorn app.fast_api_app:app --port 8002

# Terminal 3 — orchestrator
cd src/trip-planner
export USE_MESH_MOCKS=false
export FLIGHT_A2A_CARD_URL=http://127.0.0.1:8001/a2a/app/.well-known/agent-card.json
export HOTEL_A2A_CARD_URL=http://127.0.0.1:8002/a2a/app/.well-known/agent-card.json
agents-cli run "Plan NYC to San Francisco."
```

## Offline eval

Requires Vertex AI / project access:

```bash
cd src/flight-researcher && agents-cli eval run --project yexperiment --region global
cd src/hotel-researcher && agents-cli eval run --project yexperiment --region global
cd src/trip-planner && agents-cli eval run --project yexperiment --region global
```

Use `--region global` for Gemini inference; Agent Runtime deploy stays `asia-northeast1`.

Store baselines under each project's `artifacts/grade_results/` for regression compares.

## Terraform (platform SAs)

```bash
cd terraform
terraform init
terraform plan
terraform apply   # creates agent-operator-sa + per-agent runtime SAs
```

Impersonate operator SA for deploy:

```bash
export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=$(terraform output -raw operator_service_account_email)
```
