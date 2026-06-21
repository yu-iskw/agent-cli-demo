# 02 — Private IAM deploy

Deploy order: **flight-researcher → hotel-researcher → trip-planner** (leaf agents first).

## Prerequisites

- Terraform applied (`terraform/` — service accounts exist)
- Impersonate operator SA:

```bash
export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=agent-operator-sa@yexperiment.iam.gserviceaccount.com
export GOOGLE_CLOUD_PROJECT=yexperiment
export GOOGLE_CLOUD_LOCATION=asia-northeast1
```

## Enhance projects for Agent Runtime

```bash
cd src/flight-researcher
agents-cli scaffold enhance . --deployment-target agent_runtime --region asia-northeast1 -y --skip-checks

cd ../hotel-researcher
agents-cli scaffold enhance . --deployment-target agent_runtime --region asia-northeast1 -y --skip-checks

cd ../trip-planner
agents-cli scaffold enhance . --deployment-target agent_runtime --region asia-northeast1 -y --skip-checks
```

## Deploy (requires explicit human approval)

Agent Platform **does not allow** `--service-account` and `--agent-identity` together. Use agent identity for the governance demo:

```bash
# Flight
cd src/flight-researcher
agents-cli deploy --project yexperiment --region asia-northeast1 \
  --agent-identity --no-confirm-project

# Hotel
cd ../hotel-researcher
agents-cli deploy --project yexperiment --region asia-northeast1 \
  --agent-identity --no-confirm-project

# Trip-planner — set specialist card URLs from leaf deploy output
cd ../trip-planner
agents-cli deploy --project yexperiment --region asia-northeast1 \
  --agent-identity --no-confirm-project \
  --update-env-vars "USE_MESH_MOCKS=false,FLIGHT_A2A_CARD_URL=<flight-card-url>,HOTEL_A2A_CARD_URL=<hotel-card-url>,GOOGLE_CLOUD_LOCATION=global"
```

See `docs/notes/2026-06-21-deploy-endpoints.md` for live IDs and URLs.

### A2A specialists: AgentCard introspection shim

If deploy fails with `'AgentCard' object has no attribute 'DESCRIPTOR'`, ensure `app/app_utils/a2a_deploy_shim.py` is wired in `agent_runtime_app.py` (included in this repo).

## Verify

- `agents-cli deploy --status` if using `--no-wait`
- Cloud Trace: A2A spans from trip-planner → specialists ([tracing docs](https://docs.cloud.google.com/gemini-enterprise-agent-platform/optimize/observability/traces))
- Eval smoke against deployed URL:

```bash
agents-cli run --url <trip-planner-url> --mode adk "Plan NYC to SFO"
```

## Private access

- No public/unauthenticated endpoints
- Callers use IAM identity tokens or Agent Gateway (M3)
