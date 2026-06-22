# Deploy blocker — AgentCard introspection (resolved 2026-06-21)

## Original symptom

`agents-cli deploy` failed during agent introspection for A2A specialists:

```text
AttributeError: 'AgentCard' object has no attribute 'DESCRIPTOR'
```

## Resolution

Added `app/app_utils/a2a_deploy_shim.py` on flight-researcher and hotel-researcher:

1. Serialize Pydantic `AgentCard` to `struct_pb2.Struct` for deploy introspection.
2. Override `register_operations()` to temporarily restore the Pydantic card.
3. Restore Pydantic card in `set_up()` before `A2aAgent.set_up()`.

All three agents deployed successfully. See `docs/notes/2026-06-21-deploy-endpoints.md`.

## Secondary note: agent identity vs service account

Deploy with both `--service-account` and `--agent-identity` returns:

```text
Cannot set spec.service_account when spec.identity_type is AGENT_IDENTITY
```

Use `--agent-identity` only for this demo; Terraform runtime SAs remain for IAM policy bindings.
