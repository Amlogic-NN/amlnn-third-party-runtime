# Amlogic ONNX Runtime

## Summary

Amlogic ONNX Runtime integrates the AMLNN Execution Provider (AMLNN EP) into
ONNX Runtime. It enables a floating-point ONNX model to be converted online to
an ADLA model and executed on the Amlogic NPU.

The deployment flow is as follows:

1. The application submits a floating-point ONNX model and input tensors to ONNX Runtime.
2. ONNX Runtime parses the model and assigns supported operators to the AMLNN EP.
3. The AMLNN EP calls Core/Compiler to convert the model to ADLA on the target device.
4. NNSDK loads the generated ADLA model and executes inference on the NPU.
5. The AMLNN EP returns the inference results to ONNX Runtime, which returns them to the application.

Online conversion and inference are both performed on the target device. The
generated ADLA file does not need to be transferred manually.

### Supported Environment

| Item | Supported configuration |
| --- | --- |
| SoC | A311Y3 |
| ONNX Runtime | 1.31.0 |
| Operating systems | Android, Buildroot, Armbian/Yocto |
| Architectures | 32-bit ARM and 64-bit AArch64 |
| NPU Driver | 2.0.0 or later |

## Quick Start

### Runtime Versions

| Component | Version | Version Confirmation |
| --- | --- | --- |
| NNSDK2 | 1.1.0 | Check the NNSDK version string in the `libnnsdk.so` installed on the target device. |
| `aml_compiler_core` | 1.0.2 | Refer to the vendor release notes. Applications can call the public `AmlCompilerCoreGetVersion()` API to query the version of the loaded library. |
| ADLA Compiler (`libcompiler_adla.so`) | 3.5.3 | The online conversion log should contain `Compiler Config: Compiler Version: 3.5.3`. |

### Quick Validation

The following native cases provide a quick verification of the 64-bit target
device runtime environment. Packages for different operating systems cannot be
used interchangeably.

#### Step 1: Download the native case

