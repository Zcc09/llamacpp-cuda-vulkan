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

# Build with Dynamic Loading (DL=ON) because it is the only way to get CUDA+Vulkan stable
# We use CMAKE_INSTALL_PREFIX to gather everything in one place first
RUN cmake -B build \
    -DGGML_CUDA=ON \
    -DGGML_VULKAN=ON \
    -DGGML_NATIVE=OFF \
    -DGGML_AVX=ON \
    -DGGML_AVX2=ON \
    -DGGML_BACKEND_DL=ON \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_CUDA_ARCHITECTURES="86;89" \
    -DCMAKE_INSTALL_PREFIX=/app/install \
    && cmake --build build --config Release -j4 \
    && cmake --install build --config Release

FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y \
    libcurl4 \
    libvulkan1 \
    mesa-vulkan-drivers \
    vulkan-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 1. Copy the executable
COPY --from=builder /app/install/bin/llama-server /app/llama-server

# 2. Copy ALL shared objects (.so) from both lib and bin to /app root
# This grabs libggml-cpu.so, libggml-cuda.so, libggml-vulkan.so
COPY --from=builder /app/install/lib/*.so /app/
COPY --from=builder /app/install/bin/*.so /app/

# 3. Environment variables
ENV GGML_BACKEND_PATH="/app"
ENV LD_LIBRARY_PATH="/app:${LD_LIBRARY_PATH}"

# 4. Create a startup script to verify backends exist
RUN echo '#!/bin/bash' > /app/entrypoint.sh && \
    echo 'echo "--- Checking /app for backends ---"' >> /app/entrypoint.sh && \
    echo 'ls -la /app/*.so' >> /app/entrypoint.sh && \
    echo 'echo "----------------------------------"' >> /app/entrypoint.sh && \
    echo 'exec /app/llama-server "$@"' >> /app/entrypoint.sh && \
    chmod +x /app/entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/app/entrypoint.sh"]
