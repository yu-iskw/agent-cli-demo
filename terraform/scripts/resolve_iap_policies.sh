#!/usr/bin/env bash
# Resolve IAP agent-to-agent policy templates with project-specific principals.
# Usage: ./terraform/scripts/resolve_iap_policies.sh
#
# Reads TRIP_PLANNER_PRINCIPAL (or TRIP_PLANNER_AGENT_PRINCIPAL) from the
# environment or terraform/registry/mesh-agents.env and writes
# terraform/policies/*.resolved.json (gitignored).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
POLICIES_DIR="${REPO_ROOT}/terraform/policies"
ENV_FILE="${REPO_ROOT}/terraform/registry/mesh-agents.env"

if [[ -f ${ENV_FILE} ]]; then
	# shellcheck disable=SC1090
	source "${ENV_FILE}"
fi

TRIP_PLANNER_PRINCIPAL="${TRIP_PLANNER_PRINCIPAL:-${TRIP_PLANNER_AGENT_PRINCIPAL-}}"
if [[ -z ${TRIP_PLANNER_PRINCIPAL} ]]; then
	echo "error: set TRIP_PLANNER_PRINCIPAL or TRIP_PLANNER_AGENT_PRINCIPAL" >&2
	exit 1
fi

resolve_template() {
	local template_name="$1"
	local template_path="${POLICIES_DIR}/${template_name}.json"
	local resolved_path="${POLICIES_DIR}/${template_name}.resolved.json"

	if [[ ! -f ${template_path} ]]; then
		echo "error: missing template ${template_path}" >&2
		exit 1
	fi

	sed "s|TRIP_PLANNER_AGENT_PRINCIPAL|${TRIP_PLANNER_PRINCIPAL}|g" \
		"${template_path}" >"${resolved_path}"
	echo "wrote ${resolved_path}"
}

resolve_template "agent-to-agent-flight"
resolve_template "agent-to-agent-hotel"
