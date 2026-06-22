# IAP agent policy templates

Apply **after** agents are deployed and registered in Agent Registry (Milestone 3).

Templates use placeholders resolved at apply time:

- `TRIP_PLANNER_AGENT_PRINCIPAL` — trip-planner agent identity principal (from `terraform/registry/mesh-agents.env`)

## Resolve templates

Generate project-specific policy files (gitignored):

```bash
./terraform/scripts/resolve_iap_policies.sh
```

Writes `agent-to-agent-flight.resolved.json` and `agent-to-agent-hotel.resolved.json` under this directory.

## agent-to-agent-flight.json

Trip-planner may call flight-researcher when the end user is in an allowed group.

```bash
gcloud beta iap web set-iam-policy terraform/policies/agent-to-agent-flight.resolved.json \
  --project=<your-gcp-project> \
  --region=asia-northeast1 \
  --resource-type=agent-registry \
  --agent=FLIGHT_REGISTRY_AGENT_ID
```

Use the **registry agent UID** (for example `agentregistry-00000000-0000-0000-8ad9-56c0770a61aa`), not the Reasoning Engine numeric ID.

## agent-to-agent-hotel.json

Same pattern for hotel-researcher:

```bash
gcloud beta iap web set-iam-policy terraform/policies/agent-to-agent-hotel.resolved.json \
  --project=<your-gcp-project> \
  --region=asia-northeast1 \
  --resource-type=agent-registry \
  --agent=HOTEL_REGISTRY_AGENT_ID
```

## Full M3 apply

The orchestration script runs discovery, registry services, optional bindings, IAM ingress, and IAP policy apply:

```bash
./terraform/scripts/apply_mesh_governance.sh
```

Optional environment:

- `MESH_IAM_TEST_MEMBERS` — comma-separated IAM members for trip-planner ingress (`roles/iap.httpsResourceAccessor`)
- `AUTH_PROVIDER_BINDING` — when set, creates trip-planner→flight/hotel registry bindings (OAuth M3-2b)

Start with `iamEnforcementMode: DRY_RUN` on gateway authorization extensions before enforcing. See [Create IAM agent policies](https://docs.cloud.google.com/gemini-enterprise-agent-platform/govern/policies/assign-identity-iam).
