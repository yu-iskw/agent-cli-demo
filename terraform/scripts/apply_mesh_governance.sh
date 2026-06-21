#!/usr/bin/env bash
# Post-deploy M3 platform governance: Agent Registry services, bindings, IAP.
#
# Usage:
#   ./terraform/scripts/apply_mesh_governance.sh
#
# Optional environment:
#   AUTH_PROVIDER_BINDING   — when set, create trip-planner→flight/hotel bindings (M3-2b)
#   MESH_IAM_TEST_MEMBERS   — comma-separated IAM members for trip-planner ingress (M3-2a)
#
# Uses Application Default Credentials (ADC) for all gcloud and REST calls.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/terraform/registry/mesh-agents.env"
CARDS_DIR="${REPO_ROOT}/terraform/registry/cards"
POLICIES_DIR="${REPO_ROOT}/terraform/policies"

# shellcheck disable=SC1090
source "${ENV_FILE}"

PROJECT="${PROJECT:-${GOOGLE_CLOUD_PROJECT:-yexperiment}}"
REGION="${REGION:-${GOOGLE_CLOUD_LOCATION:-asia-northeast1}}"
REGISTRY_BASE="https://agentregistry.googleapis.com/v1alpha/projects/${PROJECT}/locations/${REGION}"

EXPECTED_AGENTS=(
	"${TRIP_PLANNER_REGISTRY_AGENT}"
	"${FLIGHT_REGISTRY_AGENT}"
	"${HOTEL_REGISTRY_AGENT}"
)

SERVICE_IDS=(trip-planner flight-researcher hotel-researcher)
BINDING_IDS=(trip-planner-to-flight trip-planner-to-hotel)

log() {
	echo "[mesh-governance] $*"
}

require_cmd() {
	local cmd="$1"
	if ! command -v "${cmd}" >/dev/null 2>&1; then
		echo "error: required command not found: ${cmd}" >&2
		exit 1
	fi
}

adc_token() {
	gcloud auth application-default print-access-token
}

gcloud_adc() {
	# CLOUDSDK_AUTH_ACCESS_TOKEN works reliably for IAP; --access-token-file can fail
	# on nested project lookups (cloudresourcemanager GetProject).
	local token
	token="$(adc_token)"
	CLOUDSDK_AUTH_ACCESS_TOKEN="${token}" gcloud "$@"
}

registry_curl() {
	local method="$1"
	local path="$2"
	local token
	token="$(adc_token)"
	curl -fsS \
		-X "${method}" \
		-H "Authorization: Bearer ${token}" \
		-H "Content-Type: application/json" \
		"${REGISTRY_BASE}/${path}"
}

registry_curl_json() {
	local method="$1"
	local path="$2"
	local body="$3"
	local token
	token="$(adc_token)"
	curl -fsS \
		-X "${method}" \
		-H "Authorization: Bearer ${token}" \
		-H "Content-Type: application/json" \
		-d "${body}" \
		"${REGISTRY_BASE}/${path}"
}

agent_uid_present() {
	local agents_json="$1"
	local uid="$2"
	echo "${agents_json}" | jq -e --arg uid "${uid}" \
		'.agents[]? | select(.uid == $uid)' >/dev/null 2>&1
}

service_exists() {
	local services_json="$1"
	local service_id="$2"
	echo "${services_json}" | jq -e --arg id "${service_id}" \
		'.services[]? | select(.name | endswith("/services/" + $id))' >/dev/null 2>&1
}

binding_exists() {
	local bindings_json="$1"
	local binding_id="$2"
	echo "${bindings_json}" | jq -e --arg id "${binding_id}" \
		'.bindings[]? | select(.name | endswith("/bindings/" + $id))' >/dev/null 2>&1
}

phase0_discovery_verify() {
	log "Phase 0: discovery verify (Agent Registry agents)"
	local agents_json
	agents_json="$(registry_curl GET "agents")"

	local agent_count
	agent_count="$(echo "${agents_json}" | jq '.agents | length')"
	log "listed ${agent_count} registry agent(s)"

	local missing=0
	for uid in "${EXPECTED_AGENTS[@]}"; do
		if echo "${agents_json}" | jq -e --arg uid "${uid}" \
			'.agents[]? | select(.uid == $uid)' >/dev/null 2>&1; then
			log "  ok: ${uid}"
		else
			log "  missing: ${uid}"
			missing=$((missing + 1))
		fi
	done

	if [[ ${missing} -gt 0 ]]; then
		echo "error: ${missing} expected mesh agent(s) not found in registry" >&2
		echo "       deploy agents with --agent-identity and re-run discovery" >&2
		exit 1
	fi
}

