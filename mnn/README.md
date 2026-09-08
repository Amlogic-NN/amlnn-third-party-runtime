## 🏗️ Architecture Overview

### 🧠 MNN Path

<p align="center">
  <img src="https://github.com/user-attachments/assets/6fdf8ec0-f610-4e15-84b9-2ae6b09300c3" width="800" alt="MNN Architecture"/>
  <br>
  <em>Figure 2. MNN deployment flow</em>
</p>

## 🚀 MNN environment setup (32-bit Board Example)

### 1. Download MNN
```sh
git clone https://github.com/alibaba/MNN.git
cd MNN
git checkout 3.2.4
```

### 2. Apply Amlogic Patch
​```sh
<copy aml_mnn_mali_gpu.patch to MNN Path>
patch -p1 < aml_mnn_mali_gpu.patch
```

### 3.  Build MNN
#### 3.1 Get Toolchain (eg. YOCTO)

```sh
#32 bit toolchain
mkdir toolchain;
cd toolchain;
<copy poky-glibc-x86_64-amlogic-bsp-armv7at2hf-neon-mesons7-bh201-5.15-a32-toolchain-4.0.20.sh to MNN/toolchain>
fakeroot ./poky-glibc-x86_64-amlogic-bsp-armv7at2hf-neon-mesons7-bh201-5.15-a32-toolchain-4.0.20.sh
```

#### 3.2 build MNN

```sh
source <PATH OF MNN>/toolchain/environment-setup-armv7at2hf-neon-pokymllib32-linux-gnueabi
 
export OECORE_TARGET_ARCH=armv7-a
export CXXFLAGS=$(echo "$CXXFLAGS" | sed 's/-g//g')
export CFLAGS=$(echo "$CXXFLAGS" | sed 's/-g//g')
 
mkdir build_yocto_32 && cd build_yocto_32
 
cmake .. \
-DCMAKE_TOOLCHAIN_FILE=${OE_CMAKE_TOOLCHAIN_FILE} \
-DCMAKE_BUILD_TYPE=Release \
-DMNN_USE_LOGCAT=false \
-DMNN_USE_SSE=OFF \
-DMNN_BUILD_TEST=ON \
-DMNN_ARM82=ON \
-DMNN_BUILD_BENCHMARK=true \
-DMNN_VULKAN=ON \
-DMNN_OPENCL=ON \
-DMNN_SUPPORT_BF16=ON \
-DMNN_LOW_MEMORY=ON \
-DMNN_SEP_BUILD=OFF \
-DNATIVE_LIBRARY_OUTPUT=. -DNATIVE_INCLUDE_OUTPUT=.
 
make -j16
```

