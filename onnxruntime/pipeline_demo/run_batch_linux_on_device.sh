#!/bin/sh
# Run each ONNX model in a separate process using a Linux/Yocto runtime package.
set -eu

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 MODEL_DIR NEW_OUTPUT_ROOT" >&2
  exit 2
fi
model_dir=$1
output_root=$2
package_dir=$(CDPATH= cd "$(dirname "$0")" && pwd -P)

if [ ! -d "$model_dir" ]; then
  echo "Model directory not found: $model_dir" >&2
  exit 2
fi
if [ ! -f "$package_dir/run_demo.sh" ]; then
  echo "Missing package runner: $package_dir/run_demo.sh" >&2
  exit 2
fi
if [ -e "$output_root" ]; then
  echo "Refusing to reuse output root: $output_root" >&2
  exit 2
fi
mkdir "$output_root"
manifest=$output_root/manifest.tsv
printf 'model\tstatus\texit_code\tlog\n' > "$manifest"
total=0
success=0
failed=0

for model in "$model_dir"/*.onnx; do
  [ -f "$model" ] || continue
  total=$((total + 1))
  name=$(basename "$model" .onnx)
  model_output=$output_root/$name
  model_log=$output_root/$name.log
  printf '[%s] START %s\n' "$total" "$name.onnx"
  if sh "$package_dir/run_demo.sh" "$model" "$model_output" error > "$model_log" 2>&1; then
    success=$((success + 1))
    printf '%s\tSUCCESS\t0\t%s\n' "$name.onnx" "$model_log" >> "$manifest"
    printf '[%s] SUCCESS %s\n' "$total" "$name.onnx"
  else
    rc=$?
    failed=$((failed + 1))
    printf '%s\tFAILED\t%s\t%s\n' "$name.onnx" "$rc" "$model_log" >> "$manifest"
    printf '[%s] FAILED %s rc=%s log=%s\n' "$total" "$name.onnx" "$rc" "$model_log"
  fi
done

if [ "$total" -eq 0 ]; then
  echo "No .onnx files found in: $model_dir" >&2
  exit 2
fi
printf 'Total: %s | Success: %s | Failed: %s\n' "$total" "$success" "$failed"
printf 'Manifest: %s\n' "$manifest"
[ "$failed" -eq 0 ]
