# A2A mesh refactor — Agent Platform (2026-06-21)

## Problem

Console playground on trip-planner returned `a2a_required` / failed delegation because:

1. Custom `delegate_*` tools required `USE_MESH_MOCKS` or manual `FLIGHT_A2A_CARD_URL` env vars.
2. Python `mesh_auth.py` persona checks are not enterprise-grade; governance belongs on Agent Platform (IAP + Gateway).

## Solution (ADK standard)

| Layer            | Before                                         | After                                                                                                                |
| ---------------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Orchestrator     | Custom tools + `a2a_delegate.py`               | `RemoteA2aAgent` sub-agents ([Google codelab pattern](https://codelabs.developers.google.com/adk-a2a-agent-runtime)) |
| Auth             | `mesh_auth.py` / `MESH_USER_PERSONA`           | Platform IAP + runtime SA IAM (`roles/aiplatform.user`)                                                              |
| Specialist cards | URL fetch at runtime (401 with agent-identity) | Bundled `AgentCard` JSON in `app/cards/`                                                                             |
| A2A HTTP         | Plain httpx                                    | `GoogleCloudAuth` httpx.Auth (ADC refresh)                                                                           |

## Deploy notes

- **trip-planner** redeployed with **`trip-planner-sa`** (not `--agent-identity`) because agent-identity outbound A2A returned 401 until registry bindings (M3-2b) exist.
- **Specialists** remain `--agent-identity` A2A servers.
- New trip-planner engine ID: `2464937943706370048`

## Verified smoke (2026-06-21)

```text
agents-cli run --url …/2464937943706370048 --mode adk "Search flights from NYC to SFO"
→ flight_researcher returns Mesh Air $320, Demo Airways $275
```

## Follow-ups

- Re-enable `--agent-identity` on trip-planner after `AUTH_PROVIDER_BINDING` + registry bindings (M3-2b).
- Update Agent Registry / IAP policies for new trip-planner engine UID.
- Platform persona tests via Gateway OAuth (not Python env vars).
