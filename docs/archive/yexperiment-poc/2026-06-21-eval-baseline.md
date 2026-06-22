# Eval baselines — 2026-06-21

Project: `yexperiment` | Inference region: `global` | Deploy region: `asia-northeast1`

Command used for each agent:

```bash
agents-cli eval run --project yexperiment --region global
```

## Results

| Agent             | Metric                  | Mean score | Artifact                                                                     |
| ----------------- | ----------------------- | ---------- | ---------------------------------------------------------------------------- |
| flight-researcher | custom_response_quality | 5.0        | `src/flight-researcher/artifacts/grade_results/results_20260621_195508.json` |
| hotel-researcher  | custom_response_quality | 5.0        | `src/hotel-researcher/artifacts/grade_results/results_20260621_195600.json`  |
| trip-planner      | custom_response_quality | 5.0        | `src/trip-planner/artifacts/grade_results/results_20260621_195653.json`      |

## Notes

- Use `--region global` for Gemini inference; default manifest region `asia-northeast1` may cause model 404 for some Gemini IDs (e.g. `gemini-3.1-flash-lite`).
- Agent `app/agent.py` defaults `GOOGLE_CLOUD_LOCATION` to `global` for local run; Agent Runtime deploy region remains `asia-northeast1`.
- Re-run after deploy with `agents-cli eval compare` against these baselines.

## Post-SequentialAgent baseline (Track 1 — 2026-06-22)

Orchestrator refactored from LLM `delegate_*` tools to `SequentialAgent` + `RemoteA2aAgent` + `trip_synthesizer`.

| Agent        | Metric                  | Mean score | Artifact                                                                |
| ------------ | ----------------------- | ---------- | ----------------------------------------------------------------------- |
| trip-planner | custom_response_quality | 5.0 (2/2)  | `src/trip-planner/artifacts/grade_results/results_20260622_081402.json` |
| traces       | —                       | —          | `src/trip-planner/artifacts/traces/traces_20260622_081319.json`         |

Command:

```bash
export GOOGLE_CLOUD_LOCATION=global
cd src/trip-planner
agents-cli eval run --project yexperiment --region global
```

Legacy pre-refactor baseline for compare: `results_20260621_195653.json` (LlmAgent + `delegate_flight_search` / `delegate_hotel_search`).

## Eval compare (Track 1 — 2026-06-22)

```bash
cd src/trip-planner
agents-cli eval compare \
  artifacts/grade_results/results_20260621_195653.json \
  artifacts/grade_results/results_20260622_081402.json
```

**Outcome:** Pass — no regression.

| Case                       | Legacy | Post-SequentialAgent                           |
| -------------------------- | ------ | ---------------------------------------------- |
| `trip_nyc_sfo`             | 5.0    | 5.0                                            |
| `trip_flight_only_persona` | 5.0    | 5.0 (soft signal; persona is prompt text only) |

Architectural delta (expected): legacy uses `delegate_*` mock tools; post-refactor uses `flight_researcher` / `hotel_researcher` / `trip_synthesizer` in trace. Scores unchanged.

## Cloud Trace verification (Track 1 — 2026-06-22)

**Remote smoke** (engine `2464937943706370048`):

```bash
export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=agent-operator-sa@yexperiment.iam.gserviceaccount.com
cd src/trip-planner
agents-cli run --url \
  "https://asia-northeast1-aiplatform.googleapis.com/v1beta1/projects/yexperiment/locations/asia-northeast1/reasoningEngines/2464937943706370048" \
  --mode adk \
  "Plan NYC to SFO June 28-July 2 2026 with flights and hotels."
```

**Smoke pass:** CLI output included `[flight_researcher]`, `[hotel_researcher]`, and `[trip_synthesizer]` (session `5904371393843167232`).

**Trace pass:** Cloud Trace REST API (`cloudtrace.googleapis.com/v1/projects/yexperiment/traces`) — 13 traces in 48h window; all multi-span (≥2). Example post-deploy trace `053e0e3eb5805a2716b22e3ec58b622b` (47 spans: A2A `on_message_send` + `invocation` + `invoke_agent root_agent`). Live engine has `GOOGLE_CLOUD_AGENT_ENGINE_ENABLE_TELEMETRY=true`.

Console: [Trace explorer — yexperiment](https://console.cloud.google.com/traces/list?project=yexperiment).
