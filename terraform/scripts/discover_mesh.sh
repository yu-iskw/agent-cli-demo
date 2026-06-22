#!/usr/bin/env bash
# Discover deployed mesh engines + registry IDs; write mesh-agents.env and patch card URLs.
#
# Usage:
#   export GOOGLE_CLOUD_PROJECT=your-gcp-project
#   ./terraform/scripts/discover_mesh.sh
#   ./terraform/scripts/discover_mesh.sh your-gcp-project asia-northeast1
#
# Prerequisites: ADC; three agents deployed (flight → hotel → trip-planner).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/terraform/registry/mesh-agents.env"
APP_CARDS_DIR="${REPO_ROOT}/src/trip-planner/app/cards"
REGISTRY_CARDS_DIR="${REPO_ROOT}/terraform/registry/cards"

MESH_DISPLAY_NAMES=(trip-planner hotel-researcher flight-researcher)

log() {
	echo "[discover-mesh] $*"
}

die() {
	echo "[discover-mesh] error: $*" >&2
	exit 1
}

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

if [[ $# -ge 1 ]]; then
	export GOOGLE_CLOUD_PROJECT="$1"
fi
if [[ $# -ge 2 ]]; then
	export GOOGLE_CLOUD_LOCATION="$2"
fi

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/require_project.sh"

REGISTRY_BASE="https://agentregistry.googleapis.com/v1alpha/projects/${PROJECT}/locations/${REGION}"
AI_PLATFORM_BASE="https://${REGION}-aiplatform.googleapis.com/v1/projects/${PROJECT}/locations/${REGION}"

adc_token() {
	gcloud auth application-default print-access-token
}

api_get() {
	local url="$1"
	local token
	token="$(adc_token)"
	curl -fsS -H "Authorization: Bearer ${token}" "${url}"
}

engine_id_from_name() {
	local name="$1"
	echo "${name}" | awk -F/ '{print $NF}'
}

find_engine_id() {
	local engines_json="$1"
	local display_name="$2"
	echo "${engines_json}" | jq -r --arg dn "${display_name}" \
		'.reasoningEngines[]? | select(.displayName == $dn) | .name | split("/") | last' | head -1
}

find_registry_uid_for_engine() {
	local agents_json="$1"
	local engine_id="$2"
	echo "${agents_json}" | jq -r --arg eid "${engine_id}" \
		'.agents[]? | select(tostring | contains($eid)) | .uid' | head -1
}

principal_for_engine() {
	local engine_id="$1"
	echo "principal://agents.global.proj-${NUMERIC_PROJECT}.system.id.goog/resources/aiplatform/projects/${NUMERIC_PROJECT}/locations/${REGION}/reasoningEngines/${engine_id}"
}

urn_for_engine() {
	local engine_id="$1"
	echo "urn:agent:projects-${NUMERIC_PROJECT}:projects:${NUMERIC_PROJECT}:locations:${REGION}:aiplatform:reasoningEngines:${engine_id}"
}

patch_card_url() {
	local card_path="$1"
	local url="$2"
	jq --arg url "${url}" '.url = $url' "${card_path}" >"${card_path}.tmp"
	mv "${card_path}.tmp" "${card_path}"
	log "  patched url: ${card_path}"
}

main() {
	require_cmd gcloud
	require_cmd curl
	require_cmd jq

	log "project=${PROJECT} region=${REGION}"

	NUMERIC_PROJECT="$(gcloud projects describe "${PROJECT}" --format='value(projectNumber)')"
	[[ -n ${NUMERIC_PROJECT} ]] || die "could not resolve numeric project id"

	local engines_json agents_json
	engines_json="$(api_get "${AI_PLATFORM_BASE}/reasoningEngines")"
	agents_json="$(api_get "${REGISTRY_BASE}/agents")"

	local trip_id hotel_id flight_id
	trip_id="$(find_engine_id "${engines_json}" "trip-planner")"
	hotel_id="$(find_engine_id "${engines_json}" "hotel-researcher")"
	flight_id="$(find_engine_id "${engines_json}" "flight-researcher")"

	[[ -n ${trip_id} && ${trip_id} != null ]] || die "trip-planner Reasoning Engine not found — deploy agents first"
	[[ -n ${hotel_id} && ${hotel_id} != null ]] || die "hotel-researcher Reasoning Engine not found"
	[[ -n ${flight_id} && ${flight_id} != null ]] || die "flight-researcher Reasoning Engine not found"

	local trip_uid hotel_uid flight_uid
	trip_uid="$(find_registry_uid_for_engine "${agents_json}" "${trip_id}")"
	hotel_uid="$(find_registry_uid_for_engine "${agents_json}" "${hotel_id}")"
	flight_uid="$(find_registry_uid_for_engine "${agents_json}" "${flight_id}")"

	[[ -n ${trip_uid} && ${trip_uid} != null ]] || die "trip-planner registry agent not found for engine ${trip_id}"
	[[ -n ${hotel_uid} && ${hotel_uid} != null ]] || die "hotel-researcher registry agent not found"
	[[ -n ${flight_uid} && ${flight_uid} != null ]] || die "flight-researcher registry agent not found"

	local trip_principal hotel_principal flight_principal
	trip_principal="$(principal_for_engine "${trip_id}")"
	hotel_principal="$(principal_for_engine "${hotel_id}")"
	flight_principal="$(principal_for_engine "${flight_id}")"

	local trip_urn hotel_urn flight_urn
	trip_urn="$(urn_for_engine "${trip_id}")"
	hotel_urn="$(urn_for_engine "${hotel_id}")"
	flight_urn="$(urn_for_engine "${flight_id}")"

	local trip_query_url flight_a2a_url hotel_a2a_url
	trip_query_url="https://${REGION}-aiplatform.googleapis.com/v1/projects/${NUMERIC_PROJECT}/locations/${REGION}/reasoningEngines/${trip_id}:query"
	flight_a2a_url="https://${REGION}-aiplatform.googleapis.com/v1beta1/projects/${NUMERIC_PROJECT}/locations/${REGION}/reasoningEngines/${flight_id}/a2a"
	hotel_a2a_url="https://${REGION}-aiplatform.googleapis.com/v1beta1/projects/${NUMERIC_PROJECT}/locations/${REGION}/reasoningEngines/${hotel_id}/a2a"

	local egress_gateway ingress_gateway
	egress_gateway="projects/${PROJECT}/locations/${REGION}/agentGateways/mesh-egress-gateway"
	ingress_gateway="projects/${PROJECT}/locations/${REGION}/agentGateways/mesh-ingress-gateway"

	cat >"${ENV_FILE}" <<EOF
# Generated by discover_mesh.sh — do not commit
PROJECT=${PROJECT}
REGION=${REGION}
NUMERIC_PROJECT=${NUMERIC_PROJECT}

TRIP_PLANNER_ENGINE_ID=${trip_id}
HOTEL_ENGINE_ID=${hotel_id}
FLIGHT_ENGINE_ID=${flight_id}

TRIP_PLANNER_REGISTRY_AGENT=${trip_uid}
HOTEL_REGISTRY_AGENT=${hotel_uid}
FLIGHT_REGISTRY_AGENT=${flight_uid}

TRIP_PLANNER_PRINCIPAL=${trip_principal}
HOTEL_PRINCIPAL=${hotel_principal}
FLIGHT_PRINCIPAL=${flight_principal}

TRIP_PLANNER_URN=${trip_urn}
HOTEL_URN=${hotel_urn}
FLIGHT_URN=${flight_urn}

TRIP_PLANNER_QUERY_URL=${trip_query_url}
FLIGHT_A2A_URL=${flight_a2a_url}
MESH_EGRESS_GATEWAY_ID=mesh-egress-gateway
MESH_INGRESS_GATEWAY_ID=mesh-ingress-gateway
MESH_OAUTH_CONNECTOR_ID=mesh-oauth-3lo
MESH_EGRESS_GATEWAY=${egress_gateway}
MESH_INGRESS_GATEWAY=${ingress_gateway}
EOF

	log "wrote ${ENV_FILE}"

	"${SCRIPT_DIR}/resolve_iap_policies.sh"

	patch_card_url "${APP_CARDS_DIR}/flight-researcher-agent-card.json" "${flight_a2a_url}"
	patch_card_url "${APP_CARDS_DIR}/hotel-researcher-agent-card.json" "${hotel_a2a_url}"
	patch_card_url "${REGISTRY_CARDS_DIR}/flight-researcher-agent-card.json" "${flight_a2a_url}"
	patch_card_url "${REGISTRY_CARDS_DIR}/hotel-researcher-agent-card.json" "${hotel_a2a_url}"

	local trip_card_url
	trip_card_url="${trip_query_url%:query}"
	patch_card_url "${REGISTRY_CARDS_DIR}/trip-planner-agent-card.json" "${trip_card_url}"

	log "done"
}

main "$@"
