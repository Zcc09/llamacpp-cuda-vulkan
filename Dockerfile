# Base image: CUDA 13.0 on Ubuntu 24.04 (Noble)
FROM nvidia/cuda:13.0.0-devel-ubuntu24.04

ARG GIT_TAG=master
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install Dependencies & LunarG Vulkan SDK
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

# -----------------------------------------------------------------------------
# CRITICAL FIX: Link against CUDA Stubs
# -----------------------------------------------------------------------------
# The build needs 'libcuda.so.1' (Driver API), but containers don't have drivers.
# We point the linker to the stubs folder and create the expected symlink.
ENV LIBRARY_PATH="/usr/local/cuda/lib64/stubs:${LIBRARY_PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64/stubs:${LD_LIBRARY_PATH}"
RUN ln -sf /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1

# 2. Clone llama.cpp
WORKDIR /app
RUN git clone --depth 1 --branch ${GIT_TAG} https://github.com/ggml-org/llama.cpp.git .

# 3. Build Variant A: CUDA (Strictly RTX 30 & 40 Series)
# Using -j4 since you confirmed the runner can handle the RAM
WORKDIR /app/build-cuda
RUN cmake .. \
    -DGGML_CUDA=ON \
    -DGGML_RPC=ON \
    -DGGML_BUILD_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES="86;89" \
    && make -j4

# 4. Build Variant B: Vulkan (RX 7600XT)
WORKDIR /app/build-vulkan
RUN cmake .. \
    -DGGML_VULKAN=ON \
    -DGGML_RPC=ON \
    -DGGML_BUILD_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    && make -j4

# 5. Organize Binaries
WORKDIR /app
RUN mkdir -p /usr/local/bin/cuda && \
    mkdir -p /usr/local/bin/vulkan && \
    cp /app/build-cuda/bin/* /usr/local/bin/cuda/ && \
    cp /app/build-vulkan/bin/* /usr/local/bin/vulkan/

ENV PATH="/usr/local/bin/cuda:/usr/local/bin/vulkan:${PATH}"
EXPOSE 8080 50052

CMD ["/bin/bash"]
