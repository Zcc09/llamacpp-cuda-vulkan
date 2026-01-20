FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

ARG RELEASE_TAG=master

# 1. Builder Stage: Install all necessary dev headers
RUN apt-get update && apt-get install -y \
    wget gnupg software-properties-common git cmake build-essential libcurl4-openssl-dev \
    libshaderc-dev libvulkan-dev \
    && wget -qO - https://packages.lunarg.com/lunarg-signing-key-pub.asc | apt-key add - \
    && wget -qO /etc/apt/sources.list.d/lunarg-vulkan-jammy.list https://packages.lunarg.com/vulkan/lunarg-vulkan-jammy.list \
    && apt-get update && apt-get install -y vulkan-sdk \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN git clone --depth 1 --branch ${RELEASE_TAG} https://github.com/ggml-org/llama.cpp.git .

# Force a clean static build for stability
RUN cmake -B build \
    -DGGML_CUDA=ON \
    -DGGML_VULKAN=ON \
    -DGGML_NATIVE=OFF \
    -DCMAKE_CUDA_ARCHITECTURES="86;89" \
    && cmake --build build --config Release -j1

FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

# 2. Runtime Stage: Fix Exit Code 100
# We use DEBIAN_FRONTEND=noninteractive and combine update/install
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libcurl4 \
    libvulkan1 \
    mesa-vulkan-drivers \
    libshaderc1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy all compiled binaries from the builder
COPY --from=builder /app/build/bin/ /app/

EXPOSE 8080

ENTRYPOINT ["/app/llama-server"]
