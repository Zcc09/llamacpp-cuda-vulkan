# Base image with CUDA support
FROM nvidia/cuda:12.6.0-devel-ubuntu22.04

# Argument for the specific llama.cpp tag to build (default to master if not specified)
ARG GIT_TAG=master

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    libvulkan-dev \
    vulkan-tools \
    libvulkan1 \
    mesa-vulkan-drivers \
    spirv-tools \
    && rm -rf /var/lib/apt/lists/*

# 2. Clone specific version of llama.cpp
WORKDIR /app
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/ggml-org/llama.cpp.git .

# 3. Build Variant A: CUDA (NVIDIA)
WORKDIR /app/build-cuda
RUN cmake .. \
    -DGGML_CUDA=ON \
    -DGGML_RPC=ON \
    -DCMAKE_BUILD_TYPE=Release \
    && make -j$(nproc)

# 4. Build Variant B: Vulkan (AMD)
WORKDIR /app/build-vulkan
RUN cmake .. \
    -DGGML_VULKAN=ON \
    -DGGML_RPC=ON \
    -DCMAKE_BUILD_TYPE=Release \
    && make -j$(nproc)

# 5. Organize Binaries
WORKDIR /app
RUN mkdir -p /usr/local/bin/cuda && \
    mkdir -p /usr/local/bin/vulkan && \
    cp /app/build-cuda/bin/* /usr/local/bin/cuda/ && \
    cp /app/build-vulkan/bin/* /usr/local/bin/vulkan/

ENV PATH="/usr/local/bin/cuda:/usr/local/bin/vulkan:${PATH}"

EXPOSE 8080 50052
CMD ["/bin/bash"]
