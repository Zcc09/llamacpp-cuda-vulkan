# Base image with CUDA support
FROM nvidia/cuda:12.6.0-devel-ubuntu22.04

# Argument for the specific llama.cpp tag to build (default to master if not specified)
ARG GIT_TAG=master

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install dependencies
# 'vulkan-tools', 'libvulkan-dev', and 'spirv-tools' are critical for AMD/Vulkan support
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
# We use -j1 to prevent Out-Of-Memory (OOM) errors on GitHub Actions runners
WORKDIR /app/build-cuda
RUN cmake .. \
    -DGGML_CUDA=ON \
    -DGGML_RPC=ON \
    -DCMAKE_BUILD_TYPE=Release \
    && make -j1

# 4. Build Variant B: Vulkan (AMD)
WORKDIR /app/build-vulkan
RUN cmake .. \
    -DGGML_VULKAN=ON \
    -DGGML_RPC=ON \
    -DCMAKE_BUILD_TYPE=Release \
    && make -j1

# 5. Organize Binaries
# Move them to distinct folders so you can call specific backends easily
WORKDIR /app
RUN mkdir -p /usr/local/bin/cuda && \
    mkdir -p /usr/local/bin/vulkan && \
    cp /app/build-cuda/bin/* /usr/local/bin/cuda/ && \
    cp /app/build-vulkan/bin/* /usr/local/bin/vulkan/

# Add binaries to path (Optional, but useful for quick access)
ENV PATH="/usr/local/bin/cuda:/usr/local/bin/vulkan:${PATH}"

# Expose ports: 8080 (Main Server), 50052 (RPC Server default)
EXPOSE 8080 50052

# Default entrypoint (Starts a shell so you can launch both processes)
CMD ["/bin/bash"]
