#!/usr/bin/env bash
# Prepare a private Android armeabi-v7a pipeline_demo deployment package.
set -euo pipefail

: "${OUTPUT_DIR:?Set OUTPUT_DIR to a new deployment-package directory}"

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)"
RELEASE_DIR="${REPO_ROOT}/tools/amlnn_release"
source "${RELEASE_DIR}/common/select_vendor_sdk.sh" android 32
PACKAGE_DIR="${PACKAGE_DIR:-${RELEASE_DIR}/pipeline_demo/bin/android32}"
DEFAULT_LIBCXX="${ANDROID_NDK_PATH:+${ANDROID_NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/libc++_shared.so}"
LIBCXX_SO="${AMLNN_LIBCXX_SO:-${DEFAULT_LIBCXX}}"

command -v realpath >/dev/null 2>&1 || { echo "Missing host tool: realpath" >&2; exit 2; }
command -v sha256sum >/dev/null 2>&1 || { echo "Missing host tool: sha256sum" >&2; exit 2; }
command -v readelf >/dev/null 2>&1 || { echo "Missing host tool: readelf" >&2; exit 2; }
OUTPUT_ABS="$(realpath -m -- "${OUTPUT_DIR}")"
case "${OUTPUT_ABS}/" in
  "${REPO_ROOT}/"*)
    echo "OUTPUT_DIR must be outside the source tree because the package contains vendor binaries: ${OUTPUT_ABS}" >&2
    exit 2
    ;;
esac
[[ ! -e "${OUTPUT_ABS}" && ! -L "${OUTPUT_ABS}" ]] || {
  echo "Refusing to overwrite existing OUTPUT_DIR: ${OUTPUT_ABS}" >&2
  exit 2
}

for binary in \
  "${PACKAGE_DIR}/pipeline_demo" \
  "${PACKAGE_DIR}/libonnxruntime.so" \
  "${AMLNN_CORE_SO}" \
  "${AMLNN_COMPILER_SO}" \
  "${LIBCXX_SO}"; do
  [[ -s "${binary}" ]] || { echo "Missing or empty binary: ${binary}" >&2; exit 2; }
  readelf -h "${binary}" | grep -Eq 'Class:[[:space:]]+ELF32' || {
    echo "Expected a 32-bit ELF binary: ${binary}" >&2; exit 2;
  }
  readelf -h "${binary}" | grep -Eq 'Machine:[[:space:]]+ARM' || {
    echo "Expected an ARM ELF binary: ${binary}" >&2; exit 2;
  }
done
[[ -f "${RELEASE_DIR}/pipeline_demo/run_batch_on_device.sh" ]] || {
  echo "Missing device batch script" >&2; exit 2;
}
[[ -f "${RELEASE_DIR}/pipeline_demo/run_on_device.sh" ]] || {
  echo "Missing device single-model script" >&2; exit 2;
}

mkdir -p -- "${OUTPUT_ABS}"
install -m 0755 "${PACKAGE_DIR}/pipeline_demo" "${OUTPUT_ABS}/pipeline_demo"
install -m 0644 "${PACKAGE_DIR}/libonnxruntime.so" "${OUTPUT_ABS}/libonnxruntime.so"
install -m 0644 "${AMLNN_CORE_SO}" "${OUTPUT_ABS}/libaml_compiler_core.so"
install -m 0644 "${AMLNN_COMPILER_SO}" "${OUTPUT_ABS}/libcompiler_adla.so"
install -m 0644 "${LIBCXX_SO}" "${OUTPUT_ABS}/libc++_shared.so"
install -m 0755 "${RELEASE_DIR}/pipeline_demo/run_on_device.sh" "${OUTPUT_ABS}/run_demo.sh"
install -m 0755 "${RELEASE_DIR}/pipeline_demo/run_batch_on_device.sh" "${OUTPUT_ABS}/run_batch_on_device.sh"
(
  cd "${OUTPUT_ABS}"
  sha256sum \
    pipeline_demo \
    libonnxruntime.so \
    libaml_compiler_core.so \
    libcompiler_adla.so \
    libc++_shared.so \
    run_demo.sh \
    run_batch_on_device.sh \
    > SHA256SUMS
  sha256sum -c SHA256SUMS
)

echo "Output: ${OUTPUT_ABS}"
echo "Contents: pipeline_demo, libonnxruntime.so, libaml_compiler_core.so, libcompiler_adla.so, libc++_shared.so, run_demo.sh, run_batch_on_device.sh, SHA256SUMS"
