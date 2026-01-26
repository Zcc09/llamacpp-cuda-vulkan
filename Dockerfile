# Base image with CUDA support
FROM nvidia/cuda:12.6.0-devel-ubuntu22.04

ARG GIT_TAG=master
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libvulkan-dev \
    vulkan-tools \
    libvulkan1 \
    mesa-vulkan-drivers \
    spirv-tools \
    && rm -rf /var/lib/apt/lists/*

# 2. Fix for missing libcuda.so.1 (Driver Stubs)
# This allows linking without a physical GPU present during build
RUN ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64/stubs:${LD_LIBRARY_PATH}"

# 3. Clone llama.cpp
WORKDIR /app
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/ggml-org/llama.cpp.git .

# 4. Build Variant A: CUDA (NVIDIA)
# We disable tests (-DGGML_BUILD_TESTS=OFF) and build only the specific targets we need.
WORKDIR /app/build-cuda
RUN cmake .. \
    -DGGML_CUDA=ON \
    -DGGML_RPC=ON \
    -DGGML_BUILD_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    && cmake --build . --config Release --target llama-server rpc-server --parallel $(nproc)

# 5. Build Variant B: Vulkan (AMD)
WORKDIR /app/build-vulkan
RUN cmake .. \
    -DGGML_VULKAN=ON \
    -DGGML_RPC=ON \
    -DGGML_BUILD_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    && cmake --build . --config Release --target llama-server rpc-server --parallel $(nproc)

# 6. Organize Binaries
WORKDIR /app
RUN mkdir -p /usr/local/bin/cuda && \
    mkdir -p /usr/local/bin/vulkan && \
    # Copy specifically the targets we built
    cp /app/build-cuda/bin/llama-server /usr/local/bin/cuda/ && \
    cp /app/build-cuda/bin/rpc-server /usr/local/bin/cuda/ && \
    cp /app/build-vulkan/bin/llama-server /usr/local/bin/vulkan/ && \
    cp /app/build-vulkan/bin/rpc-server /usr/local/bin/vulkan/

ENV PATH="/usr/local/bin/cuda:/usr/local/bin/vulkan:${PATH}"

EXPOSE 8080 50052
CMD ["/bin/bash"]

