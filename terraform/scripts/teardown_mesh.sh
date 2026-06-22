#!/usr/bin/env bash
# Full mesh teardown (reverse deploy order).
#
# Usage:
#   ./terraform/scripts/teardown_mesh.sh --dry-run
#   ./terraform/scripts/teardown_mesh.sh --confirm YOUR_GCP_PROJECT
#
# Prerequisites:
#   - ADC: gcloud auth application-default login
#   - gcloud, curl, jq, terraform on PATH
#   - IAM: aiplatform.admin + registry/gateway delete permissions
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/terraform/registry/mesh-agents.env"
TERRAFORM_DIR="${REPO_ROOT}/terraform"
EMPTY_IAP_POLICY='{"bindings":[]}'

DRY_RUN=true
CONFIRM_PROJECT=""
SKIP_TERRAFORM=false
INCLUDE_ORPHANS=false

SERVICE_IDS=(trip-planner flight-researcher hotel-researcher)
BINDING_IDS=(trip-planner-to-flight trip-planner-to-hotel)
ENGINE_IDS=()
REGISTRY_AGENT_UIDS=()

log() {
	echo "[teardown-mesh] $*"
}

warn() {
	echo "[teardown-mesh] warn: $*" >&2
}

die() {
	echo "[teardown-mesh] error: $*" >&2
	exit 1
}

require_cmd() {
	local cmd="$1"
	if ! command -v "${cmd}" >/dev/null 2>&1; then
		die "required command not found: ${cmd}"
	fi
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dry-run)
			DRY_RUN=true
			shift
			;;
		--confirm)
			DRY_RUN=false
			if [[ $# -lt 2 ]]; then
				die "--confirm requires PROJECT argument"
			fi
			CONFIRM_PROJECT="$2"
			shift 2
			;;
		--skip-terraform)
			SKIP_TERRAFORM=true
			shift
			;;
		--include-orphans)
			INCLUDE_ORPHANS=true
			shift
			;;
		--help | -h)
			sed -n '1,20p' "$0"
			exit 0
			;;
		*)
			die "unknown arg: $1"
			;;
		esac
	done
}

load_env() {
	# shellcheck disable=SC1091
	source "${SCRIPT_DIR}/require_project.sh"

	if [[ -f ${ENV_FILE} ]]; then
		# shellcheck disable=SC1090
		source "${ENV_FILE}"
	else
		warn "missing ${ENV_FILE}; using displayName discovery for engines/registry"
		TRIP_PLANNER_ENGINE_ID=""
		HOTEL_ENGINE_ID=""
		FLIGHT_ENGINE_ID=""
		TRIP_PLANNER_REGISTRY_AGENT=""
		FLIGHT_REGISTRY_AGENT=""
		HOTEL_REGISTRY_AGENT=""
	fi

	NUMERIC_PROJECT="${NUMERIC_PROJECT:-$(gcloud projects describe "${PROJECT}" --format='value(projectNumber)' 2>/dev/null || true)}"
	EGRESS_GATEWAY_ID="${MESH_EGRESS_GATEWAY_ID:-mesh-egress-gateway}"
	INGRESS_GATEWAY_ID="${MESH_INGRESS_GATEWAY_ID:-mesh-ingress-gateway}"
	OAUTH_CONNECTOR_ID="${MESH_OAUTH_CONNECTOR_ID:-mesh-oauth-3lo}"
	AUTHZ_EXTENSION_ID="mesh-iap-authz-ext"
	REGISTRY_BASE="https://agentregistry.googleapis.com/v1alpha/projects/${PROJECT}/locations/${REGION}"
	AI_PLATFORM_BASE="https://${REGION}-aiplatform.googleapis.com/v1/projects/${PROJECT}/locations/${REGION}"

	ENGINE_IDS=(
		"${TRIP_PLANNER_ENGINE_ID}"
		"${HOTEL_ENGINE_ID}"
		"${FLIGHT_ENGINE_ID}"
	)
	REGISTRY_AGENT_UIDS=(
		"${TRIP_PLANNER_REGISTRY_AGENT}"
		"${FLIGHT_REGISTRY_AGENT}"
		"${HOTEL_REGISTRY_AGENT}"
	)
}

