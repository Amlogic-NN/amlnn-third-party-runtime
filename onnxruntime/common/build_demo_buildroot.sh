#!/usr/bin/env bash
# Cross-build pipeline_demo for a Buildroot-compatible Linux target.
set -euo pipefail

[[ $# -eq 1 ]] || { echo "Usage: $0 32|64" >&2; exit 2; }
bits="$1"
case "${bits}" in
  32)
    : "${BUILDROOT32_PATH:?Set BUILDROOT32_PATH to the extracted ARMv7 GNU toolchain}"
    toolchain_root="${BUILDROOT32_PATH}"
    cxx="${toolchain_root}/bin/arm-none-linux-gnueabihf-g++"
    default_build=AMLNN-buildroot32
    expected_class=ELF32
    expected_machine=ARM
    ;;
  64)
    : "${BUILDROOT64_PATH:?Set BUILDROOT64_PATH to the extracted AArch64 GNU toolchain}"
    toolchain_root="${BUILDROOT64_PATH}"
    cxx="${toolchain_root}/bin/aarch64-none-linux-gnu-g++"
    default_build=AMLNN-buildroot64
    expected_class=ELF64
    expected_machine=AArch64
    ;;
  *) echo "Unsupported bit width: ${bits}" >&2; exit 2 ;;
esac

release_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(cd -- "${release_dir}/../.." && pwd)"
build_dir="${BUILD_DIR:-${repo_root}/build/${default_build}}"
ort_build_dir="${ORT_BUILD_DIR:-${build_dir}/Release}"
output_dir="${OUTPUT_DIR:-${release_dir}/pipeline_demo/bin/linux${bits}}"
ort_so="${ort_build_dir}/libonnxruntime.so"
cache="${ort_build_dir}/CMakeCache.txt"

[[ -x "${cxx}" ]] || { echo "Cross compiler not found: ${cxx}" >&2; exit 2; }
[[ -s "${ort_so}" && -f "${cache}" ]] || { echo "Missing Buildroot ORT build: ${ort_build_dir}" >&2; exit 2; }
grep -q '^onnxruntime_USE_AMLNN:BOOL=ON$' "${cache}"
grep -q '^AMLNN_ENABLE_CONVERTER:BOOL=ON$' "${cache}"
readelf -h "${ort_so}" | grep -Eq "Class: +${expected_class}$"
readelf -h "${ort_so}" | grep -Eq "Machine: +${expected_machine}$"

mkdir -p -- "${output_dir}"
"${cxx}" -std=c++17 -O2 -fexceptions -frtti \
  -I"${repo_root}/include/onnxruntime" \
  -I"${repo_root}/include/onnxruntime/core/session" \
  "${release_dir}/pipeline_demo/pipeline_demo.cc" \
  -L"${ort_build_dir}" -Wl,-rpath-link,"${ort_build_dir}" \
  -lonnxruntime -Wl,-rpath,'$ORIGIN' \
  -o "${output_dir}/pipeline_demo"
readelf -h "${output_dir}/pipeline_demo" | grep -Eq "Class: +${expected_class}$"
readelf -h "${output_dir}/pipeline_demo" | grep -Eq "Machine: +${expected_machine}$"
echo "Output: ${output_dir}/pipeline_demo"
echo "ONNX Runtime build: ${ort_build_dir}"
