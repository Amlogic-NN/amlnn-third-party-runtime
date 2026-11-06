#!/system/bin/sh
# Run online ONNX -> ADLA -> NNSDK inference for every ONNX file on an
# Android device. The runner and all shared libraries must already be in
# PIPELINE_DIR, which must be on an executable filesystem such as /data.

PIPELINE_DIR="${PIPELINE_DIR:-$(CDPATH= cd "$(dirname "$0")" && pwd -P)}"
: "${MODEL_DIR:?Set MODEL_DIR to the target directory containing ONNX models}"
: "${OUTPUT_ROOT:?Set OUTPUT_ROOT to a new directory for batch results}"
LOG_LEVEL="${LOG_LEVEL:-error}"
# Use the target's own NNSDK directory: /vendor/lib for 32-bit Android,
# /vendor/lib64 for 64-bit Android. VENDOR_LIB_DIR remains a compatibility alias.
VENDOR_LIB_DIR="${NNSDK_LIB_DIR:-${VENDOR_LIB_DIR:-}}"
: "${VENDOR_LIB_DIR:?Set NNSDK_LIB_DIR to the target directory containing libnnsdk.so}"
# Set CLEAN_INTERMEDIATES=1 for large batch runs. This preserves inference
# outputs and failure logs while removing large conversion artifacts after
# each successful model.
CLEAN_INTERMEDIATES="${CLEAN_INTERMEDIATES:-0}"

case "${CLEAN_INTERMEDIATES}" in
  0|1) ;;
  *) echo "ERROR: CLEAN_INTERMEDIATES must be 0 or 1" >&2; exit 2 ;;
esac

case "${LOG_LEVEL}" in
  error|info|debug|0|1|2) ;;
  *)
    echo "ERROR: unsupported LOG_LEVEL: ${LOG_LEVEL}. Use error, info, debug, 0, 1, or 2." >&2
    exit 2
    ;;
esac

RUNNER="${PIPELINE_DIR}/pipeline_demo"
MANIFEST="${OUTPUT_ROOT}/manifest.tsv"
MODEL_LIST="${OUTPUT_ROOT}/models.list"

if [ ! -x "${RUNNER}" ]; then
  echo "ERROR: runner is not executable: ${RUNNER}" >&2
  exit 2
fi
if [ ! -d "${MODEL_DIR}" ]; then
  echo "ERROR: model directory not found: ${MODEL_DIR}" >&2
  exit 2
fi
if [ ! -d "${VENDOR_LIB_DIR}" ]; then
  echo "ERROR: vendor library directory not found: ${VENDOR_LIB_DIR}" >&2
  exit 2
fi
if [ ! -s "${VENDOR_LIB_DIR}/libnnsdk.so" ]; then
  echo "ERROR: target NNSDK library not found: ${VENDOR_LIB_DIR}/libnnsdk.so" >&2
  exit 2
fi

if [ -e "${OUTPUT_ROOT}" ]; then
  echo "ERROR: refusing to reuse output root: ${OUTPUT_ROOT}" >&2
  exit 2
fi
mkdir "${OUTPUT_ROOT}"
export LD_LIBRARY_PATH="${PIPELINE_DIR}:${VENDOR_LIB_DIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

find "${MODEL_DIR}" -maxdepth 1 -type f -name '*.onnx' | sort > "${MODEL_LIST}"
total=$(wc -l < "${MODEL_LIST}" | tr -d ' ')
if [ "${total}" -eq 0 ]; then
  echo "ERROR: no ONNX models found in ${MODEL_DIR}" >&2
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
  if [ "${rc}" -eq 0 ] && [ -s "${adla}" ] && [ -s "${output_bin}" ]; then
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
  if [ "${CLEAN_INTERMEDIATES}" = "1" ] && [ "${status}" = "SUCCESS" ]; then
    rm -f "${model_output}"/*.json "${model_output}"/*.adla \
      "${model_output}"/*.fingerprint
    rm -f "${log}"
  fi
done < "${MODEL_LIST}"

echo ""
echo "Total: ${total} | Success: ${success} | Failed: ${failed}"
echo "Manifest: ${MANIFEST}"

# All selected models were attempted. Return non-zero when any model failed so
# callers and CI do not mistake a completed batch for a fully successful one.
if [ "${failed}" -ne 0 ]; then
  exit 1
fi
