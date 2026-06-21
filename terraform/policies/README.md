# IAP agent policy templates

Apply **after** agents are deployed and registered in Agent Registry (Milestone 3).

Replace placeholders:

- `TRIP_PLANNER_AGENT_PRINCIPAL` — trip-planner agent identity principal
- `TARGET_AGENT_ID` — reasoning engine / registry agent ID
- `ALLOWED_USER_MEMBERS` — groups allowed for this specialist

## agent-to-agent-flight.json

Trip-planner may call flight-researcher when the end user is in an allowed group.

```bash
gcloud beta iap web set-iam-policy terraform/policies/agent-to-agent-flight.json \
  --project=yexperiment \
  --agent=TARGET_AGENT_ID \
  --region=asia-northeast1
```

## agent-to-agent-hotel.json

Same pattern for hotel-researcher.

Start with `iamEnforcementMode: DRY_RUN` on gateway extensions before enforcing.

See [Create IAM agent policies](https://docs.cloud.google.com/gemini-enterprise-agent-platform/govern/policies/assign-identity-iam).
