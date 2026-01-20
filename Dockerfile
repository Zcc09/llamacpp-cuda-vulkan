FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

ARG RELEASE_TAG=master

# Install build dependencies + Vulkan SDK
RUN apt-get update && apt-get install -y \
    wget gnupg software-properties-common git cmake build-essential libcurl4-openssl-dev \
    && wget -qO - https://packages.lunarg.com/lunarg-signing-key-pub.asc | apt-key add - \
    && wget -qO /etc/apt/sources.list.d/lunarg-vulkan-jammy.list https://packages.lunarg.com/vulkan/lunarg-vulkan-jammy.list \
    && apt-get update && apt-get install -y vulkan-sdk \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN git clone --depth 1 --branch ${RELEASE_TAG} https://github.com/ggml-org/llama.cpp.git .

# FIX: We use -j2 instead of -j$(nproc) to prevent OOM (Out of Memory) on GH Actions
# Explicitly setting Vulkan paths for Ubuntu 22.04
RUN cmake -B build \
    -DGGML_CUDA=ON \
    -DGGML_VULKAN=ON \
    -DGGML_NATIVE=OFF \
    -DCMAKE_CUDA_ARCHITECTURES="86;89" \
    -DVulkan_INCLUDE_DIR=/usr/include/vulkan \
    && cmake --build build --config Release -j2

FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y \
    libcurl4 \
    libvulkan1 \
    mesa-vulkan-drivers \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/build/bin/ .

EXPOSE 8080
ENTRYPOINT ["/app/llama-server"]
