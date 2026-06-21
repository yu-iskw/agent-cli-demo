# Enterprise Trip-Planner Mesh — Overview

Three-agent **A2A mesh** on Google Cloud **Agent Platform** demonstrating enterprise governance: private deploy, IAM/OAuth ingress, and per-agent authorization.

| Agent             | Role                    | Path                                                              |
| ----------------- | ----------------------- | ----------------------------------------------------------------- |
| trip-planner      | Orchestrator (ADK)      | [`src/trip-planner/`](../../src/trip-planner/README.md)           |
| flight-researcher | Flight specialist (A2A) | [`src/flight-researcher/`](../../src/flight-researcher/README.md) |
| hotel-researcher  | Hotel specialist (A2A)  | [`src/hotel-researcher/`](../../src/hotel-researcher/README.md)   |

**Project:** `yexperiment` | **Region:** `asia-northeast1` | **Access:** private only

Live engine IDs: [`docs/notes/2026-06-21-deploy-endpoints.md`](../notes/2026-06-21-deploy-endpoints.md)

## System context

External callers never reach specialists directly. Humans and services enter through **trip-planner**; the orchestrator delegates to **flight-researcher** and **hotel-researcher** over governed A2A.

```mermaid
flowchart TB
  subgraph Callers["Callers"]
    Human["Human user<br/>(Agent Gateway OAuth — M3-2b)"]
    Service["Internal service / CI<br/>(IAM identity token — M3-2a)"]
    Dev["Developer<br/>(Console playground / agents-cli)"]
  end

  subgraph Platform["Gemini Enterprise Agent Platform — yexperiment"]
    GW["Agent Gateway<br/>(ingress — M3-2b)"]
    TP["trip-planner<br/>Reasoning Engine<br/>RemoteA2aAgent orchestrator"]
    FR["flight-researcher<br/>A2A specialist"]
    HR["hotel-researcher<br/>A2A specialist"]
    REG["Agent Registry<br/>+ IAP policies"]
  end

  Human -->|"OAuth 3LO"| GW
  GW --> TP
  Service -->|"IAM token"| TP
  Dev --> TP
  TP -->|"A2A message:send<br/>GoogleCloudAuth ADC"| FR
  TP -->|"A2A message:send"| HR
  REG -.->|"bindings + egress"| TP
  REG -.-> FR
  REG -.-> HR
```

## Agentic mesh topology

Orchestration uses ADK **`RemoteA2aAgent`** sub-agents (not custom delegate tools). Specialist **AgentCards** are bundled under `src/trip-planner/app/cards/`. Governance lives on the platform (IAP, Gateway, Registry)—not in Python persona env vars.

```mermaid
flowchart LR
  subgraph Orchestrator["trip-planner"]
    Root["root_agent<br/>Gemini orchestrator"]
    RA1["flight_researcher<br/>RemoteA2aAgent"]
    RA2["hotel_researcher<br/>RemoteA2aAgent"]
    Auth["a2a_auth.py<br/>GoogleCloudAuth"]
    Cards["app/cards/*.json"]
    Root --> RA1
    Root --> RA2
    RA1 --> Auth
    RA2 --> Auth
    RA1 --> Cards
    RA2 --> Cards
  end

  subgraph Specialists["Agent Runtime — specialists"]
    F["flight-researcher<br/>search_flights"]
    H["hotel-researcher<br/>search_hotels"]
  end

  RA1 -->|"A2A HTTP+JSON"| F
  RA2 -->|"A2A HTTP+JSON"| H
```

## Milestone map

Guides follow the mesh lifecycle from local dev through platform governance.

```mermaid
flowchart LR
  M1["M1 Local mesh<br/>01-local-mesh"]
  M2["M2 IAM deploy<br/>02-iam-deploy"]
  M3a["M3-2a IAM ingress<br/>03-auth-gateway"]
  M3b["M3-2b OAuth Gateway<br/>03-auth-gateway"]
  M3g["M3 Governance<br/>04-mesh-governance"]

  M1 --> M2 --> M3a --> M3b
  M2 --> M3g
  M3a --> M3g
  M3b --> M3g
```

| Guide                                          | Focus                                              |
| ---------------------------------------------- | -------------------------------------------------- |
| [01-local-mesh.md](01-local-mesh.md)           | ADK layout, unit tests, local vs deployed A2A      |
| [02-iam-deploy.md](02-iam-deploy.md)           | Private Agent Runtime deploy order and identities  |
| [03-auth-gateway.md](03-auth-gateway.md)       | IAM ingress (applied) and OAuth Gateway (deferred) |
| [04-mesh-governance.md](04-mesh-governance.md) | Registry, IAP egress, persona matrix, apply script |

## Personas (platform-enforced)

Authorization is evaluated **per agent**, not only at the entry point. Full matrix: [`.agents-cli-spec.md`](../../.agents-cli-spec.md). Platform tests require M3-2b (OAuth + Google Groups)—see [04-mesh-governance.md](04-mesh-governance.md).

## Terraform

Platform service accounts and IAM templates: [`terraform/`](../../terraform/main.tf). Deploy operations impersonate **`agent-operator-sa`**. Registry IDs: [`terraform/registry/mesh-agents.env`](../../terraform/registry/mesh-agents.env).

## Related notes

- A2A refactor rationale: [`docs/notes/2026-06-21-a2a-mesh-refactor.md`](../notes/2026-06-21-a2a-mesh-refactor.md)
- Acceptance checklist: [`docs/notes/ACCEPTANCE.md`](../notes/ACCEPTANCE.md)
