#!/usr/bin/env python3
"""Report ONNX, optional TFLite, and AMLNN binary-output similarity metrics."""
import argparse
from pathlib import Path
import numpy as np
p=argparse.ArgumentParser(description=__doc__); p.add_argument("onnx_dir"); p.add_argument("amlnn_dir"); p.add_argument("tflite_dir", nargs="?"); a=p.parse_args()
def compare(label, first, second):
    x=np.fromfile(first, dtype=np.float32).astype(np.float64); y=np.fromfile(second, dtype=np.float32).astype(np.float64)
    if not x.size or not y.size: print(f"{label}: empty output"); return False
    if x.size != y.size: print(f"{label}: element count mismatch {x.size} vs {y.size}"); return False
    if not (np.isfinite(x).all() and np.isfinite(y).all()): print(f"{label}: non-finite output values"); return False
    denom=np.linalg.norm(x)*np.linalg.norm(y); cosine=float(np.dot(x,y)/denom) if denom else float(np.array_equal(x,y))
    print(f"{label}: max_abs_diff={np.abs(x-y).max(initial=0):.9g} relative_l2={np.linalg.norm(x-y)/(np.linalg.norm(x) or 1):.9g} cosine={cosine:.9f}"); return True
source_dir=Path(a.onnx_dir)
target_dir=Path(a.amlnn_dir)
source_files={file.name: file for file in source_dir.glob("output_*.bin")}
target_files={file.name: file for file in target_dir.glob("output_*.bin")}
if not source_files: print(f"no ONNX output files in: {source_dir}")
if source_files.keys()!=target_files.keys(): print("ONNX and AMLNN output file sets differ")
ok=bool(source_files) and source_files.keys()==target_files.keys()
tflite_files=None
if a.tflite_dir:
    tflite_files={file.name: file for file in Path(a.tflite_dir).glob("output_*.bin")}
    if source_files.keys()!=tflite_files.keys(): print("ONNX and TFLite output file sets differ"); ok=False
for name, source in sorted(source_files.items()):
    if name in target_files: ok=compare(f"{name} ONNX vs AMLNN", source, target_files[name]) and ok
    if tflite_files is not None and name in tflite_files:
        ok=compare(f"{name} ONNX vs TFLite", source, tflite_files[name]) and ok
raise SystemExit(0 if ok else 1)
