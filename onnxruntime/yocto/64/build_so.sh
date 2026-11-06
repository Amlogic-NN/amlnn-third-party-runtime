#!/usr/bin/env bash
# Cross-build ONNX Runtime with AMLNN EP using the vendor Yocto64 SDK.
set -euo pipefail

: "${YOCTO64_PATH:?YOCTO64_PATH must name the installed Yocto64 SDK directory}"
[[ -z "${LD_LIBRARY_PATH:-}" ]] || {
  echo "Unset LD_LIBRARY_PATH before loading the Yocto SDK" >&2
  exit 2
}

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)"
source "${REPO_ROOT}/tools/amlnn_release/common/select_vendor_sdk.sh" yocto 64
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build/AMLNN-yocto64}"
PARALLEL_JOBS="${PARALLEL_JOBS:-1}"
[[ "${PARALLEL_JOBS}" =~ ^[1-9][0-9]*$ ]] || {
  echo "PARALLEL_JOBS must be a positive integer" >&2
  exit 2
}

# Resolve host tools before the SDK changes PATH.
: "${AMLNN_HOST_PYTHON:=$(command -v python3)}"
: "${AMLNN_HOST_CMAKE:=$(command -v cmake)}"
test -x "${AMLNN_HOST_PYTHON}"
test -x "${AMLNN_HOST_CMAKE}"
HOST_CMAKE_VERSION="$("${AMLNN_HOST_CMAKE}" --version | awk 'NR == 1 {print $3}')"
if ! printf '%s\n%s\n' '3.28' "${HOST_CMAKE_VERSION}" | sort -V -C; then
  echo "CMake 3.28 or newer is required: ${AMLNN_HOST_CMAKE} is ${HOST_CMAKE_VERSION}" >&2
  exit 2
fi

SDK_ROOT="$(cd -- "${YOCTO64_PATH}" && pwd)"
ENV_SETUP="${SDK_ROOT}/environment-setup-armv8a-poky-linux"
TOOLCHAIN="${SDK_ROOT}/sysroots/x86_64-pokysdk-linux/usr/share/cmake/OEToolchainConfig.cmake"
test -f "${ENV_SETUP}"
test -f "${TOOLCHAIN}"
if grep -qF '/usr/local/oe-sdk-hardcoded-buildpath' "${ENV_SETUP}"; then
  echo "Yocto64 SDK was not fully relocated: ${ENV_SETUP}" >&2
  exit 2
fi
# shellcheck disable=SC1090
source "${ENV_SETUP}"
: "${SDKTARGETSYSROOT:?Yocto64 SDK did not set SDKTARGETSYSROOT}"
: "${STRIP:?Yocto64 SDK did not set STRIP}"
TARGET_STRIP="${STRIP%% *}"
test -d "${SDKTARGETSYSROOT}"
command -v "${CXX%% *}" >/dev/null
command -v "${TARGET_STRIP}" >/dev/null
command -v ninja >/dev/null
command -v file >/dev/null
command -v readelf >/dev/null

: "${AMLNN_NNSDK2_INCLUDE_DIR:=${REPO_ROOT}/onnxruntime/core/providers/amlnn/builder/include/sdk/include}"
: "${AMLNN_AML_COMPILER_CORE_INCLUDE_DIR:=${REPO_ROOT}/onnxruntime/core/providers/amlnn/builder/include/aml_compiler_core/include}"
test -f "${AMLNN_NNSDK2_INCLUDE_DIR}/nnsdk2.h"
test -f "${AMLNN_AML_COMPILER_CORE_INCLUDE_DIR}/compiler_core_api.h"
test -f "${AMLNN_AML_COMPILER_CORE_INCLUDE_DIR}/compiler_core_context.h"
bash "${REPO_ROOT}/tools/amlnn_release/common/verify_source_tree.sh"

if [[ -f "${BUILD_DIR}/Release/CMakeCache.txt" ]]; then
  grep -q '^onnxruntime_USE_AMLNN:BOOL=ON$' "${BUILD_DIR}/Release/CMakeCache.txt" || {
    echo "Existing BUILD_DIR is not an AMLNN build: ${BUILD_DIR}" >&2
    exit 2
  }
  grep -q '^CMAKE_GENERATOR:INTERNAL=Ninja$' "${BUILD_DIR}/Release/CMakeCache.txt" || {
    echo "Existing BUILD_DIR uses a different CMake generator: ${BUILD_DIR}" >&2
    exit 2
  }
fi

args=(
  --build_shared_lib
  --skip_tests
  --skip_submodule_sync
  --compile_no_warning_as_error
  --config Release
  --parallel "${PARALLEL_JOBS}"
  --no_kleidiai
  --no_sve
  --cmake_generator Ninja
  --cmake_path "${AMLNN_HOST_CMAKE}"
  --build_dir "${BUILD_DIR}"
  --cmake_extra_defines
  onnxruntime_BUILD_UNIT_TESTS=OFF
  onnxruntime_USE_AMLNN=ON
  AMLNN_ENABLE_CONVERTER=ON
  CMAKE_TOOLCHAIN_FILE="${TOOLCHAIN}"
  CMAKE_SYSTEM_PROCESSOR=aarch64
  AMLNN_NNSDK2_INCLUDE_DIR="${AMLNN_NNSDK2_INCLUDE_DIR}"
  AMLNN_AML_COMPILER_CORE_INCLUDE_DIR="${AMLNN_AML_COMPILER_CORE_INCLUDE_DIR}"
)
if [[ -n "${CMAKE_DEPS_MIRROR_DIR:-}" ]]; then
  test -d "${CMAKE_DEPS_MIRROR_DIR}"
  args+=(--cmake_deps_mirror_dir "${CMAKE_DEPS_MIRROR_DIR}")
fi
if [[ "${EUID}" -eq 0 ]]; then
  args+=(--allow_running_as_root)
fi

cd "${REPO_ROOT}"
"${AMLNN_HOST_PYTHON}" tools/ci_build/build.py "${args[@]}"
test -s "${BUILD_DIR}/Release/libonnxruntime.so"
LIBRARY_PATH="$(readlink -f "${BUILD_DIR}/Release/libonnxruntime.so")"
test -s "${LIBRARY_PATH}"
"${TARGET_STRIP}" --strip-unneeded "${LIBRARY_PATH}"
if file "${LIBRARY_PATH}" | grep -q 'with debug_info'; then
  echo "Release library still contains debug information: ${LIBRARY_PATH}" >&2
  exit 1
fi
readelf -Ws "${LIBRARY_PATH}" |
  grep 'OrtSessionOptionsAppendExecutionProvider_Amlnn' >/dev/null
echo "Output: ${BUILD_DIR}/Release/libonnxruntime.so"
