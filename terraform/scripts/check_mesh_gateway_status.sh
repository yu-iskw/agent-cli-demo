#!/usr/bin/env bash
# Report Agent Gateway + Agent Policy readiness for the trip-planner mesh.
#
# Usage:
#   ./terraform/scripts/check_mesh_gateway_status.sh
#   ./terraform/scripts/check_mesh_gateway_status.sh --json
#
# Exit 0 when all required checks pass (gateway demo ready).
# Exit 1 when any required check fails.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/terraform/registry/mesh-agents.env"

JSON_MODE=false
if [[ ${1-} == "--json" ]]; then
	JSON_MODE=true
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

PROJECT="${PROJECT:-yexperiment}"
REGION="${REGION:-asia-northeast1}"
EGRESS_GATEWAY_ID="${MESH_EGRESS_GATEWAY_ID:-mesh-egress-gateway}"
INGRESS_GATEWAY_ID="${MESH_INGRESS_GATEWAY_ID:-mesh-ingress-gateway}"
OAUTH_CONNECTOR_ID="${MESH_OAUTH_CONNECTOR_ID:-mesh-oauth-3lo}"

declare -A CHECKS=()
declare -A DETAILS=()

pass() {
	local key="$1"
	local detail="${2-}"
	CHECKS["${key}"]=pass
	DETAILS["${key}"]="${detail}"
}

fail() {
	local key="$1"
	local detail="${2-}"
	CHECKS["${key}"]=fail
	DETAILS["${key}"]="${detail}"
}

require_cmd() {
	local cmd="$1"
	if ! command -v "${cmd}" >/dev/null 2>&1; then
		echo "error: required command not found: ${cmd}" >&2
		exit 2
	fi
}

adc_token() {
	gcloud auth application-default print-access-token
}

check_registry_agents() {
	local token agents_json count
	token="$(adc_token)"
	agents_json="$(curl -fsS -H "Authorization: Bearer ${token}" \
		"https://agentregistry.googleapis.com/v1alpha/projects/${PROJECT}/locations/${REGION}/agents")"
	count=0
	for uid in "${TRIP_PLANNER_REGISTRY_AGENT}" "${FLIGHT_REGISTRY_AGENT}" "${HOTEL_REGISTRY_AGENT}"; do
		if echo "${agents_json}" | jq -e --arg uid "${uid}" \
			'.agents[]? | select(.uid == $uid)' >/dev/null 2>&1; then
			count=$((count + 1))
		fi
	done
	if [[ ${count} -eq 3 ]]; then
		pass registry_agents "3 mesh registry agents present"
	else
		fail registry_agents "expected 3 mesh registry UIDs; found ${count}"
	fi
}

check_registry_bindings() {
	local token bindings_json
	token="$(adc_token)"
	bindings_json="$(curl -fsS -H "Authorization: Bearer ${token}" \
		"https://agentregistry.googleapis.com/v1alpha/projects/${PROJECT}/locations/${REGION}/bindings")"
	local ok=0
	for binding_id in trip-planner-to-flight trip-planner-to-hotel; do
		if echo "${bindings_json}" | jq -e --arg id "${binding_id}" \
			'.bindings[]? | select(.name | endswith("/bindings/" + $id))' >/dev/null 2>&1; then
			ok=$((ok + 1))
		fi
	done
	if [[ ${ok} -eq 2 ]]; then
		pass registry_bindings "trip-planner→flight/hotel bindings exist"
	else
		fail registry_bindings "found ${ok}/2 bindings (need AUTH_PROVIDER_BINDING + apply)"
	fi
}

check_oauth_connector() {
	if gcloud alpha agent-identity connectors describe "${OAUTH_CONNECTOR_ID}" \
		--project="${PROJECT}" --location="${REGION}" >/dev/null 2>&1; then
		pass oauth_connector "${OAUTH_CONNECTOR_ID} exists"
	else
		fail oauth_connector "missing connector ${OAUTH_CONNECTOR_ID}"
	fi
}

check_egress_gateway() {
	if gcloud alpha network-services agent-gateways describe "${EGRESS_GATEWAY_ID}" \
		--project="${PROJECT}" --location="${REGION}" >/dev/null 2>&1; then
		pass egress_gateway "${EGRESS_GATEWAY_ID} exists"
	else
		fail egress_gateway "missing ${EGRESS_GATEWAY_ID}"
	fi
}

check_ingress_gateway() {
	if gcloud alpha network-services agent-gateways describe "${INGRESS_GATEWAY_ID}" \
		--project="${PROJECT}" --location="${REGION}" >/dev/null 2>&1; then
		pass ingress_gateway "${INGRESS_GATEWAY_ID} exists"
	else
		fail ingress_gateway "missing ${INGRESS_GATEWAY_ID}"
	fi
}

check_iap_egress_policies() {
	local flight_policy="${REPO_ROOT}/terraform/policies/agent-to-agent-flight.resolved.json"
	if [[ -f ${flight_policy} ]]; then
		pass iap_egress_templates "resolved IAP policy files present"
	else
		fail iap_egress_templates "run resolve_iap_policies.sh or apply_mesh_governance.sh Phase 4"
	fi
}

main() {
	require_cmd gcloud
	require_cmd curl
	require_cmd jq

	check_registry_agents
	check_egress_gateway
	check_ingress_gateway
	check_oauth_connector
	check_registry_bindings
	check_iap_egress_policies

	local failed=0
	for key in registry_agents egress_gateway ingress_gateway oauth_connector registry_bindings iap_egress_templates; do
		if [[ ${CHECKS[${key}]} == fail ]]; then
			failed=$((failed + 1))
		fi
	done

	local ready_value=false
	if [[ ${failed} -eq 0 ]]; then
		ready_value=true
	fi

	if ${JSON_MODE}; then
		jq -n \
			--arg project "${PROJECT}" \
			--arg region "${REGION}" \
			--arg ready "${ready_value}" \
			--arg registry_agents "${CHECKS[registry_agents]}:${DETAILS[registry_agents]}" \
			--arg egress_gateway "${CHECKS[egress_gateway]}:${DETAILS[egress_gateway]}" \
			--arg ingress_gateway "${CHECKS[ingress_gateway]}:${DETAILS[ingress_gateway]}" \
			--arg oauth_connector "${CHECKS[oauth_connector]}:${DETAILS[oauth_connector]}" \
			--arg registry_bindings "${CHECKS[registry_bindings]}:${DETAILS[registry_bindings]}" \
			--arg iap_egress_templates "${CHECKS[iap_egress_templates]}:${DETAILS[iap_egress_templates]}" \
			'{
        project: $project,
        region: $region,
        ready: ($ready == "true"),
        checks: {
          registry_agents: $registry_agents,
          egress_gateway: $egress_gateway,
          ingress_gateway: $ingress_gateway,
          oauth_connector: $oauth_connector,
          registry_bindings: $registry_bindings,
          iap_egress_templates: $iap_egress_templates
        }
      }'
	else
		echo "Mesh Gateway + Policy status (${PROJECT}/${REGION})"
		for key in registry_agents egress_gateway ingress_gateway oauth_connector registry_bindings iap_egress_templates; do
			printf "  [%s] %s: %s\n" "${CHECKS[${key}]}" "${key}" "${DETAILS[${key}]}"
		done
		if [[ ${failed} -eq 0 ]]; then
			echo "READY: gateway + policy prerequisites satisfied"
		else
			echo "NOT READY: ${failed} check(s) failed"
		fi
	fi

	if [[ ${failed} -gt 0 ]]; then
		exit 1
	fi
}

main "$@"
