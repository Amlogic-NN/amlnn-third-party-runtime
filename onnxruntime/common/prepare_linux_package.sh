#!/usr/bin/env bash
# Package the selected Linux/Yocto ABI; NNSDK remains provided by the target.
set -euo pipefail
[[ $# -eq 2 ]] || { echo "Usage: $0 linux|yocto 32|64" >&2; exit 2; }
platform="$1"
bits="$2"
RELEASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd -- "${RELEASE_DIR}/../.." && pwd)"
source "${RELEASE_DIR}/common/select_vendor_sdk.sh" "${platform}" "${bits}"
: "${OUTPUT_DIR:?Set OUTPUT_DIR to a new package directory outside the source tree}"
: "${PIPELINE_DEMO:?Set PIPELINE_DEMO to the executable built for this platform and ABI}"
case "${platform}:${bits}" in
  linux:32) default_build=AMLNN-buildroot32 ;;
  linux:64) default_build=AMLNN-buildroot64 ;;
  yocto:32) default_build=AMLNN-yocto32 ;;
  yocto:64) default_build=AMLNN-yocto64 ;;
  *) echo "Unsupported package target: ${platform}/${bits}" >&2; exit 2 ;;
esac
ORT_BUILD_DIR="${ORT_BUILD_DIR:-${REPO_ROOT}/build/${default_build}/Release}"
ORT_SO="${ORT_BUILD_DIR}/libonnxruntime.so"
[[ -s "${ORT_SO}" ]] || { echo "Missing ONNX Runtime library: ${ORT_SO}" >&2; exit 2; }
command -v realpath >/dev/null
command -v sha256sum >/dev/null
command -v readelf >/dev/null

expected_class=ELF64
expected_machine=AArch64
if [[ "${bits}" == 32 ]]; then
  expected_class=ELF32
  expected_machine=ARM
fi
for library in "${ORT_SO}" "${AMLNN_CORE_SO}" "${AMLNN_COMPILER_SO}"; do
  readelf -h "${library}" | grep -Eq "Class: +${expected_class}$" || {
    echo "Wrong ELF class: ${library}; expected ${expected_class}" >&2; exit 2;
  }
  readelf -h "${library}" | grep -Eq "Machine: +${expected_machine}$" || {
    echo "Wrong ELF machine: ${library}; expected ${expected_machine}" >&2; exit 2;
  }
done

output_abs="$(realpath -m -- "${OUTPUT_DIR}")"
case "${output_abs}/" in
  "${REPO_ROOT}/"*) echo "OUTPUT_DIR must be outside the source tree" >&2; exit 2 ;;
esac
[[ ! -e "${output_abs}" && ! -L "${output_abs}" ]] || {
  echo "Refusing to reuse output directory: ${output_abs}" >&2; exit 2;
}
[[ -s "${PIPELINE_DEMO}" && -x "${PIPELINE_DEMO}" ]] || {
  echo "Missing or empty executable demo: ${PIPELINE_DEMO}" >&2; exit 2;
}
readelf -h "${PIPELINE_DEMO}" | grep -Eq "Class: +${expected_class}$" || {
  echo "Wrong demo ELF class: ${PIPELINE_DEMO}; expected ${expected_class}" >&2; exit 2;
}
readelf -h "${PIPELINE_DEMO}" | grep -Eq "Machine: +${expected_machine}$" || {
  echo "Wrong demo ELF machine: ${PIPELINE_DEMO}; expected ${expected_machine}" >&2; exit 2;
}
mkdir -p -- "${output_abs}"
install -m 0644 "${ORT_SO}" "${output_abs}/libonnxruntime.so"
ln -s libonnxruntime.so "${output_abs}/libonnxruntime.so.1"
install -m 0644 "${AMLNN_CORE_SO}" "${output_abs}/libaml_compiler_core.so"
install -m 0644 "${AMLNN_COMPILER_SO}" "${output_abs}/libcompiler_adla.so"
install -m 0755 "${PIPELINE_DEMO}" "${output_abs}/pipeline_demo"
install -m 0755 "${RELEASE_DIR}/pipeline_demo/run_on_device.sh" "${output_abs}/run_demo.sh"
install -m 0755 "${RELEASE_DIR}/pipeline_demo/run_batch_linux_on_device.sh" "${output_abs}/run_batch.sh"
(
  cd "${output_abs}"
  sha256sum libonnxruntime.so libonnxruntime.so.1 libaml_compiler_core.so libcompiler_adla.so > SHA256SUMS
  sha256sum pipeline_demo run_demo.sh run_batch.sh >> SHA256SUMS
  sha256sum -c SHA256SUMS
)
echo "Package: ${output_abs} (${platform}/${bits})"
