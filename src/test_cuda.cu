#include <cuda_runtime.h>
#include <stdio.h>
#include <chrono>

#define N 10000000

__global__ void add_gpu(int* a, int* b, int* c) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < N) {
        c[idx] = a[idx] + b[idx];
    }
}

void add_cpu(int* a, int* b, int* c) {
    for (int i = 0; i < N; i++) {
        c[i] = a[i] + b[i];
    }
}

int main() {
    int *a, *b, *c, *d;
    int *d_a, *d_b, *d_c;
    
    size_t size = N * sizeof(int);
    
    cudaMallocHost(&a, size);
    cudaMallocHost(&b, size);
    cudaMallocHost(&c, size);
    cudaMallocHost(&d, size);
    
    cudaMalloc(&d_a, size);
    cudaMalloc(&d_b, size);
    cudaMalloc(&d_c, size);
    
    for (int i = 0; i < N; i++) {
        a[i] = i;
        b[i] = i * 2;
    }
    
    auto start_cpu = std::chrono::high_resolution_clock::now();
    add_cpu(a, b, c);
    auto end_cpu = std::chrono::high_resolution_clock::now();
    double cpu_time = std::chrono::duration<double, std::milli>(end_cpu - start_cpu).count();
    
    cudaMemcpy(d_a, a, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, b, size, cudaMemcpyHostToDevice);
    
    int threadsPerBlock = 256;
    int blocksPerGrid = (N + threadsPerBlock - 1) / threadsPerBlock;
    
    auto start_gpu = std::chrono::high_resolution_clock::now();
    add_gpu<<<blocksPerGrid, threadsPerBlock>>>(d_a, d_b, d_c);
    cudaDeviceSynchronize();
    auto end_gpu = std::chrono::high_resolution_clock::now();
    double gpu_time = std::chrono::duration<double, std::milli>(end_gpu - start_gpu).count();
    
    cudaMemcpy(d, d_c, size, cudaMemcpyDeviceToHost);
    
    printf("CUDA 性能对比测试\n");
    printf("==================\n");
    printf("数据量: %d 个整数\n", N);
    printf("任务: 数组加法 (c[i] = a[i] + b[i])\n\n");
    
    printf("CPU 执行时间: %.3f 毫秒\n", cpu_time);
    printf("GPU 执行时间: %.3f 毫秒\n", gpu_time);
    printf("加速比: %.1f 倍\n", cpu_time / gpu_time);
    
    bool correct = true;
    for (int i = 0; i < N; i++) {
        if (c[i] != d[i]) {
            correct = false;
            break;
        }
    }
    
    printf("\n结果验证: %s\n", correct ? "✓ CPU 和 GPU 结果一致" : "✗ 结果不一致");
    
    cudaFreeHost(a);
    cudaFreeHost(b);
    cudaFreeHost(c);
    cudaFreeHost(d);
    cudaFree(d_a);
    cudaFree(d_b);
    cudaFree(d_c);
    
    return 0;
}