phase1_create_services() {
	log "Phase 1: create registry services (A2A agent cards, no interfaces field)"
	local services_json
	services_json="$(registry_curl GET "services")"

	for service_id in "${SERVICE_IDS[@]}"; do
		local card_path="${CARDS_DIR}/${service_id}-agent-card.json"
		if echo "${services_json}" | jq -e --arg id "${service_id}" \
			'.services[]? | select(.name | endswith("/services/" + $id))' >/dev/null 2>&1; then
			log "  skip: service ${service_id} already exists"
			continue
		fi

		if [[ ! -f ${card_path} ]]; then
			echo "error: missing agent card ${card_path}" >&2
			exit 1
		fi

		local display_name
		display_name="$(echo "${service_id}" | tr '-' ' ' | awk '{for (i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')"
		local card_content
		card_content="$(jq -c '.' "${card_path}")"
		local body
		body="$(jq -n \
			--arg displayName "${display_name}" \
			--argjson content "${card_content}" \
			'{
        displayName: $displayName,
        agentSpec: {
          type: "A2A_AGENT_CARD",
          content: $content
        }
      }')"

		log "  create: service ${service_id}"
		registry_curl_json POST "services?serviceId=${service_id}" "${body}" >/dev/null
	done
}

phase2_create_bindings() {
	log "Phase 2: trip-planner→flight/hotel bindings (M3-2b OAuth gate)"
	if [[ -z ${AUTH_PROVIDER_BINDING-} ]]; then
		log "  skip: AUTH_PROVIDER_BINDING not set"
		log "        OAuth auth-provider + gateway binding is deferred (M3-2b)."
		log "        Set AUTH_PROVIDER_BINDING to the auth provider resource name when ready."
		return 0
	fi

	log "  AUTH_PROVIDER_BINDING=${AUTH_PROVIDER_BINDING}"
	local bindings_json
	bindings_json="$(registry_curl GET "bindings")"

	for binding_id in "${BINDING_IDS[@]}"; do
		local target_urn=""
		case "${binding_id}" in
		trip-planner-to-flight) target_urn="${FLIGHT_URN}" ;;
		trip-planner-to-hotel) target_urn="${HOTEL_URN}" ;;
		*)
			echo "error: unknown binding ${binding_id}" >&2
			exit 1
			;;
		esac
		if echo "${bindings_json}" | jq -e --arg id "${binding_id}" \
			'.bindings[]? | select(.name | endswith("/bindings/" + $id))' >/dev/null 2>&1; then
			log "  skip: binding ${binding_id} already exists"
			continue
		fi

		local display_name
		display_name="$(echo "${binding_id}" | tr '-' ' ' | awk '{for (i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')"
		local body
		body="$(jq -n \
			--arg displayName "${display_name}" \
			--arg source "${TRIP_PLANNER_URN}" \
			--arg target "${target_urn}" \
			'{
        displayName: $displayName,
        source: { identifier: $source },
        target: { identifier: $target }
      }')"

		log "  create: binding ${binding_id} (${TRIP_PLANNER_URN} → ${target_urn})"
		registry_curl_json POST "bindings?bindingId=${binding_id}" "${body}" >/dev/null
	done
}

phase3_iam_ingress() {
	log "Phase 3: IAM ingress on trip-planner (M3-2a)"
	if [[ -z ${MESH_IAM_TEST_MEMBERS-} ]]; then
		log "  skip: MESH_IAM_TEST_MEMBERS not set"
		log "        export comma-separated members, e.g. user:alice@example.com,group:mesh-full-user@..."
		return 0
	fi

	local members_csv="${MESH_IAM_TEST_MEMBERS}"
	local member
	IFS=',' read -ra member_list <<<"${members_csv}"
	for member in "${member_list[@]}"; do
		member="$(echo "${member}" | xargs)"
		if [[ -z ${member} ]]; then
			continue
		fi
		log "  add-iam-policy-binding: ${member} → roles/iap.httpsResourceAccessor"
		gcloud_adc beta iap web add-iam-policy-binding \
			--project="${PROJECT}" \
			--region="${REGION}" \
			--resource-type=agent-registry \
			--agent="${TRIP_PLANNER_REGISTRY_AGENT}" \
			--member="${member}" \
			--role="roles/iap.httpsResourceAccessor" \
			--quiet
	done
}

phase4_iap_dry_run() {
	log "Phase 4: IAP agent-to-agent policies in DRY_RUN (M3-3)"
	"${SCRIPT_DIR}/resolve_iap_policies.sh"

	local flight_policy="${POLICIES_DIR}/agent-to-agent-flight.resolved.json"
	local hotel_policy="${POLICIES_DIR}/agent-to-agent-hotel.resolved.json"

	log "  set-iam-policy: flight-researcher (${FLIGHT_REGISTRY_AGENT})"
	gcloud_adc beta iap web set-iam-policy "${flight_policy}" \
		--project="${PROJECT}" \
		--region="${REGION}" \
		--resource-type=agent-registry \
		--agent="${FLIGHT_REGISTRY_AGENT}" \
		--quiet

	log "  set-iam-policy: hotel-researcher (${HOTEL_REGISTRY_AGENT})"
	gcloud_adc beta iap web set-iam-policy "${hotel_policy}" \
		--project="${PROJECT}" \
		--region="${REGION}" \
		--resource-type=agent-registry \
		--agent="${HOTEL_REGISTRY_AGENT}" \
		--quiet

	log "  note: enable DRY_RUN on gateway auth extensions before enforcing (see docs/guides/03-auth-gateway.md)"
}

main() {
	require_cmd gcloud
	require_cmd curl
	require_cmd jq

	log "project=${PROJECT} region=${REGION}"
	phase0_discovery_verify
	phase1_create_services
	phase2_create_bindings
	phase3_iam_ingress
	phase4_iap_dry_run
	log "done"
}

main "$@"