adc_token() {
	gcloud auth application-default print-access-token
}

gcloud_adc() {
	local token
	token="$(adc_token)"
	CLOUDSDK_AUTH_ACCESS_TOKEN="${token}" gcloud "$@"
}

check_exit_status() {
	local -n _rc_ref=$1
	shift
	set +e
	"$@"
	_rc_ref=$?
	set -e
}

fetch_aiplatform_json() {
	local path="$1"
	local -n _json_ref=$2
	set +e
	_json_ref="$(aiplatform_curl GET "${path}" 2>/dev/null)"
	local rc=$?
	set -e
	if [[ ${rc} -ne 0 ]]; then
		_json_ref='{}'
	fi
}

fetch_registry_json() {
	local path="$1"
	local -n _json_ref=$2
	set +e
	_json_ref="$(registry_curl GET "${path}" 2>/dev/null)"
	local rc=$?
	set -e
	if [[ ${rc} -ne 0 ]]; then
		_json_ref='{}'
	fi
}

run_or_dry() {
	local description="$1"
	shift
	if [[ ${DRY_RUN} == true ]]; then
		log "  [dry-run] ${description}"
		return 0
	fi
	log "  ${description}"
	"$@"
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

aiplatform_curl() {
	local method="$1"
	local path="$2"
	local token
	token="$(adc_token)"
	curl -fsS \
		-X "${method}" \
		-H "Authorization: Bearer ${token}" \
		-H "Content-Type: application/json" \
		"${AI_PLATFORM_BASE}/${path}"
}

confirm_gate() {
	if [[ ${DRY_RUN} == true ]]; then
		log "mode=dry-run (no mutations)"
		return 0
	fi
	if [[ -z ${CONFIRM_PROJECT} ]]; then
		die "mutations require --confirm PROJECT (must match GOOGLE_CLOUD_PROJECT or mesh-agents.env)"
	fi
	if [[ ${CONFIRM_PROJECT} != "${PROJECT}" ]]; then
		die "--confirm project '${CONFIRM_PROJECT}' does not match mesh env PROJECT='${PROJECT}'"
	fi
	log "mode=execute confirm=${CONFIRM_PROJECT}"
}

phase0_preflight() {
	log "Phase 0: preflight inventory"
	log "  project=${PROJECT} region=${REGION} numeric=${NUMERIC_PROJECT}"

	local engines_json
	fetch_aiplatform_json "reasoningEngines" engines_json
	local engine_count
	engine_count="$(echo "${engines_json}" | jq '.reasoningEngines | length // 0')"
	log "  reasoning engines listed: ${engine_count}"
	echo "${engines_json}" | jq -r '.reasoningEngines[]? | "    \(.displayName) \(.name)"' || true

	local known_ids
	known_ids="$(printf '%s\n' "${ENGINE_IDS[@]}")"
	echo "${engines_json}" | jq -r '.reasoningEngines[]? | .name | split("/") | last' | while read -r engine_id; do
		if ! echo "${known_ids}" | grep -qx "${engine_id}"; then
			warn "orphan engine not in mesh-agents.env: ${engine_id} (use --include-orphans to delete)"
		fi
	done

	local rc
	for uid in "${REGISTRY_AGENT_UIDS[@]}"; do
		check_exit_status rc registry_curl GET "agents/${uid}"
		if [[ ${rc} -eq 0 ]]; then
			log "  registry agent present: ${uid}"
		else
			log "  registry agent absent: ${uid}"
		fi
	done

	local services_json
	fetch_registry_json "services" services_json
	for service_id in "${SERVICE_IDS[@]}"; do
		if echo "${services_json}" | jq -e --arg id "${service_id}" \
			'.services[]? | select(.name | endswith("/services/" + $id))' >/dev/null 2>&1; then
			log "  registry service present: ${service_id}"
		else
			log "  registry service absent: ${service_id}"
		fi
	done

	for gw_id in "${EGRESS_GATEWAY_ID}" "${INGRESS_GATEWAY_ID}"; do
		check_exit_status rc gcloud_adc alpha network-services agent-gateways describe "${gw_id}" \
			--project="${PROJECT}" --location="${REGION}"
		if [[ ${rc} -eq 0 ]]; then
			log "  gateway present: ${gw_id}"
		else
			log "  gateway absent: ${gw_id}"
		fi
	done

	check_exit_status rc gcloud_adc beta service-extensions authz-extensions describe "${AUTHZ_EXTENSION_ID}" \
		--project="${PROJECT}" --location="${REGION}"
	if [[ ${rc} -eq 0 ]]; then
		log "  authz extension present: ${AUTHZ_EXTENSION_ID}"
	else
		log "  authz extension absent: ${AUTHZ_EXTENSION_ID}"
	fi

	check_exit_status rc gcloud_adc alpha agent-identity connectors describe "${OAUTH_CONNECTOR_ID}" \
		--project="${PROJECT}" --location="${REGION}"
	if [[ ${rc} -eq 0 ]]; then
		log "  oauth connector present: ${OAUTH_CONNECTOR_ID}"
	else
		log "  oauth connector absent: ${OAUTH_CONNECTOR_ID}"
	fi

	if [[ -f ${TERRAFORM_DIR}/terraform.tfstate ]]; then
		local tf_count
		tf_count="$(cd "${TERRAFORM_DIR}" && terraform state list 2>/dev/null | wc -l | tr -d ' ')"
		log "  terraform state resources: ${tf_count}"
	else
		warn "terraform state file missing at ${TERRAFORM_DIR}/terraform.tfstate"
	fi
}

delete_reasoning_engine() {
	local engine_id="$1"
	local display_name="$2"
	local rc
	check_exit_status rc aiplatform_curl GET "reasoningEngines/${engine_id}"
	if [[ ${rc} -eq 0 ]]; then
		run_or_dry "delete reasoning engine ${display_name} (${engine_id})" \
			aiplatform_curl DELETE "reasoningEngines/${engine_id}?force=true"
	else
		log "  skip: reasoning engine ${display_name} (${engine_id}) not found"
	fi
}

phase1_delete_engines() {
	log "Phase 1: delete Reasoning Engines (trip-planner → hotel → flight)"
	delete_reasoning_engine "${TRIP_PLANNER_ENGINE_ID}" "trip-planner"
	delete_reasoning_engine "${HOTEL_ENGINE_ID}" "hotel-researcher"
	delete_reasoning_engine "${FLIGHT_ENGINE_ID}" "flight-researcher"

	if [[ ${INCLUDE_ORPHANS} == true ]]; then
		log "  scanning for orphan engines (--include-orphans)"
		local engines_json known_ids engine_id display_name engine_lines
		fetch_aiplatform_json "reasoningEngines" engines_json
		known_ids="$(printf '%s\n' "${ENGINE_IDS[@]}")"
		engine_lines="$(echo "${engines_json}" | jq -r '.reasoningEngines[]? | "\(.name | split("/") | last)\t\(.displayName // "orphan")"')"
		while IFS=$'\t' read -r engine_id display_name; do
			[[ -z ${engine_id} ]] && continue
			if echo "${known_ids}" | grep -qx "${engine_id}"; then
				continue
			fi
			delete_reasoning_engine "${engine_id}" "${display_name:-orphan}"
		done <<<"${engine_lines}"
	fi
}

reset_iap_policy() {
	local agent_uid="$1"
	local label="$2"
	local rc
	check_exit_status rc gcloud_adc beta iap web get-iam-policy \
		--project="${PROJECT}" \
		--region="${REGION}" \
		--resource-type=agent-registry \
		--agent="${agent_uid}" \
		--format=json
	if [[ ${rc} -ne 0 ]]; then
		log "  skip: no IAP policy on ${label} (${agent_uid})"
		return 0
	fi

	local tmp_policy
	tmp_policy="$(mktemp)"
	echo "${EMPTY_IAP_POLICY}" >"${tmp_policy}"
	run_or_dry "reset IAP policy on ${label} (${agent_uid})" \
		gcloud_adc beta iap web set-iam-policy "${tmp_policy}" \
		--project="${PROJECT}" \
		--region="${REGION}" \
		--resource-type=agent-registry \
		--agent="${agent_uid}" \
		--quiet
	rm -f "${tmp_policy}"
}

phase2_clear_iap() {
	log "Phase 2: clear IAP policies (egress + ingress)"
	reset_iap_policy "${FLIGHT_REGISTRY_AGENT}" "flight-researcher"
	reset_iap_policy "${HOTEL_REGISTRY_AGENT}" "hotel-researcher"
	reset_iap_policy "${TRIP_PLANNER_REGISTRY_AGENT}" "trip-planner"
}

delete_registry_binding() {
	local binding_id="$1"
	local bindings_json
	fetch_registry_json "bindings" bindings_json
	if echo "${bindings_json}" | jq -e --arg id "${binding_id}" \
		'.bindings[]? | select(.name | endswith("/bindings/" + $id))' >/dev/null 2>&1; then
		run_or_dry "delete registry binding ${binding_id}" \
			registry_curl DELETE "bindings/${binding_id}"
	else
		log "  skip: binding ${binding_id} not found"
	fi
}

delete_registry_service() {
	local service_id="$1"
	local rc
	check_exit_status rc registry_curl GET "services/${service_id}"
	if [[ ${rc} -eq 0 ]]; then
		run_or_dry "delete registry service ${service_id}" \
			registry_curl DELETE "services/${service_id}"
	else
		log "  skip: service ${service_id} not found"
	fi
}

delete_registry_agent() {
	local agent_uid="$1"
	local rc
	check_exit_status rc registry_curl GET "agents/${agent_uid}"
	if [[ ${rc} -eq 0 ]]; then
		run_or_dry "delete registry agent ${agent_uid}" \
			registry_curl DELETE "agents/${agent_uid}"
	else
		log "  skip: registry agent ${agent_uid} not found"
	fi
}

phase3_delete_registry() {
	log "Phase 3: delete registry bindings → services → agents"
	for binding_id in "${BINDING_IDS[@]}"; do
		delete_registry_binding "${binding_id}"
	done
	for service_id in "${SERVICE_IDS[@]}"; do
		delete_registry_service "${service_id}"
	done
	for agent_uid in "${REGISTRY_AGENT_UIDS[@]}"; do
		delete_registry_agent "${agent_uid}"
	done
}

delete_if_exists() {
	local resource_type="$1"
	local resource_id="$2"
	local describe_cmd="$3"
	shift 3
	local rc
	set +e
	eval "${describe_cmd}" >/dev/null 2>&1
	rc=$?
	set -e
	if [[ ${rc} -eq 0 ]]; then
		run_or_dry "delete ${resource_type} ${resource_id}" "$@"
	else
		log "  skip: ${resource_type} ${resource_id} not found"
	fi
}

phase4_delete_gateways() {
	log "Phase 4: delete authz extension and Agent Gateways"
	delete_if_exists "authz extension" "${AUTHZ_EXTENSION_ID}" \
		"gcloud_adc beta service-extensions authz-extensions describe ${AUTHZ_EXTENSION_ID} --project=${PROJECT} --location=${REGION}" \
		gcloud_adc beta service-extensions authz-extensions delete "${AUTHZ_EXTENSION_ID}" \
		--project="${PROJECT}" --location="${REGION}" --quiet

	delete_if_exists "egress gateway" "${EGRESS_GATEWAY_ID}" \
		"gcloud_adc alpha network-services agent-gateways describe ${EGRESS_GATEWAY_ID} --project=${PROJECT} --location=${REGION}" \
		gcloud_adc alpha network-services agent-gateways delete "${EGRESS_GATEWAY_ID}" \
		--project="${PROJECT}" --location="${REGION}" --quiet

	delete_if_exists "ingress gateway" "${INGRESS_GATEWAY_ID}" \
		"gcloud_adc alpha network-services agent-gateways describe ${INGRESS_GATEWAY_ID} --project=${PROJECT} --location=${REGION}" \
		gcloud_adc alpha network-services agent-gateways delete "${INGRESS_GATEWAY_ID}" \
		--project="${PROJECT}" --location="${REGION}" --quiet
}

phase5_delete_oauth() {
	log "Phase 5: delete OAuth connector (if exists)"
	delete_if_exists "oauth connector" "${OAUTH_CONNECTOR_ID}" \
		"gcloud_adc alpha agent-identity connectors describe ${OAUTH_CONNECTOR_ID} --project=${PROJECT} --location=${REGION}" \
		gcloud_adc alpha agent-identity connectors delete "${OAUTH_CONNECTOR_ID}" \
		--project="${PROJECT}" --location="${REGION}" --quiet
}

phase6_terraform_destroy() {
	log "Phase 6: terraform destroy (root mesh IAM + service accounts)"
	if [[ ${SKIP_TERRAFORM} == true ]]; then
		log "  skip: --skip-terraform"
		return 0
	fi
	if [[ ! -f ${TERRAFORM_DIR}/terraform.tfstate ]]; then
		warn "no terraform state; skipping destroy"
		return 0
	fi
	local resource_count
	resource_count="$(cd "${TERRAFORM_DIR}" && terraform state list 2>/dev/null | wc -l | tr -d ' ')"
	if [[ ${resource_count} -eq 0 ]]; then
		log "  skip: terraform state already empty"
		return 0
	fi
	if [[ ${DRY_RUN} == true ]]; then
		log "  [dry-run] terraform destroy (${resource_count} resources in state)"
		cd "${TERRAFORM_DIR}" && terraform plan -destroy -no-color 2>&1 | sed 's/^/    /' || true
		return 0
	fi
	log "  terraform destroy (${resource_count} resources)"
	(
		cd "${TERRAFORM_DIR}"
		terraform destroy -auto-approve
	)
}

phase7_verify() {
	log "Phase 7: verify teardown"
	local failures=0

	local engines_json engine_count
	fetch_aiplatform_json "reasoningEngines" engines_json
	engine_count="$(echo "${engines_json}" | jq '.reasoningEngines | length // 0')"
	if [[ ${engine_count} -eq 0 ]]; then
		log "  ok: no reasoning engines"
	else
		warn "reasoning engines still present: ${engine_count}"
		failures=$((failures + 1))
	fi

	local rc
	for gw_id in "${EGRESS_GATEWAY_ID}" "${INGRESS_GATEWAY_ID}"; do
		check_exit_status rc gcloud_adc alpha network-services agent-gateways describe "${gw_id}" \
			--project="${PROJECT}" --location="${REGION}"
		if [[ ${rc} -eq 0 ]]; then
			warn "gateway still present: ${gw_id}"
			failures=$((failures + 1))
		fi
	done

	for service_id in "${SERVICE_IDS[@]}"; do
		check_exit_status rc registry_curl GET "services/${service_id}"
		if [[ ${rc} -eq 0 ]]; then
			warn "registry service still present: ${service_id}"
			failures=$((failures + 1))
		fi
	done

	if [[ ${SKIP_TERRAFORM} == false && -f ${TERRAFORM_DIR}/terraform.tfstate ]]; then
		local tf_count
		tf_count="$(cd "${TERRAFORM_DIR}" && terraform state list 2>/dev/null | wc -l | tr -d ' ')"
		if [[ ${tf_count} -eq 0 ]]; then
			log "  ok: terraform state empty"
		else
			warn "terraform state still has ${tf_count} resource(s)"
			failures=$((failures + 1))
		fi
	fi

	if [[ ${failures} -eq 0 ]]; then
		log "verification passed"
	else
		warn "verification found ${failures} issue(s)"
		return 1
	fi
}

main() {
	parse_args "$@"
	require_cmd gcloud
	require_cmd curl
	require_cmd jq
	require_cmd terraform
	load_env
	confirm_gate

	phase0_preflight
	phase1_delete_engines
	phase2_clear_iap
	phase3_delete_registry
	phase4_delete_gateways
	phase5_delete_oauth
	phase6_terraform_destroy
	local rc
	if [[ ${DRY_RUN} == false ]]; then
		check_exit_status rc phase7_verify
		if [[ ${rc} -ne 0 ]]; then
			:
		fi
	fi
	log "done"
}

main "$@"
