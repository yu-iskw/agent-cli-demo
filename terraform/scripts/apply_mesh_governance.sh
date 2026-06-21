#!/usr/bin/env bash
# Post-deploy: register agents in Agent Registry and apply IAP policies (M3).
# Usage: ./terraform/scripts/apply_mesh_governance.sh
set -euo pipefail

PROJECT="${GOOGLE_CLOUD_PROJECT:-yexperiment}"
REGION="${GOOGLE_CLOUD_REGION:-asia-northeast1}"

echo "Register agents in Agent Registry via Cloud Console or gcloud (preview APIs)."
echo "Then apply IAP policies from terraform/policies/ — see terraform/policies/README.md"
echo "Project: ${PROJECT} Region: ${REGION}"
