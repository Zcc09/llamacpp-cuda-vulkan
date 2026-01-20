FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

ARG RELEASE_TAG=master

# Install minimal build dependencies
RUN apt-get update && apt-get install -y \
    git cmake build-essential libcurl4-openssl-dev \
    libvulkan-dev vulkan-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN git clone --depth 1 --branch ${RELEASE_TAG} https://github.com/ggml-org/llama.cpp.git .

# Build with CUDA and Vulkan enabled
RUN cmake -B build \
    -DGGML_CUDA=ON \
    -DGGML_VULKAN=ON \
    -DGGML_NATIVE=OFF \
    -DCMAKE_CUDA_ARCHITECTURES="86;89" \
    && cmake --build build --config Release -j2

FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

# Install runtime libraries for Vulkan
RUN apt-get update && apt-get install -y \
    libcurl4 \
    libvulkan1 \
    mesa-vulkan-drivers \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy binaries
COPY --from=builder /app/build/bin/ /app/

EXPOSE 8080

ENTRYPOINT ["/app/llama-server"]
