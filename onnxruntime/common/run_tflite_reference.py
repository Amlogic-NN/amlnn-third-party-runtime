#!/usr/bin/env python3
"""Run a TFLite model with LiteRT; inputs and outputs use NCHW binary files."""
import argparse, json
from pathlib import Path
import numpy as np
try:
    from ai_edge_litert.interpreter import Interpreter
except ImportError as exc:
    raise SystemExit("Install ai-edge-litert to use this tool") from exc

def nchw(shape): return [shape[0], shape[3], shape[1], shape[2]] if len(shape) == 4 else list(shape)
p = argparse.ArgumentParser(description=__doc__); p.add_argument("model"); p.add_argument("inputs", nargs="+"); p.add_argument("--output-dir", required=True); a = p.parse_args()
i = Interpreter(model_path=a.model); i.allocate_tensors(); ins=i.get_input_details(); outs=i.get_output_details()
if len(ins) != len(a.inputs): raise SystemExit("input-file count does not match model")
for detail, filename in zip(ins, a.inputs):
    shape=nchw([int(x) for x in detail["shape"]]); value=np.fromfile(filename, dtype=detail["dtype"]).reshape(shape)
    i.set_tensor(detail["index"], np.transpose(value, (0,2,3,1)) if value.ndim == 4 else value)
i.invoke(); out=Path(a.output_dir)
if out.exists(): raise SystemExit(f"refusing to reuse output directory: {out}")
out.mkdir(parents=True)
for index, detail in enumerate(outs):
    value=i.get_tensor(detail["index"]); value=np.transpose(value, (0,3,1,2)) if value.ndim == 4 else value
    value.tofile(out / f"output_{index}.bin"); (out / f"output_{index}.meta").write_text(json.dumps({"name":detail.get("name", f"output_{index}"),"dtype":str(value.dtype),"shape":list(value.shape),"elements":int(value.size)})+"\n")
