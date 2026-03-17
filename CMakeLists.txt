cmake_minimum_required(VERSION 3.18)


project(test_cuda LANGUAGES CUDA)

set(CMAKE_CUDA_ARCHITECTURES 52 60 70 75 80)

set(CMAKE_CUDA_STANDARD 14)

set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -Xcompiler=-MD")


add_executable(test_cuda test_cuda.cu)

target_compile_options(test_cuda PRIVATE $<$<COMPILE_LANGUAGE:CUDA>:--expt-relaxed-constexpr>)
