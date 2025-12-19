<p align="center">
  <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/4/43/Amlogic_logo.svg/500px-Amlogic_logo.svg.png" alt="Amlogic Logo" width="220"/>
</p>

<h1 align="center">Amlogic AI Software Development Kit</h1>

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

Amlogic provides multiple **AI deployment solutions** that support NPU, CPU, and GPU.  
If your board supports **NPU**, you can directly use **NNSDK** for optimal performance.  
If your board does not have an NPU, you can still deploy models on **CPU** or **GPU** with ease.

👉 For official documentation and NPU support, please visit [Amlogic](https://www.amlogic.cn/).

We currently support two deployment paths:
- **NNSDK path** — TensorFlow Lite–based deployment solution developed by Amlogic.  
- **MNN path** — Open-source inference framework developed by Alibaba.

---

## 🏗️ Architecture Overview

### 🧠 NNSDK Path

<p align="center">
  <img src="https://github.com/user-attachments/assets/2e01e9f5-9ff6-4ec1-8b78-533aba7a7c02" width="300" alt="NNSDK Architecture"/>
  <br>
  <em>Figure 1. Amlogic NNSDK deployment flow</em>
</p>

---

### 🧠 MNN Path

<p align="center">
  <img src="https://github.com/user-attachments/assets/6fdf8ec0-f610-4e15-84b9-2ae6b09300c3" width="800" alt="MNN Architecture"/>
  <br>
  <em>Figure 2. MNN deployment flow</em>
</p>

---

## ⚡ Quick Start

### 📌 1. NNSDK Development

If your board does not support NPU and you choose **NNSDK** for development:  
```bash
# Refer to the official NNSDK documentation
```
📖 [NNSDK/README.md](https://github.com/Amlogic-NN/amlnn-multibackend/blob/main/NNSDK/README.md)

---

### 📌 2. MNN Development

If your board does not support NPU or you prefer the **MNN** backend:  
```bash
# Refer to the MNN deployment guide
```
📖 [MNN/README.md](https://github.com/Amlogic-NN/amlnn-multibackend/blob/main/MNN/README.md)

---

## 🧾 Typical Workflow

1. Select backend: **NNSDK** (NPU/CPU/GPU) or **MNN** (CPU/GPU)  
2. Convert your model (e.g., TFLite, ONNX) to supported format  
3. Push executable and model to Amlogic board  
4. Run demo to validate  
5. Integrate into your application

---

## 🙌 Acknowledgement

This project references the following open-source work:

- [MNN](https://github.com/alibaba/MNN)

We would like to thank the MNN team for their contributions to open-source AI infrastructure.

---

## 📜 License

This project is released under the **Apache 2.0 License**.  
It is intended for evaluation and development purposes with **Amlogic NN SDK**.

---

<p align="center">
  Made with ❤️ for Embedded AI Development
</p>



