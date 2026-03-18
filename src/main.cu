#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>
#include "cuda_utils.h"

int main() {
    int *d_a, *h_a;
    size_t size = N * sizeof(int);

    h_a = (int*)malloc(size);
    cudaMalloc(&d_a, size);

    for (int i = 0; i < N; i++) {
        h_a[i] = i;
    }

    cudaMemcpy(d_a, h_a, size, cudaMemcpyHostToDevice);

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);
    addOneGPU(d_a);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float gpuTime;
    cudaEventElapsedTime(&gpuTime, start, stop);

    printf("GPU time: %.3f ms\n", gpuTime);

    cudaEventRecord(start);
    addOneCPU(h_a);
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float cpuTime;
    cudaEventElapsedTime(&cpuTime, start, stop);

    printf("CPU time: %.3f ms\n", cpuTime);
    printf("Speedup: %.2fx\n", cpuTime / gpuTime);

    free(h_a);
    cudaFree(d_a);
    cudaEventDestroy(start);
    cudaEventDestroy(stop);

    return 0;
}
