# 04 — Mesh governance

Enterprise demo: **authorization is per agent**, not only at the entry point.

## Personas

| Persona            | trip-planner | flight-researcher | hotel-researcher |
| ------------------ | :----------: | :---------------: | :--------------: |
| `mesh-full-user`   |    allow     |       allow       |      allow       |
| `mesh-flight-user` |    allow     |       allow       |       deny       |
| `mesh-hotel-user`  |    allow     |       deny        |      allow       |
| `mesh-deny-user`   |     deny     |       deny        |       deny       |

## Local verification

```bash
export USE_MESH_MOCKS=true
export MESH_USER_PERSONA=mesh-flight-user
cd src/trip-planner
agents-cli run "Plan NYC to San Francisco with flights and hotels."
# Expect: flights in plan, AUTH_ERROR for hotels
```

## Platform governance (M3)

1. **Register** all agents in Agent Registry (trip-planner, flight-researcher, hotel-researcher)
2. **Agent-to-agent IAP policies** — templates in [`terraform/policies/`](../terraform/policies/)
3. Apply after deploy:

```bash
gcloud beta iap web set-iam-policy terraform/policies/agent-to-agent-flight.json \
  --project=yexperiment --agent=<flight-engine-id> --region=asia-northeast1
```

4. **Negative tests** (required for acceptance):

| Test                       | Expected                             |
| -------------------------- | ------------------------------------ |
| mesh-full-user via gateway | Full trip plan                       |
| mesh-flight-user           | Flights OK; hotel AUTH_ERROR visible |
| mesh-hotel-user            | Hotels OK; flight AUTH_ERROR visible |
| mesh-deny-user             | Blocked at gateway ingress           |

## Implementation layers

| Layer                          | Location                                     |
| ------------------------------ | -------------------------------------------- |
| Persona matrix                 | `app/mesh_auth.py` in each agent             |
| Orchestrator delegation guards | `src/trip-planner/app/tools.py`              |
| Specialist enforcement         | `before_agent_callback` in specialist agents |
| Platform IAM                   | `terraform/policies/` + Agent Registry       |

## References

- [Create IAM agent policies](https://docs.cloud.google.com/gemini-enterprise-agent-platform/govern/policies/assign-identity-iam)
- [Agent Gateway overview](https://docs.cloud.google.com/gemini-enterprise-agent-platform/govern/gateways/agent-gateway-overview)
- [Agent identity](https://docs.cloud.google.com/gemini-enterprise-agent-platform/scale/runtime/agent-identity)
