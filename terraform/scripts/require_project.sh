#!/usr/bin/env bash
# Require GOOGLE_CLOUD_PROJECT or PROJECT; optional REGION default.
# Usage: source "$(dirname "$0")/require_project.sh"
set -euo pipefail

PROJECT="${PROJECT:-${GOOGLE_CLOUD_PROJECT-}}"
REGION="${REGION:-${GOOGLE_CLOUD_LOCATION:-asia-northeast1}}"

if [[ -z ${PROJECT} ]]; then
	echo "error: set GOOGLE_CLOUD_PROJECT or PROJECT" >&2
	exit 1
fi

export PROJECT
export REGION