### 4. Demo
After compilation, the generated files **libMNN.so, timeProfile. out, benchmark. out**, etc. can be obtained from the compilation directory.
#### 4.1 Run Demo
```sh
./timeProfile.out mobilenetv2-12.mnn 100 7 1x3x224x224 1 0
Use extra forward type: 7
inputDims: 1 3 224 224
Set ThreadNumber = 1
Use precision type: 0
cpuIds:
Open Model mobilenetv2-12.mnn
CPU Group: [ 0  1  2  3 ], 500000 - 2004000
The device supports: i8sdot:1, fp16:1, i8mm: 1, sve2: 1, sme2: 0
Sort by node name !
Node Name                               Op Type                 Avg(ms)         %               Flops Rate
339                                     BinaryOp                0.001440        2.083115        0.023833
356                                     BinaryOp                0.000940        1.359811        0.007944
365                                     BinaryOp                0.000910        1.316413        0.007944
382                                     BinaryOp                0.000850        1.229616        0.003972
391                                     BinaryOp                0.000830        1.200684        0.003972
400                                     BinaryOp                0.000750        1.084955        0.003972
417                                     BinaryOp                0.000760        1.099421        0.005958
426                                     BinaryOp                0.000870        1.258548        0.005958
443                                     BinaryOp                0.000580        0.839032        0.002483
452                                     BinaryOp                0.000800        1.157286        0.002483
464_raster_0                            Pooling                 0.000800        1.157286        0.000000
474                                     Convolution             0.001650        2.386903        3.598591
474_raster_0                            Raster                  0.003680        5.323514        0.063553
477                                     ConvolutionDepthwise    0.001660        2.401369        1.199530
480                                     Convolution             0.000830        1.200684        2.132499
483                                     Convolution             0.001240        1.793793        6.397495
486                                     ConvolutionDepthwise    0.001310        1.895056        0.899648
489                                     Convolution             0.001410        2.039717        2.399061
492                                     Convolution             0.001000        1.446608        3.598591
495                                     ConvolutionDepthwise    0.001250        1.808260        1.349473
498                                     Convolution             0.000810        1.171752        3.598591
501                                     Convolution             0.001090        1.576802        3.598591
504                                     ConvolutionDepthwise    0.001030        1.490006        0.337368
507                                     Convolution             0.001020        1.475540        1.199530
510                                     Convolution             0.000930        1.345345        1.599374
513                                     ConvolutionDepthwise    0.000840        1.215150        0.449824
516                                     Convolution             0.000690        0.998159        1.599374
519                                     Convolution             0.001520        2.198843        1.599374
522                                     ConvolutionDepthwise    0.000940        1.359811        0.449824
525                                     Convolution             0.001150        1.663599        1.599374
528                                     Convolution             0.000900        1.301947        1.599374
531                                     ConvolutionDepthwise    0.001260        1.822726        0.112456
534                                     Convolution             0.000990        1.432141        0.799687
537                                     Convolution             0.000830        1.200684        1.599374
540                                     ConvolutionDepthwise    0.001280        1.851657        0.224912
543                                     Convolution             0.000890        1.287481        1.599374
546                                     Convolution             0.000700        1.012625        1.599374
549                                     ConvolutionDepthwise    0.001090        1.576802        0.224912
552                                     Convolution             0.000820        1.186218        1.599374
555                                     Convolution             0.001040        1.504472        1.599374
558                                     ConvolutionDepthwise    0.000840        1.215150        0.224912
561                                     Convolution             0.000860        1.244082        1.599374
564                                     Convolution             0.001000        1.446608        1.599374
567                                     ConvolutionDepthwise    0.001070        1.547870        0.224912
570                                     Convolution             0.000830        1.200684        2.399061
573                                     Convolution             0.000820        1.186218        3.598591
576                                     ConvolutionDepthwise    0.001190        1.721463        0.337368
579                                     Convolution             0.000790        1.142820        3.598591
582                                     Convolution             0.001000        1.446608        3.598591
585                                     ConvolutionDepthwise    0.001110        1.605734        0.337368
588                                     Convolution             0.000830        1.200684        3.598591
591                                     Convolution             0.000980        1.417675        3.598591
594                                     ConvolutionDepthwise    0.000970        1.403209        0.084342
597                                     Convolution             0.000590        0.853498        1.499413
600                                     Convolution             0.000880        1.273015        2.499025
603                                     ConvolutionDepthwise    0.001230        1.779328        0.140570
606                                     Convolution             0.000700        1.012625        2.499025
609                                     Convolution             0.000990        1.432142        2.499025
612                                     ConvolutionDepthwise    0.000960        1.388743        0.140570
615                                     Convolution             0.001020        1.475540        2.499025
618                                     Convolution             0.000840        1.215150        2.499025
621                                     ConvolutionDepthwise    0.001190        1.721464        0.140570
624                                     Convolution             0.000720        1.041557        4.998049
627                                     Convolution             0.001140        1.649133        6.664062
output__matmul_converted                Convolution             0.001040        1.504472        0.425003
output__matmul_converted_raster_0       Raster                  0.001320        1.909522        0.000405
output_raster_0                         Raster                  0.000840        1.215150        0.000317
Print <=20 slowest Op for Convolution, larger than 3.00
 
Sort by time cost !
Node Type               Avg(ms)         %               Called times    Flops Rate
Pooling                 0.000800        1.157286        1.000000        0.000000
Raster                  0.005840        8.448174        3.000000        0.064275
BinaryOp                0.008730        12.628778       10.000000       0.068519
ConvolutionDepthwise    0.019220        27.804119       17.000000       6.878554
Convolution             0.034540        49.965141       36.000000       92.988518
total time : 0.069127 ms, total mflops : 301.173798
main, 171, cost time: 2921.684082 ms
```


