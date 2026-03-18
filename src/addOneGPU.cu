#include <cuda_runtime.h>

__global__ void addOneGPUKernel(int *a) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < N) {
        a[idx] = a[idx] + 1;
    }
}

void addOneGPU(int *a) {
    int threadsPerBlock = 256;
    int blocksPerGrid = (N + threadsPerBlock - 1) / threadsPerBlock;
    addOneGPUKernel<<<blocksPerGrid, threadsPerBlock>>>(a);
    cudaDeviceSynchronize();
}
