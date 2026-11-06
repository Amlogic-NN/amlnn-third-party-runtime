#!/usr/bin/env bash
set -euo pipefail

: "${ANDROID_NDK_PATH:?ANDROID_NDK_PATH must be set}"
: "${ANDROID_SDK_PATH:?ANDROID_SDK_PATH must be set}"
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)"
RELEASE_DIR="${REPO_ROOT}/tools/amlnn_release"
source "${RELEASE_DIR}/common/select_vendor_sdk.sh" android 64
PARALLEL_JOBS="${PARALLEL_JOBS:-1}"
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build/AMLNN-android64}"
: "${AMLNN_NNSDK2_INCLUDE_DIR:=${REPO_ROOT}/onnxruntime/core/providers/amlnn/builder/include/sdk/include}"
: "${AMLNN_AML_COMPILER_CORE_INCLUDE_DIR:=${REPO_ROOT}/onnxruntime/core/providers/amlnn/builder/include/aml_compiler_core/include}"
[[ "${PARALLEL_JOBS}" =~ ^[1-9][0-9]*$ ]] || { echo "PARALLEL_JOBS must be a positive integer" >&2; exit 2; }
for tool in python3 cmake ninja; do
  command -v "${tool}" >/dev/null 2>&1 || { echo "Missing host tool: ${tool}" >&2; exit 2; }
done
[[ -x "${ANDROID_NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang++" ]] || {
  echo "Android NDK arm64 compiler not found under ANDROID_NDK_PATH: ${ANDROID_NDK_PATH}" >&2; exit 2;
}
[[ -d "${ANDROID_SDK_PATH}" ]] || { echo "ANDROID_SDK_PATH is not a directory: ${ANDROID_SDK_PATH}" >&2; exit 2; }
for header in \
  "${AMLNN_NNSDK2_INCLUDE_DIR}/nnsdk2.h" \
  "${AMLNN_AML_COMPILER_CORE_INCLUDE_DIR}/compiler_core_api.h" \
  "${AMLNN_AML_COMPILER_CORE_INCLUDE_DIR}/compiler_core_context.h"; do
  [[ -f "${header}" ]] || { echo "Required AMLNN header not found: ${header}" >&2; exit 2; }
done
bash "${RELEASE_DIR}/common/verify_source_tree.sh"

# A CMake build tree cannot change generators in-place. Refuse before CMake
# runs, rather than leaving users with a late and ambiguous configuration error.
if [[ -f "${BUILD_DIR}/Release/CMakeCache.txt" ]] &&
   ! grep -q '^CMAKE_GENERATOR:INTERNAL=Ninja$' "${BUILD_DIR}/Release/CMakeCache.txt"; then
  echo "Existing BUILD_DIR uses a different CMake generator: ${BUILD_DIR}" >&2
  echo "Choose a new BUILD_DIR (recommended), or remove only its CMakeCache.txt and CMakeFiles after backing it up." >&2
  exit 2
fi

cd "${REPO_ROOT}"
./build.sh --build_shared_lib --skip_tests --skip_submodule_sync --compile_no_warning_as_error --android \
  --parallel "${PARALLEL_JOBS}" --cmake_generator Ninja \
  --android_ndk_path "${ANDROID_NDK_PATH}" --android_sdk_path "${ANDROID_SDK_PATH}" \
  --android_abi arm64-v8a --android_api 21 \
  --config Release --no_kleidiai --no_sve --build_dir "${BUILD_DIR}" \
  --cmake_extra_defines onnxruntime_BUILD_UNIT_TESTS=OFF onnxruntime_USE_AMLNN=ON AMLNN_ENABLE_CONVERTER=ON \
  AMLNN_AML_COMPILER_CORE_INCLUDE_DIR="${AMLNN_AML_COMPILER_CORE_INCLUDE_DIR}" \
  AMLNN_NNSDK2_INCLUDE_DIR="${AMLNN_NNSDK2_INCLUDE_DIR}"
