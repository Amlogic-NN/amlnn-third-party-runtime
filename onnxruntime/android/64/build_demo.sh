#!/usr/bin/env bash
set -euo pipefail

: "${ANDROID_NDK_PATH:?ANDROID_NDK_PATH must be set}"

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)"
RELEASE_DIR="${REPO_ROOT}/tools/amlnn_release"
CXX="${ANDROID_NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang++"
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build/AMLNN-android64}"
ORT_BUILD_DIR="${ORT_BUILD_DIR:-${BUILD_DIR}/Release}"
OUTPUT_DIR="${RELEASE_DIR}/pipeline_demo/bin/android64"

[[ -x "${CXX}" ]] || { echo "Compiler not found: ${CXX}" >&2; exit 1; }
[[ -f "${ORT_BUILD_DIR}/libonnxruntime.so" ]] || {
  echo "ONNX Runtime library not found: ${ORT_BUILD_DIR}/libonnxruntime.so" >&2
  exit 1
}
[[ -f "${ORT_BUILD_DIR}/CMakeCache.txt" ]] || {
  echo "CMake cache not found: ${ORT_BUILD_DIR}/CMakeCache.txt" >&2
  exit 2
}
grep -q '^onnxruntime_USE_AMLNN:BOOL=ON$' "${ORT_BUILD_DIR}/CMakeCache.txt" || {
  echo "Selected ONNX Runtime build does not enable AMLNN: ${ORT_BUILD_DIR}" >&2
  exit 2
}
grep -q '^AMLNN_ENABLE_CONVERTER:BOOL=ON$' "${ORT_BUILD_DIR}/CMakeCache.txt" || {
  echo "Selected ONNX Runtime build does not enable online conversion: ${ORT_BUILD_DIR}" >&2
  exit 2
}
grep -Eq '^ANDROID_ABI:[^=]+=arm64-v8a$' "${ORT_BUILD_DIR}/CMakeCache.txt" || {
  echo "Selected ONNX Runtime build is not Android arm64-v8a: ${ORT_BUILD_DIR}" >&2
  exit 2
}

mkdir -p "${OUTPUT_DIR}"
"${CXX}" \
  -std=c++17 \
  -O2 \
  -fexceptions \
  -frtti \
  -nostdlib++ \
  -stdlib=libc++ \
  -I"${REPO_ROOT}/include/onnxruntime" \
  -I"${REPO_ROOT}/include/onnxruntime/core/session" \
  "${RELEASE_DIR}/pipeline_demo/pipeline_demo.cc" \
  -L"${ORT_BUILD_DIR}" \
  -lonnxruntime \
  -lc++_shared \
  -Wl,-rpath,'$ORIGIN' \
  -o "${OUTPUT_DIR}/pipeline_demo"

cp "${ORT_BUILD_DIR}/libonnxruntime.so" "${OUTPUT_DIR}/"
echo "Output: ${OUTPUT_DIR}"
echo "ONNX Runtime build: ${ORT_BUILD_DIR}"
