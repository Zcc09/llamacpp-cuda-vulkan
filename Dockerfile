FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

ARG RELEASE_TAG=master

# Install build dependencies + Vulkan SDK + Shaderc (Critical for Vulkan linking)
RUN apt-get update && apt-get install -y \
    wget gnupg software-properties-common git cmake build-essential libcurl4-openssl-dev \
    libshaderc-dev libvulkan-dev \
    && wget -qO - https://packages.lunarg.com/lunarg-signing-key-pub.asc | apt-key add - \
    && wget -qO /etc/apt/sources.list.d/lunarg-vulkan-jammy.list https://packages.lunarg.com/vulkan/lunarg-vulkan-jammy.list \
    && apt-get update && apt-get install -y vulkan-sdk \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN git clone --depth 1 --branch ${RELEASE_TAG} https://github.com/ggml-org/llama.cpp.git .

# Build with CUDA + Vulkan. 
# We use -j1 to guarantee stability on GitHub's limited RAM runners.
RUN cmake -B build \
    -DGGML_CUDA=ON \
    -DGGML_VULKAN=ON \
    -DGGML_NATIVE=OFF \
    -DCMAKE_CUDA_ARCHITECTURES="86;89" \
    && cmake --build build --config Release -j1

FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y \
    libcurl4 \
    libvulkan1 \
    mesa-vulkan-drivers \
    libshaderc1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the server and the necessary backend files
COPY --from=builder /app/build/bin/ /app/

EXPOSE 8080

# Use the full path for the entrypoint
ENTRYPOINT ["/app/llama-server"]
