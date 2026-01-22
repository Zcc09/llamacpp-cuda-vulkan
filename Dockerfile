FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

ARG RELEASE_TAG=master

# Install build dependencies and Vulkan SDK
RUN apt-get update && apt-get install -y \
    wget gnupg software-properties-common git cmake build-essential libcurl4-openssl-dev \
    && wget -qO - https://packages.lunarg.com/lunarg-signing-key-pub.asc | apt-key add - \
    && wget -qO /etc/apt/sources.list.d/lunarg-vulkan-jammy.list https://packages.lunarg.com/vulkan/lunarg-vulkan-jammy.list \
    && apt-get update && apt-get install -y vulkan-sdk \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN git clone --depth 1 --branch ${RELEASE_TAG} https://github.com/ggml-org/llama.cpp.git .

# Build with Dynamic Loading (DL=ON)
# Added -DGGML_USE_CPU=ON as per PR #10469
RUN cmake -B build \
    -DGGML_CUDA=ON \
    -DGGML_VULKAN=ON \
    -DGGML_NATIVE=OFF \
    -DGGML_AVX=ON \
    -DGGML_AVX2=ON \
    -DGGML_USE_CPU=ON \
    -DGGML_BACKEND_DL=ON \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_CUDA_ARCHITECTURES="86;89;90" \
    -DCMAKE_INSTALL_PREFIX=/app/install \
    && cmake --build build --config Release -j4 \
    && cmake --install build --config Release

# --- CRITICAL STEP ---
# Use 'cp -a' to copy libraries while PRESERVING symlinks (e.g. libmtmd.so.0 -> libmtmd.so)
RUN mkdir -p /staging/lib && \
    mkdir -p /staging/bin && \
    cp -a /app/install/lib/. /staging/lib/ && \
    cp -a /app/install/bin/. /staging/bin/

# ----------------------------------------------------
# FINAL STAGE
# ----------------------------------------------------
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y \
    libcurl4 \
    libvulkan1 \
    mesa-vulkan-drivers \
    vulkan-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy from staging to preserve the symlinks
COPY --from=builder /staging/ .

# Point the OS loader to our library folder so it finds libmtmd.so.0
ENV LD_LIBRARY_PATH="/app/lib:${LD_LIBRARY_PATH}"

# Point llama.cpp to the folder containing the backends
ENV GGML_BACKEND_PATH="/app/lib"

EXPOSE 8080

ENTRYPOINT ["/app/bin/llama-server"]
