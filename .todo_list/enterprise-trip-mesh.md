# Enterprise Trip-Planner Mesh — TODO

Project: `yexperiment` | Region: `asia-northeast1` | Private only

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

- [ ] M3-1: Register all agents in Agent Registry (console — see `docs/guides/04-mesh-governance.md`)
- [ ] M3-2: Agent Gateway + OAuth ingress (requires OAuth client + real Google Groups)
- [ ] M3-3: Agent-to-agent IAP policies (`terraform/policies/`, post-registry)
- [x] M3-4: Persona tests (local `MESH_USER_PERSONA` + unit tests; platform negative tests after M3-2/3)
- [x] M3-5: `docs/guides/03-auth-gateway.md`, `04-mesh-governance.md`
- [x] M3-6: `docs/notes/ACCEPTANCE.md`
