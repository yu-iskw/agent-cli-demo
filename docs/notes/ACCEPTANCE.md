# ACCEPTANCE.md — Enterprise Trip-Planner Mesh

Project: `<your-gcp-project>` | Region: `asia-northeast1`

> **Teardown:** Mesh GCP resources can be removed with [`terraform/scripts/teardown_mesh.sh`](../terraform/scripts/teardown_mesh.sh). PoC session notes live under [`docs/archive/yexperiment-poc/`](../archive/yexperiment-poc/).

## Agent CLI implementation

- [x] Three agents under `src/` (flight-researcher, hotel-researcher, trip-planner)
- [x] A2A orchestration via ADK `RemoteA2aAgent` (no Python mesh auth)
- [x] Hybrid mock tools for offline eval

## Terraform / IAM

- [x] Service accounts: agent-operator-sa + per-agent runtime SAs
- [x] Operator impersonation (`roles/iam.serviceAccountTokenCreator`)
- [x] IAP policy templates in `terraform/policies/`
- [ ] Persona Google Groups created and bound (M3-2b — real groups, not example.com)

## Lifecycle

- [x] Phase 0 spec (`.agents-cli-spec.md`)
- [x] Scaffold + enhance for Agent Runtime
- [x] Unit tests for A2A mesh wiring (`test_a2a_mesh.py`, specialists)
- [x] Eval datasets updated per agent
- [x] Offline eval baselines — [`docs/archive/yexperiment-poc/2026-06-21-eval-baseline.md`](../archive/yexperiment-poc/2026-06-21-eval-baseline.md)
- [x] Deploy to Agent Runtime — run `discover_mesh.sh`; see [02 — IAM deploy](../guides/02-iam-deploy.md)

## Governance (M3)

- [x] Agent Registry registration (auto on deploy with `--agent-identity`)
- [x] Registry services created (3) — `apply_mesh_governance.sh` Phase 1
- [x] IAM ingress on trip-planner (M3-2a) — ADC user via `MESH_IAM_TEST_MEMBERS`
- [x] Agent-to-agent IAP egress policies applied (flight/hotel, DRY_RUN)
- [x] Agent Gateways created — `mesh-egress-gateway`, `mesh-ingress-gateway` (2026-06-21)
- [x] IAP authz extension in DRY_RUN — `mesh-iap-authz-ext`
- [ ] OAuth 3LO connector (`mesh-oauth-3lo`) — requires `OAUTH_CLIENT_ID` / `OAUTH_CLIENT_SECRET`
- [ ] Registry bindings trip-planner→flight/hotel — requires `AUTH_PROVIDER_BINDING` + apply script
- [ ] Trip-planner redeploy with `agent_gateway_config` + `--agent-identity`
- [ ] Platform four-persona gateway tests (after OAuth + groups)

## LLMOps

- [x] Eval config per scaffolded project
- [x] Cloud Trace verification (post-deploy) — [`docs/archive/yexperiment-poc/2026-06-21-eval-baseline.md`](../archive/yexperiment-poc/2026-06-21-eval-baseline.md)
- [x] `eval compare` regression baselines — legacy `results_20260621_195653.json` vs post-SequentialAgent `results_20260622_081402.json` (no regression)

## Documentation

- [x] `docs/guides/00-overview.md` through `05-gateway-policy-demo.md`
- [x] `docs/guides/` and [`docs/archive/yexperiment-poc/`](../archive/yexperiment-poc/) (historical PoC notes)
- [x] Gateway automation: `terraform/scripts/setup_agent_gateway.sh`, `check_mesh_gateway_status.sh`

## Human follow-ups

1. Create real Google Groups for mesh personas in your GCP project
2. Create OAuth client; run `./terraform/scripts/setup_agent_gateway.sh --with-oauth --apply-governance`
3. Redeploy trip-planner with gateway binding (irreversible — use test engine if unsure)
4. Review DRY_RUN audit logs; switch gateway/IAP to enforce
5. Run four-persona gateway tests; update [`docs/archive/yexperiment-poc/2026-06-21-m3-platform-tests.md`](../archive/yexperiment-poc/2026-06-21-m3-platform-tests.md)

## Readiness check

```bash
./terraform/scripts/check_mesh_gateway_status.sh
```

Exit **0** = gateway + policy prerequisites satisfied.
