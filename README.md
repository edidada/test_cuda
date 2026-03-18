cmake -S . -B build -DCMAKE_CUDA_HOST_COMPILER=/usr/bin/g++-12
cmake --build build -j

test_cuda 构建问题说明：GitHub Actions 可编译，WSL2 Ubuntu 24 不行？

概览
- 现象：GitHub Actions（Ubuntu 24）可以编译，本地 WSL2 Ubuntu 24 编译失败。
- 结论：失败的根因是“主机编译器版本与 nvcc（CUDA 12.0）不兼容”。WSL2 环境中 GCC 为 13.3，Clang 为 18，均超出 CUDA 12.0 的支持范围；CI 环境使用了兼容的工具链（例如安装了 gcc-12 或使用了匹配的 CUDA 容器/镜像），因此可以通过。

错误要点（复现摘要）
- nvcc 12.0 检测不到受支持的 gcc/g++：
  - ERROR: No supported gcc/g++ host compiler found
- 指定 clang++ 后仍失败，头文件明确限制：
  - unsupported clang version! clang version must be less than 15
- 伴随 libstdc++ 14 相关解析错误，进一步佐证了主机编译器版本不匹配。

仓库中的构建入口
- CMake 列表：[CMakeLists.txt](file:///mnt/d/develops/git/github/cuda/test_cuda/CMakeLists.txt) 使用 CUDA 语言，生成可执行文件 test_cuda。失败发生在 CMake 探测 CUDA/主机编译器阶段，并非项目代码逻辑问题。

可行修复方案（四选一，按推荐顺序）
1) 安装受支持的 GCC 并指给 nvcc（推荐）
- 安装 gcc-12/g++-12（Ubuntu 24.04）：

```bash
sudo apt update
sudo apt install gcc-12 g++-12
```

- 配置并指定主机编译器：

```bash
cmake -S . -B build -DCMAKE_CUDA_HOST_COMPILER=/usr/bin/g++-12
cmake --build build -j
```

- 或通过 nvcc 的 -ccbin（经由 CMake 传递）：

```bash
cmake -S . -B build -DCMAKE_CUDA_FLAGS="-ccbin=/usr/bin/g++-12"
cmake --build build -j
```

2) 升级 CUDA 工具链到与 Ubuntu 24 匹配的版本（同样推荐）
- 选择 CUDA 12.4/12.5/12.6（对 GCC 13 支持更好），流程要点：
  - 卸载 Ubuntu 源中的 nvidia-cuda-toolkit（避免老版本工具链）。
  - 按 NVIDIA 官方文档添加其 apt 仓库并安装新版 CUDA。
  - 再次执行 CMake 配置与构建。
- 兼容矩阵与 NVCC_CCBIN 等配置方法详见 NVIDIA 官方安装指南（见文末参考）。

3) 使用较低版本的 Clang（仅在愿意安装 clang-14/16 时）
- 安装后在 CMake 中指定：

```bash
cmake -S . -B build -DCMAKE_CUDA_HOST_COMPILER=/usr/bin/clang++-14
cmake --build build -j
```

- 注意：需与所装 CUDA 版本的“clang 支持上限”匹配，否则仍会在 host_config.h 阶段失败。

4) 临时绕过版本检查（不推荐长期使用）
- 仅放行版本检查，实际编译仍可能失败：

```bash
cmake -S . -B build -DCMAKE_CUDA_FLAGS="--allow-unsupported-compiler"
cmake --build build -j
```

建议落地选择
- 最稳妥做法：安装 g++-12 并通过 CMAKE_CUDA_HOST_COMPILER 指定；或升级 CUDA 到 12.4+ 与 Ubuntu 24 的 GCC 13 匹配。
- 若 CI 使用 nvidia/cuda 官方镜像（如 12.x devel ubuntu24.04），建议本地使用相同镜像（Docker on WSL2）对齐环境，减少差异。

环境差异自检清单
- 本地检查：

```bash
nvcc --version
gcc --version
clang --version
cmake --version
```

- WSL2 当前观测版本（示例）：
  - nvcc：12.0.140
  - gcc/g++：13.3.0
  - clang：18.1.3
- 若与 CI 不一致，请按上文四种方案之一处理。

附：常用命令示例

```bash
# 方案1：使用 g++-12 作为 CUDA 主机编译器
rm -rf build
cmake -S . -B build -DCMAKE_CUDA_HOST_COMPILER=/usr/bin/g++-12
cmake --build build -j

# 方案2：升级 CUDA 后的常规构建
rm -rf build
cmake -S . -B build
cmake --build build -j
```

参考
- NVIDIA CUDA Linux 安装指南（包含主机编译器支持范围与 NVCC_CCBIN 配置）：
  - https://docs.nvidia.com/cuda/cuda-installation-guide-linux/

