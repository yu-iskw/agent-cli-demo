# Acceptance checklist — Enterprise Trip-Planner Mesh

Project: `yexperiment` | Region: `asia-northeast1`

## Agent CLI implementation

- [x] Three agents under `src/` (flight-researcher, hotel-researcher, trip-planner)
- [x] A2A specialists + orchestrator with auth-gated delegation
- [x] Hybrid mock tools for offline eval

## Terraform / IAM

- [x] Service accounts: agent-operator-sa + per-agent runtime SAs
- [x] Operator impersonation (`roles/iam.serviceAccountTokenCreator`)
- [x] IAP policy templates in `terraform/policies/`
- [ ] Persona Google Groups created and bound (M3-2b — replace example.com addresses)

## Lifecycle

- [x] Phase 0 spec (`.agents-cli-spec.md`)
- [x] Scaffold + enhance for Agent Runtime
- [x] Unit tests for mesh auth (37 unit tests passing — see `2026-06-21-m3-platform-tests.md`)
- [x] Eval datasets updated per agent
- [x] Offline eval baselines — `docs/notes/2026-06-21-eval-baseline.md`
- [x] Deploy to Agent Runtime — `docs/notes/2026-06-21-deploy-endpoints.md`

## Governance (M3)

- [x] Local persona tests via `MESH_USER_PERSONA`
- [x] Per-agent auth in specialist `before_agent_callback`
- [x] Orchestrator delegation guards in `tools.py`
- [x] Agent Registry registration (auto on deploy with `--agent-identity`)
- [x] Registry services created (3) — `apply_mesh_governance.sh` Phase 1
- [x] IAM ingress on trip-planner (M3-2a) — ADC user via `MESH_IAM_TEST_MEMBERS`
- [x] Agent-to-agent IAP egress policies applied (flight/hotel, DRY_RUN)
- [ ] Agent Gateway + OAuth 3LO ingress (M3-2b — requires OAuth client + Google Groups)
- [ ] Registry bindings trip-planner→flight/hotel (requires `AUTH_PROVIDER_BINDING`)
- [ ] Platform negative tests with real personas via gateway (after M3-2b)

## LLMOps

- [x] Eval config per scaffolded project
- [ ] Cloud Trace verification (post-deploy)
- [ ] `eval compare` regression baselines

## Documentation

- [x] `docs/guides/00-overview.md` through `04-mesh-governance.md`
- [x] `docs/notes/` (session notes)
- [x] `.todo_list/enterprise-trip-mesh.md`

## Human follow-ups

1. Create real Google Groups for mesh personas in `yexperiment`
2. Configure Agent Gateway + OAuth client; set `AUTH_PROVIDER_BINDING` and re-run `apply_mesh_governance.sh`
3. Review DRY_RUN audit logs; switch IAP/gateway policies to enforce
4. Run platform four-persona gateway tests; update `2026-06-21-m3-platform-tests.md`
5. Run `agents-cli eval run` on each agent; commit baselines to `artifacts/` or document scores in notes
