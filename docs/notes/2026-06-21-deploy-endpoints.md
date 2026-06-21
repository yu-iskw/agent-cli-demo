# Deployed mesh endpoints — 2026-06-21

Project: `yexperiment` | Region: `asia-northeast1` | Identity: `--agent-identity` (Preview)

> **Note:** Agent Platform rejects `--service-account` together with `--agent-identity`. Deploys use agent identity only; per-agent runtime SAs from Terraform remain for IAM bindings and future policy work.

## Agents

| Agent             | Reasoning Engine ID   | Agent card URL                                                                                                                                              |
| ----------------- | --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| flight-researcher | `8436148099646226432` | `https://asia-northeast1-aiplatform.googleapis.com/v1beta1/projects/yexperiment/locations/asia-northeast1/reasoningEngines/8436148099646226432/a2a/v1/card` |
| hotel-researcher  | `787347082510860288`  | `https://asia-northeast1-aiplatform.googleapis.com/v1beta1/projects/yexperiment/locations/asia-northeast1/reasoningEngines/787347082510860288/a2a/v1/card`  |
| trip-planner      | `2912483156676313088` | Console playground (ADK orchestrator)                                                                                                                       |

## Trip-planner env (deploy)

```
USE_MESH_MOCKS=false
FLIGHT_A2A_CARD_URL=<flight card URL above>
HOTEL_A2A_CARD_URL=<hotel card URL above>
GOOGLE_CLOUD_LOCATION=global
```

## Workaround: A2A AgentCard deploy introspection

Pydantic `AgentCard` failed vertexai `MessageToJson` during deploy. Fixed via `app/app_utils/a2a_deploy_shim.py` on specialists (protobuf Struct shim + `register_operations` restore).

## Console links

- [flight-researcher](https://console.cloud.google.com/vertex-ai/agents/agent-engines/locations/asia-northeast1/agent-engines/8436148099646226432?project=yexperiment)
- [hotel-researcher](https://console.cloud.google.com/vertex-ai/agents/agent-engines/locations/asia-northeast1/agent-engines/787347082510860288?project=yexperiment)
- [trip-planner playground](https://console.cloud.google.com/vertex-ai/agents/agent-engines/locations/asia-northeast1/agent-engines/2912483156676313088/playground?project=yexperiment)

## M3 follow-ups

1. Register agents in Agent Registry (bound to gateway)
2. Create real Google Groups for mesh personas; bind in Terraform/IAP
3. Apply `terraform/policies/agent-to-agent-*.json` via `terraform/scripts/apply_mesh_governance.sh`
4. Configure Agent Gateway OAuth ingress → trip-planner only
