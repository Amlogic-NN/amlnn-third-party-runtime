#!/usr/bin/env bash
# Build the Yocto64 pipeline demo natively on the Armbian aarch64 test board.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)"
RELEASE_DIR="${REPO_ROOT}/tools/amlnn_release"
CXX="${CXX:-c++}"
ORT_BUILD_DIR="${ORT_BUILD_DIR:-${REPO_ROOT}/build/AMLNN-yocto64/Release}"
OUTPUT_DIR="${OUTPUT_DIR:-${RELEASE_DIR}/pipeline_demo/bin/yocto64}"

command -v "${CXX}" >/dev/null
[[ "$(uname -m)" == "aarch64" ]] || {
  echo "Build pipeline_demo on the aarch64 target after deploying libonnxruntime.so; current host is $(uname -m)" >&2
  exit 1
}
[[ -f "${ORT_BUILD_DIR}/libonnxruntime.so" ]] || {
  echo "ONNX Runtime library not found: ${ORT_BUILD_DIR}/libonnxruntime.so" >&2
  exit 1
}

mkdir -p "${OUTPUT_DIR}"
"${CXX}" \
  -std=c++17 \
  -O2 \
  -fexceptions \
  -frtti \
  -I"${REPO_ROOT}/include/onnxruntime" \
  -I"${REPO_ROOT}/include/onnxruntime/core/session" \
  "${RELEASE_DIR}/pipeline_demo/pipeline_demo.cc" \
  -L"${ORT_BUILD_DIR}" \
  -lonnxruntime \
  -Wl,-rpath,'$ORIGIN' \
  -o "${OUTPUT_DIR}/pipeline_demo"

cp -f "${ORT_BUILD_DIR}/libonnxruntime.so" "${OUTPUT_DIR}/"
# The native ORT shared object has SONAME libonnxruntime.so.1. Keep the
# unversioned copy for users and provide the SONAME expected by the loader.
ln -sf "libonnxruntime.so" "${OUTPUT_DIR}/libonnxruntime.so.1"
echo "Output: ${OUTPUT_DIR}"
