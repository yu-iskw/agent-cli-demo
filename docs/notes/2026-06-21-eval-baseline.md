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

- Use `--region global` for Gemini inference; default manifest region `asia-northeast1` causes model 404 for `gemini-flash-latest`.
- Agent `app/agent.py` defaults `GOOGLE_CLOUD_LOCATION` to `global` for local run; Agent Runtime deploy region remains `asia-northeast1`.
- Re-run after deploy with `agents-cli eval compare` against these baselines.
