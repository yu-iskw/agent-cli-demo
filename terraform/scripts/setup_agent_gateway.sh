#!/usr/bin/env bash
# M3-2b: Agent Gateway + OAuth connector setup (DRY_RUN first).
#
# Prerequisites:
#   - ADC: gcloud auth application-default login
#   - OAuth client created in Google Cloud Console (3LO)
#
# Required for OAuth connector (Phase 2):
#   export OAUTH_CLIENT_ID=...
#   export OAUTH_CLIENT_SECRET=...   # or read from Secret Manager
#
# Optional:
#   export MESH_OAUTH_CONNECTOR_ID=mesh-oauth-3lo
#   export MESH_EGRESS_GATEWAY_ID=mesh-egress-gateway
#   export MESH_INGRESS_GATEWAY_ID=mesh-ingress-gateway
#   export AUTH_PROVIDER_BINDING=projects/.../locations/.../connectors/...
#
# Usage:
#   ./terraform/scripts/setup_agent_gateway.sh              # gateways only
#   ./terraform/scripts/setup_agent_gateway.sh --with-oauth # + OAuth connector
#   ./terraform/scripts/setup_agent_gateway.sh --apply-governance
#
# After OAuth connector exists, export AUTH_PROVIDER_BINDING and run:
#   ./terraform/scripts/apply_mesh_governance.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GATEWAY_DIR="${REPO_ROOT}/terraform/gateway"
ENV_FILE="${REPO_ROOT}/terraform/registry/mesh-agents.env"

WITH_OAUTH=false
APPLY_GOVERNANCE=false
for arg in "$@"; do
	case "${arg}" in
	--with-oauth) WITH_OAUTH=true ;;
	--apply-governance) APPLY_GOVERNANCE=true ;;
	*)
		echo "unknown arg: ${arg}" >&2
		exit 2
		;;
	esac
done

# shellcheck disable=SC1090
if [[ ! -f ${ENV_FILE} ]]; then
	echo "error: missing ${ENV_FILE}; run ./terraform/scripts/discover_mesh.sh after deploy" >&2
	exit 1
fi
source "${ENV_FILE}"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/require_project.sh"

EGRESS_GATEWAY_ID="${MESH_EGRESS_GATEWAY_ID:-mesh-egress-gateway}"
INGRESS_GATEWAY_ID="${MESH_INGRESS_GATEWAY_ID:-mesh-ingress-gateway}"
OAUTH_CONNECTOR_ID="${MESH_OAUTH_CONNECTOR_ID:-mesh-oauth-3lo}"

log() {
	echo "[setup-agent-gateway] $*"
}

require_cmd() {
	local cmd="$1"
	if ! command -v "${cmd}" >/dev/null 2>&1; then
		echo "error: required command not found: ${cmd}" >&2
		exit 1
	fi
}

phase1_gateways() {
	log "Phase 1: create egress + ingress Agent Gateways"
	if ! gcloud alpha network-services agent-gateways describe "${EGRESS_GATEWAY_ID}" \
		--project="${PROJECT}" --location="${REGION}" >/dev/null 2>&1; then
		log "  import egress gateway ${EGRESS_GATEWAY_ID}"
		local rendered
		rendered="$(mktemp)"
		sed "s|PROJECT|${PROJECT}|g; s|REGION|${REGION}|g" \
			"${GATEWAY_DIR}/mesh-egress-gateway.yaml" >"${rendered}"
		gcloud alpha network-services agent-gateways import "${EGRESS_GATEWAY_ID}" \
			--source="${rendered}" \
			--location="${REGION}" \
			--project="${PROJECT}"
		rm -f "${rendered}"
	else
		log "  skip: egress gateway ${EGRESS_GATEWAY_ID} exists"
	fi

	if ! gcloud alpha network-services agent-gateways describe "${INGRESS_GATEWAY_ID}" \
		--project="${PROJECT}" --location="${REGION}" >/dev/null 2>&1; then
		log "  import ingress gateway ${INGRESS_GATEWAY_ID}"
		gcloud alpha network-services agent-gateways import "${INGRESS_GATEWAY_ID}" \
			--source="${GATEWAY_DIR}/mesh-ingress-gateway.yaml" \
			--location="${REGION}" \
			--project="${PROJECT}"
	else
		log "  skip: ingress gateway ${INGRESS_GATEWAY_ID} exists"
	fi
}

