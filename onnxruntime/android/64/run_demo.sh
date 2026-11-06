#!/usr/bin/env bash
# Deploy and execute the Android64 pipeline demo from the host with adb access.
# Vendor Core/Compiler libraries are selected from AMLNN_VENDOR_SDK_ROOT.
set -euo pipefail
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <model.onnx> <local-output-dir> [error|info|debug] [input0.bin ...]" >&2
  exit 2
fi
ONNX_MODEL="$1"; LOCAL_OUTPUT_DIR="$2"; shift 2
LOG_LEVEL=error
case "${1:-}" in
  error|info|debug|0|1|2) LOG_LEVEL="$1"; shift ;;
  warning|warn|verbose|trace|fatal)
    echo "Unsupported log level: $1. Use error, info, debug, 0, 1, or 2." >&2
    exit 2
    ;;
esac
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)"
RELEASE_DIR="${REPO_ROOT}/tools/amlnn_release"
source "${RELEASE_DIR}/common/select_vendor_sdk.sh" android 64
PACKAGE_DIR="${PACKAGE_DIR:-${RELEASE_DIR}/pipeline_demo/bin/android64}"
REMOTE_DIR="${REMOTE_DIR:-/data/local/tmp/amlnn_android64_$(date +%Y%m%d_%H%M%S)_$RANDOM}"
[[ "${REMOTE_DIR}" =~ ^/data/local/tmp/[A-Za-z0-9_-]+$ ]] || {
  echo "REMOTE_DIR must be one dedicated directory directly under /data/local/tmp (letters, digits, _ or -): ${REMOTE_DIR}" >&2
  exit 2
}
RUNNER="${PACKAGE_DIR}/pipeline_demo"; ORT_SO="${PACKAGE_DIR}/libonnxruntime.so"
DEFAULT_LIBCXX="${ANDROID_NDK_PATH:+${ANDROID_NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so}"
LIBCXX_SO="${AMLNN_LIBCXX_SO:-${DEFAULT_LIBCXX}}"
command -v adb >/dev/null || { echo 'adb not found' >&2; exit 1; }
for f in "${RUNNER}" "${ORT_SO}" "${AMLNN_CORE_SO}" "${AMLNN_COMPILER_SO}" "${LIBCXX_SO}" "${ONNX_MODEL}"; do test -f "${f}" || { echo "Missing: ${f}" >&2; exit 1; }; done
for input in "$@"; do
  [[ -f "${input}" ]] || { echo "Missing input: ${input}" >&2; exit 1; }
done
mkdir -p "${LOCAL_OUTPUT_DIR}"
adb shell "test ! -e '${REMOTE_DIR}' && mkdir -p '${REMOTE_DIR}/output'"
adb push "${RUNNER}" "${REMOTE_DIR}/pipeline_demo" >/dev/null
adb push "${ORT_SO}" "${REMOTE_DIR}/libonnxruntime.so" >/dev/null
adb push "${AMLNN_CORE_SO}" "${REMOTE_DIR}/libaml_compiler_core.so" >/dev/null
adb push "${AMLNN_COMPILER_SO}" "${REMOTE_DIR}/libcompiler_adla.so" >/dev/null
adb push "${LIBCXX_SO}" "${REMOTE_DIR}/libc++_shared.so" >/dev/null
adb push "${ONNX_MODEL}" "${REMOTE_DIR}/model.onnx" >/dev/null
remote_inputs=''
input_index=0
for input in "$@"; do
  remote_name="input_${input_index}.bin"
  adb push "${input}" "${REMOTE_DIR}/${remote_name}" >/dev/null
  remote_inputs="${remote_inputs} ${remote_name}"
  input_index=$((input_index + 1))
done
adb shell "chmod 755 '${REMOTE_DIR}/pipeline_demo'"
adb shell "cd '${REMOTE_DIR}' && export LD_LIBRARY_PATH='${REMOTE_DIR}:/vendor/lib64' && ./pipeline_demo model.onnx output '${LOG_LEVEL}'${remote_inputs}" | tee "${LOCAL_OUTPUT_DIR}/run.log"
adb pull "${REMOTE_DIR}/output/." "${LOCAL_OUTPUT_DIR}/" >/dev/null
echo "Outputs: ${LOCAL_OUTPUT_DIR}"
