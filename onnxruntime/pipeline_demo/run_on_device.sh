#!/bin/sh
# Run one ONNX model from a complete Android, Linux/Buildroot, or Yocto package.
set -eu

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 MODEL.onnx NEW_OUTPUT_DIR [error|info|debug] [INPUT_0.bin ...]" >&2
  exit 2
fi
model=$1
output_dir=$2
shift 2
log_level=error
case "${1:-}" in
  error|info|debug|0|1|2) log_level=$1; shift ;;
  warning|warn|verbose|trace|fatal)
    echo "Unsupported log level: $1" >&2
    exit 2 ;;
esac

package_dir=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
: "${NNSDK_LIB_DIR:?Set NNSDK_LIB_DIR to the target directory containing libnnsdk.so}"
for required in \
  "$package_dir/pipeline_demo" \
  "$package_dir/libonnxruntime.so" \
  "$package_dir/libaml_compiler_core.so" \
  "$package_dir/libcompiler_adla.so" \
  "$NNSDK_LIB_DIR/libnnsdk.so" \
  "$model"; do
  if [ ! -s "$required" ]; then
    echo "Missing or empty: $required" >&2
    exit 2
  fi
done
if [ -e "$package_dir/libonnxruntime.so.1" ] && [ ! -s "$package_dir/libonnxruntime.so.1" ]; then
  echo "Invalid ONNX Runtime SONAME link" >&2
  exit 2
fi
if [ -e "$package_dir/libc++_shared.so" ] && [ ! -s "$package_dir/libc++_shared.so" ]; then
  echo "Invalid Android C++ runtime library" >&2
  exit 2
fi
if [ ! -x "$package_dir/pipeline_demo" ]; then
  echo "Not executable: $package_dir/pipeline_demo" >&2
  exit 2
fi
for input do
  if [ ! -f "$input" ]; then
    echo "Missing input: $input" >&2
    exit 2
  fi
done
if [ -e "$output_dir" ]; then
  echo "Refusing to reuse output directory: $output_dir" >&2
  exit 2
fi
mkdir "$output_dir"
unset AMLNN_MODEL_PATH
export LD_LIBRARY_PATH="$package_dir:$NNSDK_LIB_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$package_dir/pipeline_demo" "$model" "$output_dir" "$log_level" "$@"

model_stem=$(basename "${model%.onnx}")
if [ ! -s "$output_dir/$model_stem.adla" ] || [ ! -s "$output_dir/output_0.bin" ] || [ ! -s "$output_dir/output_0.meta" ]; then
  echo "Inference returned without the expected ADLA and output files: $output_dir" >&2
  exit 1
fi
echo "Online conversion and NPU inference: PASS"
echo "Output: $output_dir"
