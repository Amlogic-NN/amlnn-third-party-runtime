<p align="center">
  <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/4/43/Amlogic_logo.svg/500px-Amlogic_logo.svg.png" alt="Amlogic Logo" width="220"/>
</p>

<h1 align="center">Amlogic AI Third-Party Runtime</h1>

<p align="center">
  🧠 Efficient AI Deployment for Amlogic Embedded Platforms  
  <br>
  <a href="https://github.com/your-repo/amlogic-nn-demo"><img src="https://img.shields.io/badge/GitHub-Repository-blue?logo=github" alt="GitHub"></a>
  <a href="#"><img src="https://img.shields.io/badge/Build-Passing-brightgreen?logo=cmake" alt="Build"></a>
  <a href="#"><img src="https://img.shields.io/badge/License-Apache%202.0-yellow.svg" alt="License"></a>
  <a href="#"><img src="https://img.shields.io/badge/Platform-Yocto%20Linux-orange" alt="Platform"></a>
</p>

---

## 🧭 Introduction

Amlogic provides multiple **AI deployment solutions** that support NPU acceleration.  
In addition to the official **NNSDK** (TFLite-based), we also support popular third-party inference frameworks running efficiently on **Amlogic NPU**.

Check out the following paths to deploy your models on the NPU using your preferred framework.

👉 For official documentation and NPU support, please visit [Amlogic](https://github.com/Amlogic-NN/amlnn-model-playground).

We currently support multiple deployment paths:
- **MNN path** — Open-source inference framework developed by Alibaba.
- **ExecuTorch path** — PyTorch's end-to-end solution for enabling on-device inference capabilities.
- **ONNX Runtime path** — Cross-platform, high performance ML inferencing and training accelerator.
- **NNStreamer path** — Efficient and flexible stream pipeline for complex AI applications.

---


## ⚡ Quick Start

### 📌 1. MNN Development
To deploy models using **MNN** with NPU acceleration:
```bash
# Refer to the MNN deployment guide
```
📖 [MNN/README.md](mnn/README.md)

### 📌 2. ExecuTorch Development
To deploy models using **ExecuTorch** with NPU acceleration:
```bash
# Refer to the ExecuTorch deployment guide
```
📖 [executorch/README.md](executorch/README.md)

### 📌 3. ONNX Runtime Development
To deploy models using **ONNX Runtime** with NPU acceleration:
```bash
# Refer to the ONNX Runtime deployment guide
```
📖 [onnxruntime/README.md](onnxruntime/README.md)

### 📌 4. NNStreamer Development
To deploy models using **NNStreamer** with NPU acceleration:
```bash
# Refer to the NNStreamer deployment guide
```
📖 [nnstreamer/README.md](nnstreamer/README.md)

---

## 🧾 Typical Workflow

1. Select backend:  **MNN**, **ExecuTorch**, **ONNX Runtime**, or **NNStreamer** (NPU/CPU/GPU)
2. Convert your model (e.g., TFLite, ONNX) to supported format  
3. Push executable and model to Amlogic board  
4. Run demo to validate  
5. Integrate into your application

---

## 🙌 Acknowledgement

This project references the following open-source work:

- [MNN](https://github.com/alibaba/MNN)
- [ExecuTorch](https://github.com/pytorch/executorch)
- [ONNX Runtime](https://github.com/microsoft/onnxruntime)
- [NNStreamer](https://github.com/nnstreamer/nnstreamer)

We would like to thank the open-source community for their contributions to AI infrastructure.

---

## 📜 License

This project is released under the **Apache 2.0 License**.  
It is intended for evaluation and development purposes with **Amlogic NN SDK**.

---

<p align="center">
  Made with ❤️ for Embedded AI Development
</p>




