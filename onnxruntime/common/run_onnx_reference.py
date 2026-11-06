#!/usr/bin/env python3
"""Run an ONNX model on host CPU with binary input files and save outputs."""
import argparse, json
from pathlib import Path
import numpy as np
import onnxruntime as ort

DTYPES = {"tensor(float)": np.float32, "tensor(double)": np.float64, "tensor(float16)": np.float16,
          "tensor(int8)": np.int8, "tensor(uint8)": np.uint8, "tensor(int16)": np.int16,
          "tensor(uint16)": np.uint16, "tensor(int32)": np.int32, "tensor(uint32)": np.uint32,
          "tensor(int64)": np.int64, "tensor(uint64)": np.uint64, "tensor(bool)": np.bool_}
p = argparse.ArgumentParser(description=__doc__); p.add_argument("model"); p.add_argument("inputs", nargs="+"); p.add_argument("--output-dir", required=True); a = p.parse_args()
s = ort.InferenceSession(a.model, providers=["CPUExecutionProvider"])
if len(a.inputs) != len(s.get_inputs()): raise SystemExit("input-file count does not match model")
feed = {}
for info, filename in zip(s.get_inputs(), a.inputs):
    dtype = DTYPES.get(info.type)
    if dtype is None: raise SystemExit(f"unsupported input type: {info.name} {info.type}")
    data = np.fromfile(filename, dtype=dtype)
    shape = tuple(d if isinstance(d, int) and d > 0 else 1 for d in info.shape)
    if data.size != int(np.prod(shape)): raise SystemExit(f"input size mismatch: {filename}")
    feed[info.name] = data.reshape(shape)
out = Path(a.output_dir)
if out.exists(): raise SystemExit(f"refusing to reuse output directory: {out}")
out.mkdir(parents=True)
for i, (info, value) in enumerate(zip(s.get_outputs(), s.run(None, feed))):
    value = np.asarray(value); value.tofile(out / f"output_{i}.bin")
    (out / f"output_{i}.meta").write_text(json.dumps({"name": info.name, "dtype": str(value.dtype), "shape": list(value.shape), "elements": int(value.size)}) + "\n")
    print(f"output_{i}: {info.name} {list(value.shape)} {value.dtype}")
