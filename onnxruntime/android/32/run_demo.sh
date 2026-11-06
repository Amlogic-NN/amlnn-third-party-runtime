#!/usr/bin/env bash
# Run the Android32 demo from the host that has adb access to the device.
set -euo pipefail
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 MODEL.onnx LOCAL_OUTPUT_DIR [error|info|debug] [input0.bin ...]" >&2
  exit 2
fi
model="$1"
local_output="$2"
shift 2
log_level=error
case "${1:-}" in error|info|debug|0|1|2) log_level="$1"; shift ;; esac
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)"
release_dir="${repo_root}/tools/amlnn_release"
source "${release_dir}/common/select_vendor_sdk.sh" android 32
package_dir="${PACKAGE_DIR:-${release_dir}/pipeline_demo/bin/android32}"
remote_dir="${REMOTE_DIR:-/data/local/tmp/amlnn_android32_$(date +%Y%m%d_%H%M%S)_$RANDOM}"
[[ "${remote_dir}" =~ ^/data/local/tmp/[A-Za-z0-9_-]+$ ]] || {
  echo "REMOTE_DIR must be a dedicated directory under /data/local/tmp" >&2; exit 2;
}
libcxx="${AMLNN_LIBCXX_SO:-${ANDROID_NDK_PATH:?}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/libc++_shared.so}"
command -v adb >/dev/null
for item in "${model}" "${package_dir}/pipeline_demo" "${package_dir}/libonnxruntime.so" \
  "${AMLNN_CORE_SO}" "${AMLNN_COMPILER_SO}" "${libcxx}"; do
  [[ -f "${item}" ]] || { echo "Missing: ${item}" >&2; exit 2; }
done
for input in "$@"; do [[ -f "${input}" ]] || { echo "Missing input: ${input}" >&2; exit 2; }; done
adb shell "test ! -e '${remote_dir}' && mkdir -p '${remote_dir}/output'"
adb push "${package_dir}/pipeline_demo" "${remote_dir}/pipeline_demo" >/dev/null
adb push "${package_dir}/libonnxruntime.so" "${remote_dir}/libonnxruntime.so" >/dev/null
adb push "${AMLNN_CORE_SO}" "${remote_dir}/libaml_compiler_core.so" >/dev/null
adb push "${AMLNN_COMPILER_SO}" "${remote_dir}/libcompiler_adla.so" >/dev/null
adb push "${libcxx}" "${remote_dir}/libc++_shared.so" >/dev/null
adb push "${model}" "${remote_dir}/model.onnx" >/dev/null
remote_inputs=''
i=0
for input in "$@"; do
  name="input_${i}.bin"
  adb push "${input}" "${remote_dir}/${name}" >/dev/null
  remote_inputs="${remote_inputs} ${name}"
  i=$((i + 1))
done
mkdir -p -- "${local_output}"
adb shell "chmod 755 '${remote_dir}/pipeline_demo'"
adb shell "cd '${remote_dir}' && LD_LIBRARY_PATH='${remote_dir}:/vendor/lib' ./pipeline_demo model.onnx output '${log_level}'${remote_inputs}" | tee "${local_output}/run.log"
adb pull "${remote_dir}/output/." "${local_output}/" >/dev/null
echo "Outputs: ${local_output}"
