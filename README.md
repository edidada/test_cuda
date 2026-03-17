# 使用 CMake 组织 CUDA 代码（含 macOS 无原生 CUDA 情况）

## 本地环境
- macOS 无法原生安装最新 CUDA 工具链（NVIDIA 已停止对 macOS 的支持）。如需 nvcc 编译，请使用容器方式。

## 本机直接构建（无 CUDA）
```
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```
说明：无 CUDA 环境将自动构建 CPU stub，仅用于验证工程可编译。

## 使用容器中的 nvcc 编译
前置：安装 Docker Desktop 或 Podman（建议结合 Colima）。

执行脚本（拉取 nvidia/cuda:12.x-devel 镜像，在容器内运行 cmake 与 nvcc）：
```
./tools/build_with_nvcc_docker.sh
```
可选参数：
- CUDA_IMAGE 指定镜像（默认 nvidia/cuda:12.3.2-devel-ubuntu22.04）
- BUILD_DIR 指定构建目录（默认 build-nvcc）

示例：
```
CUDA_IMAGE=nvidia/cuda:12.4.1-devel-ubuntu22.04 BUILD_DIR=out-nvcc ./tools/build_with_nvcc_docker.sh
```

该方式仅编译，不运行程序。
