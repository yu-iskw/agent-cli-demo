#!/bin/bash
#  Licensed to the Apache Software Foundation (ASF) under one or more
#  contributor license agreements.  See the NOTICE file distributed with
#  this work for additional information regarding copyright ownership.
#  The ASF licenses this file to You under the Apache License, Version 2.0
#  (the "License"); you may not use this file except in compliance with
#  the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
set -Eeuo pipefail

# Constants
SCRIPT_FILE="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "${SCRIPT_FILE}")"
MODULE_DIR="$(dirname "${SCRIPT_DIR}")"

failures=0

# Template package tests (when present) use the root virtualenv.
if [[ -d "${MODULE_DIR}/src/your_package/tests" ]]; then
	echo "==> Testing template package"
	if ! (
		cd "${MODULE_DIR}"
		uv run pytest -v -s --cache-clear \
			--cov="${MODULE_DIR}/src/your_package" \
			--cov-report=term-missing \
			--cov-report=xml \
			"src/your_package/tests"
	); then
		failures=$((failures + 1))
	fi
fi

# Agent projects ship their own pyproject.toml and virtualenvs.
for agent_dir in "${MODULE_DIR}"/src/*/; do
	if [[ ! -f "${agent_dir}/pyproject.toml" || ! -d "${agent_dir}/tests" ]]; then
		continue
	fi
	if [[ ${agent_dir} == *"/your_package/" ]]; then
		continue
	fi

	echo "==> Testing ${agent_dir}"
	if ! (
		cd "${agent_dir}"
		uv run pytest -v -s --cache-clear
	); then
		failures=$((failures + 1))
	fi
done

if [[ ${failures} -gt 0 ]]; then
	echo "error: ${failures} test suite(s) failed" >&2
	exit 1
fi

ran_any=0
if [[ -d "${MODULE_DIR}/src/your_package/tests" ]]; then
	ran_any=1
fi
for agent_dir in "${MODULE_DIR}"/src/*/; do
	if [[ -f "${agent_dir}/pyproject.toml" && -d "${agent_dir}/tests" && ${agent_dir} != *"/your_package/" ]]; then
		ran_any=1
		break
	fi
done
if [[ ${ran_any} -eq 0 ]]; then
	echo "error: no tests directories found under ${MODULE_DIR}/src" >&2
	exit 1
fi
