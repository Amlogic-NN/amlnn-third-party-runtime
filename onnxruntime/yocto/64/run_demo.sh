#!/usr/bin/env bash
# Run the Yocto64-built demo on the Armbian aarch64 test board.
set -euo pipefail

RELEASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PIPELINE_DIR="${PIPELINE_DIR:-${RELEASE_DIR}/pipeline_demo/bin/yocto64}"
AMLNN_RUNTIME_DIR="${AMLNN_RUNTIME_DIR:?AMLNN_RUNTIME_DIR must contain libaml_compiler_core.so and libcompiler_adla.so}"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 MODEL.onnx OUTPUT_DIR [LOG_LEVEL] [INPUT_0.bin ...]" >&2
  exit 2
fi

MODEL_PATH="$1"
OUTPUT_DIR="$2"
case "${3:-}" in
  warning|warn|verbose|trace|fatal)
    echo "Unsupported LOG_LEVEL: $3. Use error, info, debug, 0, 1, or 2." >&2
    exit 2
    ;;
esac
[[ -f "${MODEL_PATH}" ]] || { echo "Model not found: ${MODEL_PATH}" >&2; exit 1; }
if [[ -e "${OUTPUT_DIR}" || -L "${OUTPUT_DIR}" ]]; then
  echo "Refusing to reuse output directory: ${OUTPUT_DIR}" >&2
  exit 2
fi
mkdir -p "${OUTPUT_DIR}"

[[ -x "${PIPELINE_DIR}/pipeline_demo" ]] || {
  echo "Pipeline demo not found: ${PIPELINE_DIR}/pipeline_demo" >&2
  exit 1
}
[[ -f "${AMLNN_RUNTIME_DIR}/libaml_compiler_core.so" ]] || {
  echo "Missing: ${AMLNN_RUNTIME_DIR}/libaml_compiler_core.so" >&2
  exit 1
}
[[ -f "${AMLNN_RUNTIME_DIR}/libcompiler_adla.so" ]] || {
  echo "Missing: ${AMLNN_RUNTIME_DIR}/libcompiler_adla.so" >&2
  exit 1
}

export LD_LIBRARY_PATH="${PIPELINE_DIR}:${AMLNN_RUNTIME_DIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
exec "${PIPELINE_DIR}/pipeline_demo" "$@"
