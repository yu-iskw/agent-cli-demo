# 01 — Local mesh

Develop and test the trip-planner mesh before or alongside platform deploy. This guide covers **software architecture**, **local dev modes**, and **offline eval**.

## Prerequisites

- `agents-cli` 0.5.x (`uv tool install google-agents-cli`)
- Python 3.11+
- GCP auth for Vertex eval (optional for unit tests)

## Software architecture

Each agent is an ADK **`App`** with a **`root_agent`**. Trip-planner adds **`RemoteA2aAgent`** sub-agents; specialists expose tools only (no orchestration).

```mermaid
flowchart TB
  subgraph TP["src/trip-planner"]
    TPAgent["agent.py<br/>Agent + sub_agents"]
    TPA2A["a2a_auth.py<br/>GoogleCloudAuth httpx"]
    TPCards["specialist_cards.py<br/>+ app/cards/*.json"]
    TPRuntime["agent_runtime_app.py<br/>AgentEngineApp"]
    TPAgent --> TPA2A
    TPAgent --> TPCards
    TPRuntime --> TPAgent
  end

  subgraph FR["src/flight-researcher"]
    FRAgent["agent.py + search_flights"]
    FRRuntime["agent_runtime_app.py<br/>A2aAgentExecutor"]
    FRShim["a2a_deploy_shim.py"]
    FRRuntime --> FRAgent
    FRRuntime --> FRShim
  end

  subgraph HR["src/hotel-researcher"]
    HRAgent["agent.py + search_hotels"]
    HRRuntime["agent_runtime_app.py"]
    HRRuntime --> HRAgent
  end

  TPAgent -->|"RemoteA2aAgent"| FRRuntime
  TPAgent -->|"RemoteA2aAgent"| HRRuntime
```

| Component        | Location                                                          | Role                                                  |
| ---------------- | ----------------------------------------------------------------- | ----------------------------------------------------- |
| Orchestrator     | `trip-planner/app/agent.py`                                       | Transfers to `flight_researcher` / `hotel_researcher` |
| Outbound auth    | `trip-planner/app/a2a_auth.py`                                    | ADC bearer tokens on A2A HTTP                         |
| Bundled cards    | `trip-planner/app/cards/`                                         | Specialist AgentCard JSON (no deploy env URLs)        |
| Specialist tools | `flight-researcher/app/tools.py`, `hotel-researcher/app/tools.py` | Mock flight/hotel search                              |

Governance is **not** implemented in Python—see [04-mesh-governance.md](04-mesh-governance.md).

## Unit tests (no GCP)

```bash
cd src/flight-researcher && uv run pytest tests/unit/ -q
cd src/hotel-researcher && uv run pytest tests/unit/ -q
cd src/trip-planner && uv run pytest tests/unit/ -q
```

Orchestration wiring: `src/trip-planner/tests/unit/test_a2a_mesh.py`.

## Dev modes

Three ways to exercise the mesh locally:

```mermaid
flowchart TD
  Start["Choose dev mode"]
  U["Unit tests<br/>pytest — no network"]
  D["Deployed mesh<br/>agents-cli run --url"]
  L["Full local A2A<br/>3 terminals localhost"]

  Start --> U
  Start --> D
  Start --> L
```

### Mode A — Deployed mesh (recommended)

Query the live Agent Runtime orchestrator; A2A delegation hits deployed specialists.

```bash
cd src/trip-planner
agents-cli run --url <trip-planner-engine-url> --mode adk \
  "Plan a trip from NYC to San Francisco with flights and hotels."
```

Engine URLs: [`docs/notes/2026-06-21-deploy-endpoints.md`](../notes/2026-06-21-deploy-endpoints.md).

```mermaid
sequenceDiagram
  participant Dev as Developer
  participant CLI as agents-cli
  participant TP as trip-planner Runtime
  participant FR as flight-researcher A2A
  participant HR as hotel-researcher A2A

  Dev->>CLI: run --url trip-planner --mode adk
  CLI->>TP: stream query
  TP->>TP: transfer flight_researcher
  TP->>FR: A2A message:send (ADC)
  FR-->>TP: flight options
  TP->>TP: transfer hotel_researcher
  TP->>HR: A2A message:send
  HR-->>TP: hotel options
  TP-->>CLI: combined trip plan
  CLI-->>Dev: response
```

### Mode B — Full local A2A (three terminals)

Run specialists as local A2A servers; override bundled cards with localhost URLs (**development only**).

```bash
# Terminal 1 — flight
cd src/flight-researcher && agents-cli install && agents-cli run --agent adk_a2a --port 8001

# Terminal 2 — hotel
cd src/hotel-researcher && agents-cli install && agents-cli run --agent adk_a2a --port 8002

# Terminal 3 — orchestrator
export FLIGHT_A2A_CARD_URL=http://127.0.0.1:8001/.well-known/agent.json
export HOTEL_A2A_CARD_URL=http://127.0.0.1:8002/.well-known/agent.json
cd src/trip-planner && agents-cli install && agents-cli run "Plan NYC to SFO."
```

```mermaid
sequenceDiagram
  participant T3 as Terminal 3 trip-planner
  participant T1 as Terminal 1 :8001
  participant T2 as Terminal 2 :8002

  T3->>T1: fetch AgentCard (localhost)
  T3->>T1: A2A message:send
  T1-->>T3: flights
  T3->>T2: A2A message:send
  T2-->>T3: hotels
```

## Eval

Offline eval against the orchestrator (no live A2A required for baseline datasets):

```bash
cd src/trip-planner
agents-cli eval run --region global
```

Baselines: [`docs/notes/2026-06-21-eval-baseline.md`](../notes/2026-06-21-eval-baseline.md).

## Next steps

- Private deploy: [02-iam-deploy.md](02-iam-deploy.md)
- Ingress paths: [03-auth-gateway.md](03-auth-gateway.md)
