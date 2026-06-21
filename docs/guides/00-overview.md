# Enterprise Trip-Planner Mesh

Three-agent A2A mesh on Google Cloud Agent Platform demonstrating enterprise governance.

| Agent             | Role                    | Path                                                  |
| ----------------- | ----------------------- | ----------------------------------------------------- |
| trip-planner      | Orchestrator            | [`src/trip-planner/`](../src/trip-planner/)           |
| flight-researcher | Flight specialist (A2A) | [`src/flight-researcher/`](../src/flight-researcher/) |
| hotel-researcher  | Hotel specialist (A2A)  | [`src/hotel-researcher/`](../src/hotel-researcher/)   |

**Project:** `yexperiment` | **Region:** `asia-northeast1` | **Private only**

## Guides

1. [01-local-mesh.md](01-local-mesh.md) — local development and offline eval
2. [02-iam-deploy.md](02-iam-deploy.md) — private Agent Runtime deploy with IAM
3. [03-auth-gateway.md](03-auth-gateway.md) — Agent Gateway + OAuth 3LO
4. [04-mesh-governance.md](04-mesh-governance.md) — per-agent authorization demo

## Governance personas

See [`.agents-cli-spec.md`](../.agents-cli-spec.md) for the full auth matrix.

## Terraform

Platform service accounts and IAM: [`terraform/`](../terraform/). Impersonate `agent-operator-sa` for all deploy operations.
