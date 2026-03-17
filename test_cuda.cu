#include <cuda_runtime.h>
#include <stdio.h>

__global__ void hello_cuda_kernel() {
    printf("Hello from GPU thread %d\n", threadIdx.x);
}

int main() {
    printf("CUDA Test Program\n");
    
    hello_cuda_kernel<<<1, 5>>>();
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) {
        printf("CUDA error: %s\n", cudaGetErrorString(err));
        return -1;
    }
    
    cudaDeviceSynchronize();
    
    return 0;
}
