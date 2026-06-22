# M3 platform tests — four-persona matrix

Project: `yexperiment` | Region: `asia-northeast1` | Date: 2026-06-21

## Summary

| Layer                           | Scope                          | Result                |
| ------------------------------- | ------------------------------ | --------------------- |
| Local unit tests                | All four personas + delegation | ✅ 37 passed          |
| Platform IAM (M3-2a)            | IAP egress + IAM ingress       | ✅ applied            |
| Platform bindings (M3-2b)       | trip-planner→flight/hotel      | ⏸ deferred            |
| Platform gateway negative tests | OAuth personas via gateway     | ⏸ blocked until M3-2b |

## 1. Local unit tests — all pass

Run: `dev/test_python.sh` (or `make test` per agent package).

| Package           | Tests         | Mesh-related                                         |
| ----------------- | ------------- | ---------------------------------------------------- |
| flight-researcher | 12 passed     | `test_mesh_auth.py` (5), `test_mesh_persona.py` (6)  |
| hotel-researcher  | 10 passed     | `test_mesh_auth.py` (3), `test_mesh_persona.py` (6)  |
| trip-planner      | 15 passed     | `test_delegation.py` (8), `test_mesh_persona.py` (6) |
| **Total**         | **37 passed** | **34 mesh/delegation**                               |

Persona matrix covered locally via `MESH_USER_PERSONA` and `USE_MESH_MOCKS=true`:

| Persona            | trip-planner | flight | hotel | Local test |
| ------------------ | :----------: | :----: | :---: | ---------- |
| `mesh-full-user`   |    allow     | allow  | allow | ✅         |
| `mesh-flight-user` |    allow     | allow  | deny  | ✅         |
| `mesh-hotel-user`  |    allow     |  deny  | allow | ✅         |
| `mesh-deny-user`   |     deny     |  deny  | deny  | ✅         |

## 2. Platform IAM — applied (M3-2a / M3-3)

Applied via `./terraform/scripts/apply_mesh_governance.sh`:

| Policy      | Target            | `--agent` (registry UID)            | Mode                                |
| ----------- | ----------------- | ----------------------------------- | ----------------------------------- |
| IAP egress  | flight-researcher | `agentregistry-…-8ad9-56c0770a61aa` | DRY_RUN conditions                  |
| IAP egress  | hotel-researcher  | `agentregistry-…-985a-54304de0d469` | DRY_RUN conditions                  |
| IAP ingress | trip-planner      | `agentregistry-…-b596-f33e0323eaab` | ADC user in `MESH_IAM_TEST_MEMBERS` |

All IAP commands use `--resource-type=agent-registry` and registry UIDs (not Reasoning Engine numeric IDs).

IAM smoke test (2026-06-21):

```bash
source terraform/registry/mesh-agents.env
TOKEN=$(gcloud auth application-default print-access-token)
curl -sS -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"input":{"query":"ping"}}' \
  "${TRIP_PLANNER_QUERY_URL}"
```

Result: **HTTP 400** (`Default method query not found` — trip-planner exposes session APIs, not `:query`). **Not HTTP 403**, so IAM ingress for the ADC user is not blocking the call. Use Agent Engine session methods or the console playground for functional smoke; gateway OAuth tests remain M3-2b.

## 3. Deferred — human follow-ups

| Item                      | Blocker                         | Action                                                                       |
| ------------------------- | ------------------------------- | ---------------------------------------------------------------------------- |
| Registry bindings         | `AUTH_PROVIDER_BINDING` not set | Create OAuth auth provider; export binding name; re-run apply script Phase 2 |
| OAuth 3LO ingress (M3-2b) | No OAuth client / gateway       | Configure Agent Gateway; see `docs/guides/03-auth-gateway.md`                |
| Persona Google Groups     | Example.com placeholders        | Create real groups in `yexperiment`; update IAP condition expressions        |
| DRY_RUN → enforce         | Audit review pending            | Review gateway auth extension logs before enforcing                          |

## 4. Platform negative tests via gateway — blocked

Four-persona gateway tests require M3-2b (OAuth ingress + real groups):

| Test                       | Expected                     | Status    |
| -------------------------- | ---------------------------- | --------- |
| mesh-full-user via gateway | Full trip plan               | ⏸ not run |
| mesh-flight-user           | Flights OK; hotel AUTH_ERROR | ⏸ not run |
| mesh-hotel-user            | Hotels OK; flight AUTH_ERROR | ⏸ not run |
| mesh-deny-user             | Blocked at gateway ingress   | ⏸ not run |

Re-run after OAuth gateway and groups are configured; document results here.
