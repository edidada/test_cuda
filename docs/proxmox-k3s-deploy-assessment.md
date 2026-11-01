# test_cuda 能否部署到 r630-proxmox8 的 Proxmox / k3s —— 评估说明

采集日期 2026-11-01。评估的两个仓库：

- **本仓库（test_cuda）**：`D:\develops\git\github\cuda\test_cuda` —— CUDA 入门 Demo，CMake + `src/test_cuda.cu`，产物是**可执行文件**（不是常驻服务）。
- **目标环境（r630-proxmox8）**：`D:\develops\git\github\r630-proxmox8` —— Dell PowerEdge R630 + Proxmox VE 8.4 的运维知识库，含 5 节点 k3s 集群（VM100–104）与 GitLab/Runner/registry/Traefik CI/CD 链路。全部结论引用其仓库内实测文档，非本仓库的推断均标注。

## 结论速览

| 能力 | 结论 | 前提 |
| --- | --- | --- |
| 在 Proxmox VM/LXC 里**编译** test_cuda | ✅ 立即可行 | 不需要 GPU，照 `README.md` 装 g++-12 + CUDA toolkit 即可 |
| 在 k3s 里跑**编译 Job** | ✅ 立即可行 | 用 `nvidia/cuda:12.x-devel` 镜像起一个一次性 Job，现有集群就能跑 |
| 在 Proxmox / k3s 里**运行** test_cuda | ⚠️ 暂不可行 | 需要**物理 NVIDIA GPU + PCIe 直通 + 驱动**，目前 R630 上没有任何 GPU 配置 |
| 在 k3s 里跑**运行 Pod**（有 GPU 之后） | ✅ 可行 | nvidia runtime + device plugin，k3s 官方支持 |

一句话：**"部署编译"今天就能做，"部署运行"卡在硬件（GPU）上，不是软件问题。**

## 1. test_cuda 的硬依赖分析（本仓库事实）

`src/test_cuda.cu` 的运行时链路：

1. `cudaMallocHost` × 4（页锁定主机内存）
2. `cudaMalloc` × 3（显存分配）
3. `cudaMemcpy(H2D × 2, D2H × 1)`
4. kernel `add_gpu<<<blocksPerGrid, threadsPerBlock>>>` + `cudaDeviceSynchronize()`

以上任何一步**没有真实 NVIDIA GPU 都无法成功执行**。且代码里**没有 `cudaGetLastError` / 返回值检查**：无 GPU 时 `cudaMalloc` 返回失败、指针为无效值，程序不会报错退出，而是打印垃圾值或直接段错误——比"明确的报错"更迷惑。

**编译**则完全不需要 GPU，只依赖 nvcc + 兼容的主机编译器（`README.md` 已记录：Ubuntu 24 需 g++-12，本仓库 CI 已验证）。

架构列表 `CMakeLists.txt` 里是 `52 60 70 75 80`（Maxwell→Ampere）：

- 对 CUDA 12.0 仍可编出（sm_52 在 12.0 已弃用但保留）；
- 若目标 GPU 是二手常见的 **Tesla P40（Pascal，sm_61）**，靠已编出的 `compute_60` PTX JIT 也能跑；以后顺手加 `61/86` 更稳。

## 2. r630-proxmox8 环境的关键事实（引用该仓库实测记录）

| 事实 | 出处（r630-proxmox8 仓库内） |
| --- | --- |
| PVE 主机：R630，2× E5-2680 v3（Haswell，支持 VT-d），62 GiB，**Legacy BIOS** 启动，pve-manager 8.4 | `pve.md` |
| 5 节点 k3s（v1.35.4+k3s1），VM100–104，全部为普通 VM | `cicd/r630-vm-k3s-cluster.md` |
| 全仓库**未出现** IOMMU / vfio / passthrough / nvidia 驱动配置（关键名词仅命中 1 处 k3s-vs-rke2 对比表和 1 处 registry mirror 用到"直通"一词，与 GPU 无关） | 本文件检索过程 |
| 集群里镜像仓库未落地：`registry.192.168.31.77.nip.io` 只是镜像名的字符串，`/v2/_catalog` 实测 404 | `cicd/README.md` 第 82 行 |
| k3s 支持 GPU/Device Plugin 生态，但节点适配需自测 | `cicd/k3s-vs-k8s.md` |
| 已有"GitHub Actions 构建镜像 → tar 导入 k3s"的现成套路 | `mac12_7/2026-10-17.md`（galaxy_mall 走的这条路） |

**[推断]** 因为全仓库无一处直通/驱动配置，现网 5 个 k3s 节点均无 GPU，`kubectl describe nodes` 的可分配资源中不会有 `nvidia.com/gpu`。

## 3. Proxmox 层怎么部署

### 3.1 仅构建（不需要 GPU，今天就能做）

- 方案 A：按 `pve/lxc-ubuntu2404-dev/sop-lxc-dev-110.md` 的套路再开一个 VM/LXC，装 `gcc-12 g++-12` + CUDA 12，`README.md` 顶部的两条命令构建。
- 方案 B：不给 test_cuda 单开 VM，直接复用 k3s 集群，见第 4.1 节的编译 Job——连 PVE 这一层都不用动。

### 3.2 运行（需要硬件改造）

链路：物理 GPU → PVE 直通 → 目标 VM（或 LXC 的 `/dev/nvidia*` 共享）→ 普通执行。

