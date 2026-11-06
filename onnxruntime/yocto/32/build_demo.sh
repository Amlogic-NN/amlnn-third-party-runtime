#!/usr/bin/env bash
# Cross-build pipeline_demo with the installed Yocto32 SDK environment.
set -euo pipefail
: "${YOCTO32_PATH:?Set YOCTO32_PATH to the installed Yocto32 SDK}"
[[ -z "${LD_LIBRARY_PATH:-}" ]] || { echo "Unset LD_LIBRARY_PATH before loading the Yocto SDK" >&2; exit 2; }

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)"
release_dir="${repo_root}/tools/amlnn_release"
build_dir="${BUILD_DIR:-${repo_root}/build/AMLNN-yocto32}"
ort_build_dir="${ORT_BUILD_DIR:-${build_dir}/Release}"
output_dir="${OUTPUT_DIR:-${release_dir}/pipeline_demo/bin/yocto32}"
env_setup="${YOCTO32_PATH}/environment-setup-armv7at2hf-neon-poky-linux-gnueabi"
[[ -f "${env_setup}" ]] || { echo "Yocto32 SDK environment not found: ${env_setup}" >&2; exit 2; }
if grep -qF '/usr/local/oe-sdk-hardcoded-buildpath' "${env_setup}"; then
  echo "Yocto32 SDK was not fully relocated: ${env_setup}" >&2
  exit 2
fi
# The vendor SDK's CXX/CXXFLAGS/LDFLAGS contain target-specific options.
# shellcheck disable=SC1090
source "${env_setup}"
: "${CXX:?Yocto32 SDK did not set CXX}"
read -r -a cxx_cmd <<< "${CXX}"
read -r -a cxx_flags <<< "${CXXFLAGS:-}"
read -r -a ld_flags <<< "${LDFLAGS:-}"
command -v "${cxx_cmd[0]}" >/dev/null

ort_so="${ort_build_dir}/libonnxruntime.so"
cache="${ort_build_dir}/CMakeCache.txt"
[[ -s "${ort_so}" && -f "${cache}" ]] || { echo "Missing Yocto32 ORT build: ${ort_build_dir}" >&2; exit 2; }
grep -q '^onnxruntime_USE_AMLNN:BOOL=ON$' "${cache}"
grep -q '^AMLNN_ENABLE_CONVERTER:BOOL=ON$' "${cache}"
readelf -h "${ort_so}" | grep -Eq 'Class: +ELF32$'
readelf -h "${ort_so}" | grep -Eq 'Machine: +ARM$'

mkdir -p -- "${output_dir}"
"${cxx_cmd[@]}" "${cxx_flags[@]}" -std=c++17 -O2 -fexceptions -frtti \
  -I"${repo_root}/include/onnxruntime" \
  -I"${repo_root}/include/onnxruntime/core/session" \
  "${release_dir}/pipeline_demo/pipeline_demo.cc" \
  -L"${ort_build_dir}" -Wl,-rpath-link,"${ort_build_dir}" \
  -lonnxruntime "${ld_flags[@]}" -Wl,-rpath,'$ORIGIN' \
  -o "${output_dir}/pipeline_demo"
readelf -h "${output_dir}/pipeline_demo" | grep -Eq 'Class: +ELF32$'
readelf -h "${output_dir}/pipeline_demo" | grep -Eq 'Machine: +ARM$'
echo "Output: ${output_dir}/pipeline_demo"
echo "ONNX Runtime build: ${ort_build_dir}"
