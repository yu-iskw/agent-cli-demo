# Enterprise Trip-Planner Mesh — TODO

Project: `<your-gcp-project>` | Region: `asia-northeast1` | Private only

## Milestone 1 — Local mesh + offline eval

- [x] M1-0: `.agents-cli-spec.md` approved
- [x] M1-1: `.todo_list/enterprise-trip-mesh.md` created
- [x] M1-2: `terraform/` SAs + IAM applied
- [x] M1-3: Scaffold `src/flight-researcher`, `src/hotel-researcher`
- [x] M1-4: Scaffold `src/trip-planner` + A2A wiring
- [x] M1-5: Mock hybrid tools + local auth stub (`MESH_USER_PERSONA`)
- [x] M1-6: Offline eval baselines (all three + orchestrator)
- [x] M1-7: `docs/guides/01-local-mesh.md`

## Milestone 2 — Private IAM deploy

- [x] M2-1: `scaffold enhance` → Agent Runtime per agent
- [x] M2-2: Deploy flight → hotel → trip-planner (agent identity)
- [x] M2-3: Eval smoke (local `agents-cli eval run --region global`; Cloud Trace manual in console)
- [x] M2-4: `docs/guides/02-iam-deploy.md`

## Milestone 3 — Gateway + mesh governance

- [x] M3-1: Register all agents in Agent Registry (auto on deploy; discovery in `docs/archive/yexperiment-poc/2026-06-21-m3-discovery.md`)
- [x] M3-2a: IAM ingress on trip-planner (ADC user; curl smoke test in `docs/guides/03-auth-gateway.md`)
- [ ] M3-2b: Agent Gateway + OAuth ingress (requires OAuth client + real Google Groups + `AUTH_PROVIDER_BINDING`)
- [x] M3-3: Agent-to-agent IAP egress policies applied (flight/hotel; `--resource-type=agent-registry`, registry UIDs)
- [x] M3-3b: Registry services created (3) via `apply_mesh_governance.sh`
- [ ] M3-3c: Registry bindings trip-planner→flight/hotel (blocked until `AUTH_PROVIDER_BINDING`)
- [x] M3-4: Persona tests (local `MESH_USER_PERSONA` + 37 unit tests; platform gateway tests deferred to M3-2b)
- [x] M3-5: `docs/guides/03-auth-gateway.md`, `04-mesh-governance.md`
- [x] M3-6: `docs/notes/ACCEPTANCE.md`, `2026-06-21-m3-platform-tests.md`
