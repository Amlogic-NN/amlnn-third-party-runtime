#!/usr/bin/env bash
# Source with PLATFORM (android|linux|yocto) and BITS (32|64).
# The SDK is supplied by the customer; no vendor binaries are published here.
[[ $# -eq 2 ]] || { echo "Usage: source select_vendor_sdk.sh PLATFORM BITS" >&2; return 2; }
: "${AMLNN_VENDOR_SDK_ROOT:?Set AMLNN_VENDOR_SDK_ROOT to the aml_compiler_core SDK root}"

case "$1:$2" in
  android:32) sdk_abi=armeabi-v7a ;;
  android:64) sdk_abi=arm64-v8a ;;
  linux:32|yocto:32) sdk_abi=armv7 ;;
  linux:64|yocto:64) sdk_abi=aarch64 ;;
  *) echo "Unsupported vendor SDK target: $1/$2" >&2; return 2 ;;
esac

AMLNN_AML_COMPILER_CORE_INCLUDE_DIR="${AMLNN_VENDOR_SDK_ROOT}/include"
AMLNN_CORE_SO="${AMLNN_VENDOR_SDK_ROOT}/libs/$1/${sdk_abi}/libaml_compiler_core.so"
# The public nn_runtime SDK keeps both libraries in the same ABI directory.
# Retain support for SDKs that place Compiler under third_party/.
AMLNN_COMPILER_SO="${AMLNN_VENDOR_SDK_ROOT}/libs/$1/${sdk_abi}/libcompiler_adla.so"
if [[ ! -s "${AMLNN_COMPILER_SO}" ]]; then
  AMLNN_COMPILER_SO="${AMLNN_VENDOR_SDK_ROOT}/third_party/compiler_adla/libs/$1/${sdk_abi}/libcompiler_adla.so"
fi
for sdk_file in \
  "${AMLNN_AML_COMPILER_CORE_INCLUDE_DIR}/compiler_core_api.h" \
  "${AMLNN_AML_COMPILER_CORE_INCLUDE_DIR}/compiler_core_context.h" \
  "${AMLNN_CORE_SO}" "${AMLNN_COMPILER_SO}"; do
  [[ -s "${sdk_file}" ]] || { echo "Missing or empty vendor SDK file: ${sdk_file}" >&2; return 2; }
done

command -v readelf >/dev/null 2>&1 || {
  echo "Missing host tool: readelf" >&2; return 2;
}
expected_class=ELF64
expected_machine=AArch64
if [[ "$2" == 32 ]]; then
  expected_class=ELF32
  expected_machine=ARM
fi
for sdk_file in "${AMLNN_CORE_SO}" "${AMLNN_COMPILER_SO}"; do
  readelf -h "${sdk_file}" | grep -Eq "Class:[[:space:]]*${expected_class}$" || {
    echo "Wrong ELF class: ${sdk_file}; expected ${expected_class}" >&2; return 2;
  }
  readelf -h "${sdk_file}" | grep -Eq "Machine:[[:space:]]*${expected_machine}$" || {
    echo "Wrong ELF machine: ${sdk_file}; expected ${expected_machine}" >&2; return 2;
  }
done

export AMLNN_AML_COMPILER_CORE_INCLUDE_DIR AMLNN_CORE_SO AMLNN_COMPILER_SO
printf 'Vendor SDK: %s/%s (%s)\nCore: %s\nCompiler: %s\n' \
  "$1" "$2" "${sdk_abi}" "${AMLNN_CORE_SO}" "${AMLNN_COMPILER_SO}"
unset sdk_abi sdk_file expected_class expected_machine
