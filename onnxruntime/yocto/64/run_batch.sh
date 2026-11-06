#!/usr/bin/env bash
# Run one Yocto64-built demo process per ONNX model on the Armbian test board.
# Each process has its own conversion/output directory so that conversion and
# NPU resources are released before the next model starts.
set -u

RELEASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PIPELINE_DIR="${PIPELINE_DIR:-${RELEASE_DIR}/pipeline_demo/bin/yocto64}"
: "${MODEL_DIR:?MODEL_DIR must name a directory containing ONNX models}"
: "${AMLNN_RUNTIME_DIR:?AMLNN_RUNTIME_DIR must contain libaml_compiler_core.so and libcompiler_adla.so}"
OUTPUT_ROOT="${OUTPUT_ROOT:-${PWD}/amlnn_batch_yocto64}"
LOG_LEVEL="${LOG_LEVEL:-error}"
MODEL_LIST_FILE="${MODEL_LIST_FILE:-}"
# Set CLEAN_INTERMEDIATES=1 for large runs. Successful-model JSON, ADLA, and
# fingerprint artifacts are removed after their manifest row is written.
CLEAN_INTERMEDIATES="${CLEAN_INTERMEDIATES:-0}"

RUNNER="${PIPELINE_DIR}/pipeline_demo"
MANIFEST="${OUTPUT_ROOT}/manifest.tsv"
MODEL_LIST="${OUTPUT_ROOT}/models.list"

if [[ "$(uname -m)" != "aarch64" ]]; then
  echo "ERROR: this runner requires a native Linux aarch64 host; got $(uname -m)" >&2
  exit 2
fi
for file in \
  "${RUNNER}" \
  "${PIPELINE_DIR}/libonnxruntime.so" \
  "${PIPELINE_DIR}/libonnxruntime.so.1" \
  "${AMLNN_RUNTIME_DIR}/libaml_compiler_core.so" \
  "${AMLNN_RUNTIME_DIR}/libcompiler_adla.so"; do
  [[ -f "${file}" ]] || { echo "ERROR: required file not found: ${file}" >&2; exit 2; }
done
[[ -x "${RUNNER}" ]] || { echo "ERROR: runner is not executable: ${RUNNER}" >&2; exit 2; }
[[ -d "${MODEL_DIR}" ]] || { echo "ERROR: model directory not found: ${MODEL_DIR}" >&2; exit 2; }
case "${LOG_LEVEL}" in error|info|debug|0|1|2) ;; *)
  echo "ERROR: LOG_LEVEL must be error, info, debug, 0, 1, or 2" >&2; exit 2;;
esac
case "${CLEAN_INTERMEDIATES}" in 0|1) ;; *)
  echo "ERROR: CLEAN_INTERMEDIATES must be 0 or 1" >&2; exit 2;;
esac

if [[ -e "${OUTPUT_ROOT}" || -L "${OUTPUT_ROOT}" ]]; then
  echo "ERROR: refusing to reuse output root: ${OUTPUT_ROOT}" >&2
  exit 2
fi
mkdir -p "${OUTPUT_ROOT}"
export LD_LIBRARY_PATH="${PIPELINE_DIR}:${AMLNN_RUNTIME_DIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

if [[ -n "${MODEL_LIST_FILE}" ]]; then
  [[ -f "${MODEL_LIST_FILE}" ]] || {
    echo "ERROR: MODEL_LIST_FILE not found: ${MODEL_LIST_FILE}" >&2
    exit 2
  }
  # Ignore blank lines while preserving each remaining path exactly.
  while IFS= read -r model || [[ -n "${model}" ]]; do
    [[ -n "${model}" ]] && printf '%s\n' "${model}"
  done < "${MODEL_LIST_FILE}" > "${MODEL_LIST}"
else
  find "${MODEL_DIR}" -maxdepth 1 -type f -name '*.onnx' -print | sort > "${MODEL_LIST}"
fi
total=$(wc -l < "${MODEL_LIST}" | tr -d ' ')
if [[ "${total}" -eq 0 ]]; then
  echo "ERROR: no ONNX models selected" >&2
  exit 2
fi

printf 'model\tstatus\texit_code\tduration_sec\tadla_bytes\toutput_bytes\tlog\n' > "${MANIFEST}"
success=0
failed=0
index=0

while IFS= read -r model; do
  index=$((index + 1))
  name=$(basename "${model}")
  stem=${name%.onnx}
  model_output="${OUTPUT_ROOT}/${stem}"
  log="${OUTPUT_ROOT}/${stem}.log"

  mkdir -p "${model_output}"
  started=$(date +%s)
  echo "[${index}/${total}] START ${name}"

  "${RUNNER}" "${model}" "${model_output}" "${LOG_LEVEL}" > "${log}" 2>&1
  rc=$?
  ended=$(date +%s)
  duration=$((ended - started))

  adla="${model_output}/${stem}.adla"
  output_bin="${model_output}/output_0.bin"
  if [[ "${rc}" -eq 0 && -s "${adla}" && -s "${output_bin}" ]]; then
    status=SUCCESS
    success=$((success + 1))
    adla_bytes=$(wc -c < "${adla}" | tr -d ' ')
    output_bytes=$(wc -c < "${output_bin}" | tr -d ' ')
    echo "[${index}/${total}] SUCCESS ${name} ${duration}s"
  else
    status=FAILED
    failed=$((failed + 1))
    adla_bytes=0
    output_bytes=0
    echo "[${index}/${total}] FAILED ${name} rc=${rc} ${duration}s; log=${log}"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${name}" "${status}" "${rc}" "${duration}" \
    "${adla_bytes}" "${output_bytes}" "${log}" >> "${MANIFEST}"

  # Keep failed-model conversion artifacts for diagnosis. They are only
  # removed after a successful run, matching the documented cleanup contract.
  if [[ "${CLEAN_INTERMEDIATES}" == "1" && "${status}" == "SUCCESS" ]]; then
    rm -f "${model_output}"/*.json "${model_output}"/*.adla \
      "${model_output}"/*.fingerprint
    rm -f "${log}"
  fi
done < "${MODEL_LIST}"

echo
echo "Total: ${total} | Success: ${success} | Failed: ${failed}"
echo "Manifest: ${MANIFEST}"

# All selected models were attempted. Return non-zero when any model failed so
# callers and CI do not mistake a completed batch for a fully successful one.
if [[ "${failed}" -ne 0 ]]; then
  exit 1
fi
