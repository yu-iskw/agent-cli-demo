# M1 implementation notes

Date: 2026-06-21

## Done

- Phase 0 spec and todo list
- Terraform: 4 service accounts + IAM in `yexperiment` (persona group binding deferred until real groups exist)
- Scaffolded three agents with agents-cli 0.5.0
- Implemented mesh_auth, mock tools, auth-gated delegation
- Unit tests: 9 passing across three projects
- Enhanced all agents for `agent_runtime` / `asia-northeast1`

## Learnings

- Fake Google Group emails in Terraform fail apply — keep persona bindings in M3 docs until groups exist
- Trip-planner needs `a2a-sdk` for `RemoteA2aAgent` imports
- `USE_MESH_MOCKS=true` default enables eval without three local A2A servers

## Next

- Human-approved deploy per `docs/guides/02-iam-deploy.md`
- Gateway + registry per `docs/guides/03-auth-gateway.md` and `04-mesh-governance.md`
