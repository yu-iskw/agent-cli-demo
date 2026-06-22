# M3 discovery — Agent Registry + identity principals

Project: `yexperiment` | Region: `asia-northeast1` | Date: 2026-06-21

## API access notes

- `gcloud alpha agent-registry …` failed with expired user credentials; **ADC token works**.
- Agent Registry REST base: `https://agentregistry.googleapis.com/v1alpha/projects/yexperiment/locations/asia-northeast1`
- Do **not** use regional hostname `{region}-agentregistry.googleapis.com` (404).

## Mesh agents (auto-registered on deploy with `--agent-identity`)

| Agent             | Reasoning Engine ID   | Registry UID                                         | Registry `--agent` ID |
| ----------------- | --------------------- | ---------------------------------------------------- | --------------------- |
| trip-planner      | `2912483156676313088` | `agentregistry-00000000-0000-0000-b596-f33e0323eaab` | same UID              |
| hotel-researcher  | `787347082510860288`  | `agentregistry-00000000-0000-0000-985a-54304de0d469` | same UID              |
| flight-researcher | `8436148099646226432` | `agentregistry-00000000-0000-0000-8ad9-56c0770a61aa` | same UID              |

## Agent identity principals (for IAP egress policies)

| Agent             | Principal                                                                                                                                                              |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| trip-planner      | `principal://agents.global.proj-844279876229.system.id.goog/resources/aiplatform/projects/844279876229/locations/asia-northeast1/reasoningEngines/2912483156676313088` |
| hotel-researcher  | `principal://agents.global.proj-844279876229.system.id.goog/resources/aiplatform/projects/844279876229/locations/asia-northeast1/reasoningEngines/787347082510860288`  |
| flight-researcher | `principal://agents.global.proj-844279876229.system.id.goog/resources/aiplatform/projects/844279876229/locations/asia-northeast1/reasoningEngines/8436148099646226432` |

## Agent URNs (for bindings)

| Agent             | agentId URN                                                                                                                       |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| trip-planner      | `urn:agent:projects-844279876229:projects:844279876229:locations:asia-northeast1:aiplatform:reasoningEngines:2912483156676313088` |
| hotel-researcher  | `urn:agent:projects-844279876229:projects:844279876229:locations:asia-northeast1:aiplatform:reasoningEngines:787347082510860288`  |
| flight-researcher | `urn:agent:projects-844279876229:projects:844279876229:locations:asia-northeast1:aiplatform:reasoningEngines:8436148099646226432` |

## Registry state after M3 apply (2026-06-21)

| Resource        | Count                               | Notes                                                                                          |
| --------------- | ----------------------------------- | ---------------------------------------------------------------------------------------------- |
| **agents**      | 4 listed (3 mesh + Workspace Agent) | auto-registered on deploy                                                                      |
| **services**    | **3 created**                       | `trip-planner`, `flight-researcher`, `hotel-researcher` via `apply_mesh_governance.sh` Phase 1 |
| **bindings**    | **0 — deferred**                    | Phase 2 skipped; requires `AUTH_PROVIDER_BINDING` (OAuth M3-2b)                                |
| **IAP egress**  | **applied**                         | flight + hotel policies via Phase 4 (`--resource-type=agent-registry`, registry UIDs)          |
| **IAP ingress** | **applied**                         | trip-planner when `MESH_IAM_TEST_MEMBERS` set (M3-2a)                                          |

Generated env file: `terraform/registry/mesh-agents.env` (template: [`mesh-agents.env.example`](../../../terraform/registry/mesh-agents.env.example)).

Platform test matrix: [`2026-06-21-m3-platform-tests.md`](2026-06-21-m3-platform-tests.md).