phase2_oauth_connector() {
	log "Phase 2: 3LO OAuth connector (${OAUTH_CONNECTOR_ID})"
	if [[ -z ${OAUTH_CLIENT_ID-} || -z ${OAUTH_CLIENT_SECRET-} ]]; then
		echo "error: set OAUTH_CLIENT_ID and OAUTH_CLIENT_SECRET for --with-oauth" >&2
		echo "       Create OAuth client in Google Auth Platform; redirect URI:" >&2
		echo "       https://iamconnectorcredentials.googleapis.com/v1/projects/${PROJECT}/locations/${REGION}/connectors/${OAUTH_CONNECTOR_ID}/oauthcallback" >&2
		exit 1
	fi

	if gcloud alpha agent-identity connectors describe "${OAUTH_CONNECTOR_ID}" \
		--project="${PROJECT}" --location="${REGION}" >/dev/null 2>&1; then
		log "  skip: connector ${OAUTH_CONNECTOR_ID} exists"
	else
		gcloud alpha agent-identity connectors create "${OAUTH_CONNECTOR_ID}" \
			--project="${PROJECT}" \
			--location="${REGION}" \
			--three-legged-oauth-client-id="${OAUTH_CLIENT_ID}" \
			--three-legged-oauth-client-secret="${OAUTH_CLIENT_SECRET}" \
			--three-legged-oauth-authorization-url="https://accounts.google.com/o/oauth2/v2/auth" \
			--three-legged-oauth-token-url="https://oauth2.googleapis.com/token"
	fi

	export AUTH_PROVIDER_BINDING="projects/${PROJECT}/locations/${REGION}/connectors/${OAUTH_CONNECTOR_ID}"
	log "  AUTH_PROVIDER_BINDING=${AUTH_PROVIDER_BINDING}"
	log "  grant roles/iamconnectors.user to trip-planner agent identity when redeploying with --agent-identity"
}

phase3_authz_extension() {
	log "Phase 3: IAP authz extension (DRY_RUN)"
	if gcloud beta service-extensions authz-extensions describe mesh-iap-authz-ext \
		--location="${REGION}" --project="${PROJECT}" >/dev/null 2>&1; then
		log "  skip: mesh-iap-authz-ext exists"
		return 0
	fi
	gcloud beta service-extensions authz-extensions import mesh-iap-authz-ext \
		--source="${GATEWAY_DIR}/mesh-iap-authz-extension.yaml" \
		--location="${REGION}" \
		--project="${PROJECT}" || {
		log "  warn: authz extension import failed (may need API enablement or permissions)"
		log "        configure DRY_RUN via console: Access Authorization → Audit-only"
	}
}

phase4_apply_governance() {
	log "Phase 4: apply mesh governance (bindings + IAP)"
	if [[ -z ${AUTH_PROVIDER_BINDING-} ]]; then
		export AUTH_PROVIDER_BINDING="projects/${PROJECT}/locations/${REGION}/connectors/${OAUTH_CONNECTOR_ID}"
	fi
	"${SCRIPT_DIR}/apply_mesh_governance.sh"
}

main() {
	require_cmd gcloud
	phase1_gateways
	if ${WITH_OAUTH}; then
		phase2_oauth_connector
	fi
	phase3_authz_extension
	if ${APPLY_GOVERNANCE}; then
		if [[ -z ${AUTH_PROVIDER_BINDING-} && ${WITH_OAUTH} == false ]]; then
			echo "error: --apply-governance requires AUTH_PROVIDER_BINDING or --with-oauth" >&2
			exit 1
		fi
		phase4_apply_governance
	fi
	log "done"
	log "Next: create Google Groups for personas, redeploy trip-planner with agent_gateway_config,"
	log "      run ./terraform/scripts/check_mesh_gateway_status.sh"
}

main "$@"
