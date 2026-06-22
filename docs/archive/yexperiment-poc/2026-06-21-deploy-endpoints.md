# Deployed mesh endpoints — 2026-06-21

Project: `yexperiment` | Region: `asia-northeast1`

> **Identity:** Specialists use `--agent-identity`. Trip-planner uses `trip-planner-sa@yexperiment.iam.gserviceaccount.com` for outbound A2A (ADC via `GoogleCloudAuth`). Revisit agent-identity once M3-2b registry bindings exist.

## Agents

| Agent             | Reasoning Engine ID   | Agent card URL                                                                                                                                                                   |
| ----------------- | --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| flight-researcher | `8436148099646226432` | `https://asia-northeast1-aiplatform.googleapis.com/v1beta1/projects/yexperiment/locations/asia-northeast1/reasoningEngines/8436148099646226432/a2a/v1/card`                      |
| hotel-researcher  | `787347082510860288`  | `https://asia-northeast1-aiplatform.googleapis.com/v1beta1/projects/yexperiment/locations/asia-northeast1/reasoningEngines/787347082510860288/a2a/v1/card`                       |
| trip-planner      | `2464937943706370048` | [Console playground](https://console.cloud.google.com/vertex-ai/agents/agent-engines/locations/asia-northeast1/agent-engines/2464937943706370048/playground?project=yexperiment) |

## Trip-planner env (deploy)

```bash
GOOGLE_CLOUD_LOCATION=global
# Specialist AgentCards are bundled in src/trip-planner/app/cards/ (no env URLs required).
# Deploy with trip-planner-sa until M3-2b registry bindings enable agent-identity egress.
```

## Workaround: A2A AgentCard deploy introspection

Pydantic `AgentCard` failed vertexai `MessageToJson` during deploy. Fixed via `app/app_utils/a2a_deploy_shim.py` on specialists (protobuf Struct shim + `register_operations` restore).

## Console links

- [flight-researcher](https://console.cloud.google.com/vertex-ai/agents/agent-engines/locations/asia-northeast1/agent-engines/8436148099646226432?project=yexperiment)
- [hotel-researcher](https://console.cloud.google.com/vertex-ai/agents/agent-engines/locations/asia-northeast1/agent-engines/787347082510860288?project=yexperiment)
- [trip-planner playground](https://console.cloud.google.com/vertex-ai/agents/agent-engines/locations/asia-northeast1/agent-engines/2464937943706370048/playground?project=yexperiment)

## M3 follow-ups

1. Register agents in Agent Registry (bound to gateway)
2. Create real Google Groups for mesh personas; bind in Terraform/IAP
3. Apply `terraform/policies/agent-to-agent-*.json` via `terraform/scripts/apply_mesh_governance.sh`
4. Configure Agent Gateway OAuth ingress → trip-planner only
