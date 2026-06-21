# 03 — Agent Gateway + OAuth 3LO

Human users reach **trip-planner only** via Agent Gateway. Specialists are not public; they are invoked via governed A2A from the orchestrator.

## Prerequisites

- Milestone 2 complete (agents deployed privately)
- All three agents registered in **Agent Registry**
- OAuth client configured for 3LO ([auth with 3LO](https://docs.cloud.google.com/iam/docs/auth-with-3lo))

## Setup (high level)

1. Create Agent Gateway in `yexperiment` / `asia-northeast1` ([set up Agent Gateway](https://docs.cloud.google.com/gemini-enterprise-agent-platform/govern/gateways/set-up-agent-gateway))
2. Bind gateway to Agent Registry
3. Configure ingress OAuth for trip-planner endpoint
4. Start authorization policies in **DRY_RUN**, then enforce ([delegate authorization](https://docs.cloud.google.com/gemini-enterprise-agent-platform/govern/gateways/delegate-authorization))

## IAM path (programmatic callers)

Internal services and CI use IAM identity tokens — no OAuth:

```bash
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  <private-trip-planner-endpoint>
```

See [manage agent access](https://docs.cloud.google.com/gemini-enterprise-agent-platform/scale/runtime/manage-agent-access).

## OAuth path (human users)

Users authenticate via Gateway OAuth flow; gateway forwards identity to trip-planner with user context for downstream governance checks.

## Do not commit

- OAuth client secrets
- Gateway private keys
- `.env` with credentials

Store secrets in Secret Manager only.
