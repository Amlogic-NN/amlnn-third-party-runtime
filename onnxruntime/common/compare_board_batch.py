#!/usr/bin/env python3
"""Compare successful AMLNN batch outputs with host CPU ONNX Runtime.

The device batch runner uses zero-filled input tensors when no explicit input
files are supplied. This tool uses the same contract and records metrics; it
does not declare an accuracy pass/fail threshold.
"""
from __future__ import annotations
import argparse, csv
from pathlib import Path
import numpy as np
import onnxruntime as ort

TYPE = {"tensor(float)":np.float32,"tensor(double)":np.float64,"tensor(float16)":np.float16,
        "tensor(uint8)":np.uint8,"tensor(int8)":np.int8,"tensor(uint16)":np.uint16,
        "tensor(int16)":np.int16,"tensor(uint32)":np.uint32,"tensor(int32)":np.int32,
        "tensor(uint64)":np.uint64,"tensor(int64)":np.int64,"tensor(bool)":np.bool_}
def cpu(model):
    session=ort.InferenceSession(str(model), providers=["CPUExecutionProvider"]); feeds={}
    for item in session.get_inputs():
        shape=tuple(d if isinstance(d,int) and d>0 else 1 for d in item.shape)
        if item.type not in TYPE: raise ValueError(f"unsupported input type: {item.type}")
        feeds[item.name]=np.zeros(shape, dtype=TYPE[item.type])
    return session.run(None, feeds)
def metrics(x,y):
    x=np.asarray(x,dtype=np.float64).reshape(-1); y=np.asarray(y,dtype=np.float64).reshape(-1)
    if x.size != y.size: raise ValueError(f"element count mismatch CPU={x.size}, NPU={y.size}")
    if not x.size: raise ValueError("cannot compare an empty output tensor")
    if not (np.isfinite(x).all() and np.isfinite(y).all()): raise ValueError("non-finite output values")
    d=np.abs(x-y); nx=np.linalg.norm(x); ny=np.linalg.norm(y)
    return d.max(initial=0.0),d.mean() if d.size else 0.0,np.linalg.norm(x-y)/(nx or 1.0),(np.dot(x,y)/(nx*ny) if nx and ny else float(np.array_equal(x,y)))
p=argparse.ArgumentParser(description=__doc__); p.add_argument('--manifest',type=Path,required=True); p.add_argument('--model-dir',type=Path,required=True); p.add_argument('--batch-dir',type=Path,required=True); p.add_argument('--report',type=Path,required=True); a=p.parse_args()
with a.manifest.open(encoding='utf-8', newline='') as f: rows=list(csv.DictReader(f,delimiter='\t'))
fields=['model','status','outputs','max_abs_diff','mean_abs_diff','max_relative_l2','min_cosine_or_equal_rate','error']; a.report.parent.mkdir(parents=True,exist_ok=True); failures=compared=0
with a.report.open('w',encoding='utf-8',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=fields,delimiter='\t'); writer.writeheader()
    for row in rows:
        if row.get('status')!='SUCCESS': continue
        record={'model':row['model'],'status':'ERROR','outputs':0,'error':''}
        try:
            reference=cpu(a.model_dir/row['model'])
            if not reference: raise ValueError("CPU model has no outputs")
            output_dir=a.batch_dir/Path(row['model']).stem
            outputs=[output_dir/f"output_{i}.bin" for i in range(len(reference))]
            actual=set(output_dir.glob('output_*.bin'))
            if actual!=set(outputs): raise ValueError(f"output file mismatch CPU={len(reference)}, NPU={len(actual)}")
            if any(np.asarray(x).dtype!=np.float32 for x in reference): raise ValueError("comparison requires float32 outputs")
            values=[metrics(x,np.fromfile(y,dtype=np.float32)) for x,y in zip(reference,outputs)]
            record.update(status='METRICS',outputs=len(values),max_abs_diff=max(v[0] for v in values),mean_abs_diff=max(v[1] for v in values),max_relative_l2=max(v[2] for v in values),min_cosine_or_equal_rate=min(v[3] for v in values)); compared+=1
        except Exception as exc: record['error']=str(exc); failures+=1
        writer.writerow(record)
print(f"Compared: {compared} | Compare failures: {failures}\nReport: {a.report}")
if not compared: print("No successful models were compared")
raise SystemExit(1 if failures or not compared else 0)
