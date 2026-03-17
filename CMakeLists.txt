cmake_minimum_required(VERSION 3.18)

set(CMAKE_CUDA_COMPILER "C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v12.8/bin/nvcc.exe" CACHE FILEPATH "CUDA compiler" FORCE)
set(CUDAToolkit_ROOT "C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v12.8" CACHE PATH "CUDA Toolkit root" FORCE)

project(test_cuda LANGUAGES CUDA)

set(CMAKE_CUDA_ARCHITECTURES 52 60 70 80)

set(CMAKE_CUDA_STANDARD 14)

set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -Xcompiler=-MD")

set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /MANIFEST:NO")

add_executable(test_cuda test_cuda.cu)

target_compile_options(test_cuda PRIVATE $<$<COMPILE_LANGUAGE:CUDA>:--expt-relaxed-constexpr>)
