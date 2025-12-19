# MNNConvert

## Introduction

The model conversion tool can convert models in other formats (such as ONNX, TFLITE, TorchScript, Tensorflow, etc.) into MNN models for easy deployment on various platforms.



## Quick Start

You can used this [MNNConvert](https://github.com/Amlogic-NN/amlnn-multibackend/blob/main/MNN/TOOL/MNNConvert) for convert your model.

### requirements 

- system ：Linux x86_64 (Kernel >= 3.2)
- CPU ：x86_64

### usage

#### ONNX to MNN

```
./MNNConvert -f ONNX --modelFile mobilenetv2-12.onnx --MNNModel mobilenetv2-12.mnn --bizCode MNN
```

#### TensorFlow to MNN

```
./MNNConvert -f TF --modelFile XXX.pb --MNNModel XXX.mnn --bizCode biz
```

#### TensorFlow Lite to MNN

```
./MNNConvert -f TFLITE --modelFile XXX.tflite --MNNModel XXX.mnn --bizCode biz
```

#### Caffe to MNN

```
./MNNConvert -f CAFFE --modelFile XXX.caffemodel --prototxt XXX.prototxt --MNNModel XXX.mnn --bizCode biz
```

#### TorchScript to MNN

```
./MNNConvert -f TORCH --modelFile XXX.pt --MNNModel XXX.mnn --bizCode biz
```



## Build Your MNNConvert

If your system don't match this MNNConvert, you can build your MNNConvert from source code, please refs to https://mnn-docs.readthedocs.io/en/latest/compile/other.html#id2




