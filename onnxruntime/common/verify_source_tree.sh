#!/usr/bin/env bash
# Verify that this release-tools directory is installed in the matching
# AMLNN-enabled ONNX Runtime source tree. This does not compile anything.
set -euo pipefail

RELEASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${RELEASE_DIR}/../../.." && pwd)"
EXPECTED_ORT_VERSION="${EXPECTED_ORT_VERSION:-1.31.0}"

fail() {
  echo "ERROR: $*" >&2
  exit 2
}

require_file() {
  [[ -f "$1" ]] || fail "required file is missing: $1"
  printf 'OK file: %s\n' "$1"
}

require_text() {
  local pattern="$1"
  local file="$2"
  grep -q -- "${pattern}" "${file}" || fail "${file} does not contain required AMLNN integration: ${pattern}"
  printf 'OK integration: %s\n' "${file}"
}

require_file "${REPO_ROOT}/VERSION_NUMBER"
actual_version="$(tr -d '[:space:]' < "${REPO_ROOT}/VERSION_NUMBER")"
[[ "${actual_version}" == "${EXPECTED_ORT_VERSION}" ]] ||
  fail "ONNX Runtime ${EXPECTED_ORT_VERSION} is required; source tree reports ${actual_version}"
printf 'OK ONNX Runtime version: %s\n' "${actual_version}"

require_file "${REPO_ROOT}/build.sh"
require_file "${REPO_ROOT}/tools/ci_build/build.py"
require_file "${REPO_ROOT}/cmake/CMakeLists.txt"
require_file "${REPO_ROOT}/cmake/onnxruntime_providers_amlnn.cmake"
require_file "${REPO_ROOT}/onnxruntime/core/providers/amlnn/amlnn_execution_provider.cc"
require_file "${REPO_ROOT}/onnxruntime/core/providers/amlnn/builder/aml_adla_bridge.cc"
require_file "${REPO_ROOT}/onnxruntime/core/providers/amlnn/runtime/amlnn_nnsdk2.cc"
require_file "${REPO_ROOT}/include/onnxruntime/core/providers/amlnn/amlnn_provider_factory.h"
require_text 'onnxruntime_USE_AMLNN' "${REPO_ROOT}/cmake/CMakeLists.txt"
require_text 'onnxruntime_providers_amlnn.cmake' "${REPO_ROOT}/cmake/onnxruntime_providers.cmake"

if [[ ! -f "${REPO_ROOT}/cmake/external/onnx/CMakeLists.txt" ]]; then
  fail "ONNX submodule is not initialized; run git submodule update --init --recursive from ${REPO_ROOT}"
fi
printf 'OK submodules: cmake/external/onnx\n'

echo "AMLNN-enabled ONNX Runtime source tree: PASS"
echo "Repository root: ${REPO_ROOT}"
