# Base image: CUDA 13.0 on Ubuntu 24.04 (Noble)
FROM nvidia/cuda:13.0.0-devel-ubuntu24.04

ARG GIT_TAG=master
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install Dependencies & LunarG Vulkan SDK
# We need the latest Vulkan SDK to support the RX 7600XT properly
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    software-properties-common \
    && wget -qO - https://packages.lunarg.com/lunarg-signing-key-pub.asc | apt-key add - \
    && wget -qO /etc/apt/sources.list.d/lunarg-vulkan-noble.list https://packages.lunarg.com/vulkan/lunarg-vulkan-noble.list \
    && apt-get update

RUN apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    vulkan-sdk \
    && rm -rf /var/lib/apt/lists/*

# 2. Clone llama.cpp
WORKDIR /app
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/ggml-org/llama.cpp.git .

# 3. Build Variant A: CUDA (Strictly RTX 30 & 40 Series)
# Reverted to -j1 to prevent OOM crash during linking of libllama.so
WORKDIR /app/build-cuda
# 86 = RTX 3000 series (Ampere)
# 89 = RTX 4000 series (Ada Lovelace)
RUN cmake .. \
    -DGGML_CUDA=ON \
    -DGGML_RPC=ON \
    -DGGML_BUILD_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES="86;89" \
    && make -j2

# 4. Build Variant B: Vulkan (RX 7600XT)
# Vulkan builds are lighter, but we keep -j1 for consistency and safety
WORKDIR /app/build-vulkan
RUN cmake .. \
    -DGGML_VULKAN=ON \
    -DGGML_RPC=ON \
    -DGGML_BUILD_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    && make -j2

# 5. Organize Binaries
WORKDIR /app
RUN mkdir -p /usr/local/bin/cuda && \
    mkdir -p /usr/local/bin/vulkan && \
    cp /app/build-cuda/bin/* /usr/local/bin/cuda/ && \
    cp /app/build-vulkan/bin/* /usr/local/bin/vulkan/

ENV PATH="/usr/local/bin/cuda:/usr/local/bin/vulkan:${PATH}"
EXPOSE 8080 50052

CMD ["/bin/bash"]
