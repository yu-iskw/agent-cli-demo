# Agent Gateway setup — 2026-06-21

Project: `yexperiment` | Region: `asia-northeast1`

## Created resources

| Resource              | ID                     | Status     |
| --------------------- | ---------------------- | ---------- |
| Egress Agent Gateway  | `mesh-egress-gateway`  | ✅ Created |
| Ingress Agent Gateway | `mesh-ingress-gateway` | ✅ Created |
| IAP authz extension   | `mesh-iap-authz-ext`   | ✅ DRY_RUN |

```bash
# Verify
gcloud alpha network-services agent-gateways list \
  --project=yexperiment --location=asia-northeast1

gcloud beta service-extensions authz-extensions describe mesh-iap-authz-ext \
  --project=yexperiment --location=asia-northeast1
```

## Still required (M3-2b)

| Item                             | Blocker                                              |
| -------------------------------- | ---------------------------------------------------- |
| OAuth connector `mesh-oauth-3lo` | `OAUTH_CLIENT_ID` + `OAUTH_CLIENT_SECRET`            |
| Registry bindings                | `AUTH_PROVIDER_BINDING` + `apply_mesh_governance.sh` |
| Persona Google Groups            | Workspace admin                                      |
| Trip-planner gateway bind        | Redeploy with `agent_gateway_config`                 |

## Commands

```bash
# Status
./terraform/scripts/check_mesh_gateway_status.sh

# OAuth + governance (after OAuth client exists)
export OAUTH_CLIENT_ID=...
export OAUTH_CLIENT_SECRET=...
./terraform/scripts/setup_agent_gateway.sh --with-oauth --apply-governance
```

Guide: [`docs/guides/05-gateway-policy-demo.md`](../../guides/05-gateway-policy-demo.md)
