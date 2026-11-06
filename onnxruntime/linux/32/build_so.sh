#!/usr/bin/env bash
set -euo pipefail

: "${BUILDROOT32_PATH:?BUILDROOT32_PATH must be set to the Buildroot toolchain directory}"
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)"
RELEASE_DIR="${REPO_ROOT}/tools/amlnn_release"
source "${RELEASE_DIR}/common/select_vendor_sdk.sh" linux 32
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build/AMLNN-buildroot32}"
PARALLEL_JOBS="${PARALLEL_JOBS:-1}"
: "${AMLNN_NNSDK2_INCLUDE_DIR:=${REPO_ROOT}/onnxruntime/core/providers/amlnn/builder/include/sdk/include}"
: "${AMLNN_AML_COMPILER_CORE_INCLUDE_DIR:=${REPO_ROOT}/onnxruntime/core/providers/amlnn/builder/include/aml_compiler_core/include}"
TOOLCHAIN_ROOT="${BUILDROOT32_PATH}"
CC="${TOOLCHAIN_ROOT}/bin/arm-none-linux-gnueabihf-gcc"
CXX="${TOOLCHAIN_ROOT}/bin/arm-none-linux-gnueabihf-g++"
SYSROOT="${TOOLCHAIN_ROOT}/arm-none-linux-gnueabihf/libc"
TOOLCHAIN_FILE="${REPO_ROOT}/cmake/linux_arm32_crosscompile_toolchain.cmake"
for item in "${CC}" "${CXX}" "${TOOLCHAIN_FILE}" "${AMLNN_NNSDK2_INCLUDE_DIR}/nnsdk2.h" "${AMLNN_AML_COMPILER_CORE_INCLUDE_DIR}/compiler_core_api.h"; do test -e "${item}" || { echo "Missing: ${item}" >&2; exit 1; }; done
test -d "${SYSROOT}" || { echo "Missing: ${SYSROOT}" >&2; exit 1; }
# The repository's CMake toolchain file names the cross compilers without
# absolute paths. Make those names resolvable during CMake configuration.
export PATH="${TOOLCHAIN_ROOT}/bin:${PATH}"
bash "${RELEASE_DIR}/common/verify_source_tree.sh"
cd "${REPO_ROOT}"
./build.sh --build_shared_lib --skip_tests --skip_submodule_sync --compile_no_warning_as_error --config Release \
  --parallel "${PARALLEL_JOBS}" --no_kleidiai --no_sve --build_dir "${BUILD_DIR}" --cmake_extra_defines \
  onnxruntime_AMLNN_ALLOW_GCC_10=ON onnxruntime_BUILD_UNIT_TESTS=OFF onnxruntime_USE_AMLNN=ON AMLNN_ENABLE_CONVERTER=ON \
  CMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" CMAKE_SYSTEM_PROCESSOR=armv7l CMAKE_C_COMPILER="${CC}" \
  CMAKE_CXX_COMPILER="${CXX}" CMAKE_SYSROOT="${SYSROOT}" AMLNN_NNSDK2_INCLUDE_DIR="${AMLNN_NNSDK2_INCLUDE_DIR}" \
  AMLNN_AML_COMPILER_CORE_INCLUDE_DIR="${AMLNN_AML_COMPILER_CORE_INCLUDE_DIR}"