| Target System | Download |
| --- | --- |
| Android | [onnxruntime_android64.tar.gz](https://pub-8378326bd0fe4b1d9312a3847f6316a2.r2.dev/Quick_Start/DDK5.10.4.10/onnxruntime_native_case/onnxruntime_android64.tar.gz) |
| Buildroot | [onnxruntime_buildroot64.tar.gz](https://pub-8378326bd0fe4b1d9312a3847f6316a2.r2.dev/Quick_Start/DDK5.10.4.10/onnxruntime_native_case/onnxruntime_buildroot64.tar.gz) |
| Armbian/Yocto | [onnxruntime_armbian_yocto64.tar.gz](https://pub-8378326bd0fe4b1d9312a3847f6316a2.r2.dev/Quick_Start/DDK5.10.4.10/onnxruntime_native_case/onnxruntime_armbian_yocto64.tar.gz) |

#### Step 2: Run the native case

Download and extract the package for the target operating system on the
development host. Transfer the complete extracted directory to the matching
target device, and then follow the instructions in the package's `Readme.txt`.

The target device must provide a compatible `libnnsdk.so`, NPU driver, and the
required execution permissions.

The native cases above are intended for quick validation of the 64-bit runtime
path. For a 32-bit target, build and test the matching ABI package by following
the build instructions below and the complete user guide.

### Build from Source

#### Step 1: Download the source code

```bash
git clone --branch amlogic/aml-npu-support \
  https://github.com/Amlogic-NN/aml-onnxruntime.git aml-onnxruntime

export REPO_ROOT="$(cd aml-onnxruntime && pwd -P)"

git -C "$REPO_ROOT" checkout --detach \
  08a78e6581a877aeab5d7036ca6d45c9cfdefc5f

git -C "$REPO_ROOT" submodule update --init --recursive
```

#### Step 2: Download the build and deployment scripts

```bash
cd "$(dirname "$REPO_ROOT")"

git clone --branch main \
  https://github.com/Amlogic-NN/amlnn-third-party-runtime.git

(
  set -e
  test ! -e "$REPO_ROOT/tools/amlnn_release"
  test ! -L "$REPO_ROOT/tools/amlnn_release"
  cp -a amlnn-third-party-runtime/onnxruntime \
    "$REPO_ROOT/tools/amlnn_release"
  bash "$REPO_ROOT/tools/amlnn_release/common/verify_source_tree.sh"
)
```

The resulting source tree is:

```text
aml-onnxruntime/
├── build.sh
├── cmake/
├── include/
├── onnxruntime/
└── tools/
    └── amlnn_release/
        ├── android/
        │   ├── 32/
        │   └── 64/
        ├── common/
        ├── linux/
        │   ├── 32/
        │   └── 64/
        ├── pipeline_demo/
        └── yocto/
            ├── 32/
            └── 64/
```

#### Step 3: Download the AMLNN runtime libraries

The runtime package is published in the
[AMLNN runtime library directory](https://github.com/Amlogic-NN/amlnn-toolkit/tree/main/amlnn_runtime/nn_runtime).

The runtime libraries are stored with Git LFS. Install Git LFS on the
development host, initialize it, and pull the complete objects before using
the package:

```bash
cd "$(dirname "$REPO_ROOT")"

git lfs install
git clone https://github.com/Amlogic-NN/amlnn-toolkit.git
git -C amlnn-toolkit lfs pull --include='amlnn_runtime/nn_runtime/**'

export NN_RUNTIME_ROOT="$(cd amlnn-toolkit/amlnn_runtime/nn_runtime && pwd -P)"
export AMLNN_VENDOR_SDK_ROOT="$NN_RUNTIME_ROOT/aml_compiler_core"
```

The build scripts select `libaml_compiler_core.so` and
`libcompiler_adla.so` for the requested operating system and architecture from
`AMLNN_VENDOR_SDK_ROOT`. The same runtime package also provides 32-bit and
64-bit `libnnsdk.so` libraries under `nnsdk/android`,
`nnsdk/linux/buildroot`, and `nnsdk/linux/yocto`.

Use the compatible `libnnsdk.so` already installed on the target device when
available. Otherwise, the device integrator must deploy the library matching
the target operating system and architecture. Libraries from different
operating systems or architectures must not be mixed. The target device must
also provide a compatible NPU driver.

#### Step 4: Configure the cross-compilation environment

Configure the toolchain matching the target system and architecture before
running the build scripts.

| Target System | 32-bit Environment | 64-bit Environment |
| --- | --- | --- |
| Android | `ANDROID_SDK_PATH`, `ANDROID_NDK_PATH` | `ANDROID_SDK_PATH`, `ANDROID_NDK_PATH` |
| Buildroot | `BUILDROOT32_PATH` | `BUILDROOT64_PATH` |
| Armbian/Yocto | `YOCTO32_PATH` | `YOCTO64_PATH` |

For complete toolchain installation and configuration instructions, refer to
the user guides linked in the [Documentation](#documentation) section.

#### Step 5: Build, package, and run

Each target directory contains the scripts required to build the shared
library and Demo, and to prepare a target-device package.

| Target System | 32-bit Scripts | 64-bit Scripts |
| --- | --- | --- |
| Android | `android/32/` | `android/64/` |
| Buildroot | `linux/32/` | `linux/64/` |
| Armbian/Yocto | `yocto/32/` | `yocto/64/` |

The standard workflow is:

1. Run `build_so.sh` for the target system and architecture.
2. Run the corresponding Demo build script.
3. Set the variables required by the selected platform and run `prepare_package.sh`.
4. Transfer the complete package to the matching target device.
5. Verify `SHA256SUMS`, then run `run_demo.sh` with an ONNX model and a new output directory.

For Buildroot and Armbian/Yocto packaging, set `ORT_BUILD_DIR`,
`PIPELINE_DEMO`, and `OUTPUT_DIR` as shown in the user guide. `OUTPUT_DIR`
must be a new directory outside the source tree.

The exact commands differ by target toolchain. Follow the complete user guide
for the selected operating system and architecture.

## Directory Overview

| Directory | Description |
| --- | --- |
| `android/32` | Android 32-bit build, Demo, packaging, and execution scripts |
| `android/64` | Android 64-bit build, Demo, packaging, and execution scripts |
| `linux/32` | Buildroot 32-bit build, Demo, and packaging scripts |
| `linux/64` | Buildroot 64-bit build, Demo, and packaging scripts |
| `yocto/32` | Armbian/Yocto 32-bit build, Demo, and packaging scripts |
| `yocto/64` | Armbian/Yocto 64-bit build, Demo, packaging, and execution scripts |
| `common` | Shared source checks, SDK selection, reference inference, and comparison tools |
| `pipeline_demo` | C++ Demo source code and target-device execution scripts |

## Supported Models

The following ONNX models are supported by this release.

| Application category | Model family | Supported models |
| --- | --- | --- |
| Image classification and recognition | AlexNet / CaffeNet | `bvlcalexnet-7.onnx`, `caffenet-7.onnx` |
| Image classification and recognition | DenseNet / EfficientNet | `densenet-7.onnx`, `efficientnet_b0.onnx` |
| Image classification and recognition | GoogLeNet / Inception | `googlenet-7.onnx`, `inception-v1-7.onnx` |
| Image classification and recognition | MobileNet | `mobilenet_v2.onnx`, `mobilenetv2-7.onnx` |
| Image classification and recognition | ResNet | `resnet18.onnx`, `resnet18-v1-7.onnx`, `resnet18-v2-7.onnx`<br>`resnet34-v1-7.onnx`, `resnet34-v2-7.onnx`<br>`resnet50-v1-12.onnx`, `resnet50-v1-7.onnx`, `resnet50-v2-7.onnx`<br>`resnet101-v1-7.onnx`, `resnet101-v2-7.onnx`<br>`resnet152-v1-7.onnx`, `resnet152-v2-7.onnx` |
| Image classification and recognition | ShuffleNet / SqueezeNet | `shufflenet-v2-10.onnx`, `squeezenet1.0-12.onnx`, `squeezenet1.1-7.onnx` |
| Image classification and recognition | VGG | `vgg16-7.onnx`, `vgg19-7.onnx`, `vgg19-bn-7.onnx` |
| Image classification and recognition | Other | `mnist-7.onnx`, `scene-middle.onnx`, `age_googlenet.onnx`, `emotion-ferplus-7.onnx`, `edge256_ped_reid_mbv1_20200815.onnx` |
| Image segmentation | Human Segmentation | `paddle_human_seg.onnx` |
| Object detection | YOLOv2 | `yolov2-coco-9.onnx` |
| Basic operator validation | Mul | `hpmul.onnx` |

## Test Status

Shared-library compilation, Demo build, deployment packaging, online conversion, and
NPU inference workflows have been verified for the following configurations:

| Target System | 32-bit | 64-bit |
| --- | :---: | :---: |
| Android | PASS | PASS |
| Buildroot | PASS | PASS |
| Armbian/Yocto | PASS | PASS |

## Documentation

- [Chinese User Guide](./Amlogic_onnxruntime_User_Guide_CN_v0.1.pdf)
- [English User Guide](./Amlogic_onnxruntime_User_Guide_v0.1.pdf)

## Related Resources

- [ONNX Runtime source code](https://github.com/Amlogic-NN/aml-onnxruntime)
- [Build scripts and user guides](https://github.com/Amlogic-NN/amlnn-third-party-runtime/tree/main/onnxruntime)
- [AMLNN runtime libraries](https://github.com/Amlogic-NN/amlnn-toolkit/tree/main/amlnn_runtime/nn_runtime)