- **[推断]** E5-2680 v3 支持 VT-d，Legacy BIOS 下 PVE 也能开：`/etc/default/grub` 加 `intel_iommu=on` + vfio 模块，装卡后在 PVE Web UI 把 PCI 设备直通给某个 k3s 节点 VM。
- 显卡选型（入门级二手 homelab 常规做法，本仓库无实测）：
  - **Tesla P40**：算力强、能进 k3s，但被动散热需要加风扇改造，R630 2.5 槽位问题与供电（~250W）需确认；
  - **Quadro P2000/P2200**：单槽无外接供电，R630 兼容性省心，跑本 Demo 绰绰有余。
- 注意：PVE 的 Matrox G200 要留给 PVE 自己用，不要直通给 VM（现网 PVE 控制台依赖它）。

## 4. k3s 层怎么部署

### 4.1 编译 Job（现在就能跑，无需 GPU）

给 k3s 的一次性 Job，用官方-devel 镜像对齐 CI 环境（Ubuntu 22/24 devel 自带 gcc-11/12，CUDA 12.0 兼容）：

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: test-cuda-build
  namespace: sandbox   # [建议] 复用 cicd/namespaces/ 的治理模板新开一个 ns，别用 default
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: build
          image: nvidia/cuda:12.0.1-devel-ubuntu22.04
          command: ["/bin/bash", "-c"]
          args:
            - |
              apt-get update && apt-get install -y --no-install-recommends git cmake
              git clone <本仓库地址> src && cd src
              cmake -S . -B build && cmake --build build -j
              ./bin/test_cuda || echo "无 GPU，运行失败属预期；本 Job 只验证编译"
```

**镜像现状决策点**：如果后续想把"运行镜像"推到集群内部，`registry.192.168.31.77.nip.io` 目前 404（`cicd/README.md`），要么先按 `cicd/README.md` 的阶段一落地 registry，要么直接复用 `mac12_7` 记录的"GitHub Actions 构建 → tar 导入"老套路，不用等 registry。

### 4.2 运行 Pod（拿到 GPU 之后)

前置三件事（`cicd/k3s-vs-k8s.md` 已提示节点适配需自测）：

1. 目标 k3s 节点 VM（建议 VM103/104 之一）装 NVIDIA 驱动；
2. 节点 containerd 配 nvidia runtime（`/var/lib/rancher/k3s/agent/etc/containerd/config.toml.d/` 下用 k3s 的 config 模板覆盖）；
3. 集群装 [NVIDIA device plugin](https://github.com/NVIDIA/k8s-device-plugin)，`kubectl get nodes -o json | jq '.items[].status.allocatable | select(."nvidia.com/gpu")'` 验证。

Pod 形态建议（test_cuda 是一次性压测/对比程序，不是常驻服务，用 **Job** 而不是 Deployment）：

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: test-cuda-run
  namespace: sandbox
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      nodeSelector: { agent: gpu }          # 或按实际节点标签
      runtimeClassName: nvidia
      containers:
        - name: run
          image: registry.192.168.31.77.nip.io/sandbox/test-cuda:v1
          imagePullPolicy: IfNotPresent
          # test_cuda 是一次性程序，跑完即结束，无需探针
          args: ["/app/bin/test_cuda"]
          resources:
            limits:
              nvidia.com/gpu: 1
```

镜像建议基于 `nvidia/cuda:12.0.1-runtime-ubuntu22.04` + 仅复制二进制，最终体积约 1 GlB 量级（**[推断]**，base 镜像不含编译工具链；编译用一次性 Job 做，见 4.1）。

## 5. 差距清单（从现状到"能跑"）

| # | 差距 | 层 | 当前状态 | 对应动作 |
| --- | --- | --- | --- | --- |
| 1 | 物理 GPU 缺失 | 硬件 | R630 无卡 | 加装 P40/P2200（供电/散热先核） |
| 2 | IOMMU/vfio 未配置 | PVE | Legacy BIOS + 无配置 | grub 加 `intel_iommu=on`，重建 grub |
| 3 | 直通目标 VM 无 GPU | PVE | VM100–104 均无 | PCI 直通给一个 k3s 节点 |
| 4 | k3s 节点无 nvidia runtime | k3s | 未配置 | k3s containerd 模板覆盖 |
| 5 | 无 device plugin | k3s | 未配置 | helm/kubectl apply device-plugin |
| 6 | 镜像仓库未落地（可选） | CI | registry 404 | 按 cicd/README 阶段一落地，或走 GH Actions tar 导入 |
| 7 | test_cuda 无 CUDA 错误检查 | 本仓库代码 | 无 `cudaGetLastError` | 建议补上，Pod 里失败能给明确日志 |

## 6. 建议落地顺序

1. **今天**：k3s 里按 4.1 跑一次编译 Job，验证"部署到 k3s"这条链路上所有非 GPU 环节（镜像来源、ns 治理、Job 权限、日志采集）都通。
2. **拿到 GPU 后**：PVE 配 IOMMU + 直通（在新开一台测试 VM 上先用 `nvidia-smi` 验证，别直接动 k3s 生产节点）。
3. **最后**：k3s 节点装插件 + 4.2 的运行 Pod，`kubectl logs` 里应看到 CPU/GPU 毫秒数与"加速比"输出。

## 参考

- 本仓库：`README.md`（构建与编译器兼容问题）、`project.md`（CUDA 用途背景）、`CMakeLists.txt`
- 目标环境仓库（`D:\develops\git\github\r630-proxmox8`）：`pve.md`、`cicd/README.md`、`cicd/r630-vm-k3s-cluster.md`、`cicd/k3s-vs-k8s.md`、`cicd/namespaces/`、`cicd/infra/registry.yaml`、`pve/lxc-ubuntu2404-dev/sop-lxc-dev-110.md`
- 官方：[NVIDIA device plugin](https://github.com/NVIDIA/k8s-device-plugin)、[NVIDIA CUDA Linux 安装指南](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)
