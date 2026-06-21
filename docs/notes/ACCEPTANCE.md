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
- [ ] Persona Google Groups created and bound (M3 — replace example.com addresses)

## Lifecycle

- [x] Phase 0 spec (`.agents-cli-spec.md`)
- [x] Scaffold + enhance for Agent Runtime
- [x] Unit tests for mesh auth (9 tests passing)
- [x] Eval datasets updated per agent
- [x] Offline eval baselines — `docs/notes/2026-06-21-eval-baseline.md`
- [x] Deploy to Agent Runtime — `docs/notes/2026-06-21-deploy-endpoints.md`

## Governance (M3)

- [x] Local persona tests via `MESH_USER_PERSONA`
- [x] Per-agent auth in specialist `before_agent_callback`
- [x] Orchestrator delegation guards in `tools.py`
- [ ] Agent Registry registration (console — agents deployed)
- [ ] Agent Gateway + OAuth 3LO (requires OAuth client + Google Groups)
- [ ] Agent-to-agent IAP policies applied (after registry)
- [ ] Platform negative tests with real personas (after gateway)

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
2. Approve and run `agents-cli deploy` for each agent (leaf → orchestrator order)
3. Configure Agent Gateway and apply IAP policies (start DRY_RUN)
4. Run `agents-cli eval run` on each agent; commit baselines to `artifacts/` or document scores in notes
