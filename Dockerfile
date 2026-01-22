FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

ARG RELEASE_TAG=master

# 1. Install dependencies
RUN apt-get update && apt-get install -y \
    wget gnupg software-properties-common git cmake build-essential libcurl4-openssl-dev \
    && wget -qO - https://packages.lunarg.com/lunarg-signing-key-pub.asc | apt-key add - \
    && wget -qO /etc/apt/sources.list.d/lunarg-vulkan-jammy.list https://packages.lunarg.com/vulkan/lunarg-vulkan-jammy.list \
    && apt-get update && apt-get install -y vulkan-sdk \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN git clone --depth 1 --branch ${RELEASE_TAG} https://github.com/ggml-org/llama.cpp.git .

# 2. Build with CMAKE_INSTALL_PREFIX=/usr/local
# This tells CMake to install libs to /usr/local/lib and binaries to /usr/local/bin
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
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    && cmake --build build --config Release -j$(nproc) \
    && cmake --install build --config Release

# ----------------------------------------------------
# FINAL STAGE
# ----------------------------------------------------
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y \
    libcurl4 \
    libvulkan1 \
    mesa-vulkan-drivers \
    vulkan-tools \
    binutils \
    && rm -rf /var/lib/apt/lists/*

# 3. Copy files from the builder's system paths to the runtime's system paths
# Note: We copy to /usr/local, which is standard for user-installed software
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /usr/local/include /usr/local/include

# 4. CRITICAL: Run ldconfig
# This updates the system's shared library cache so it knows about the new .so files in /usr/local/lib
RUN ldconfig

# 5. Set Backend Path
# We point to /usr/local/lib where libggml-cpu.so now lives
ENV GGML_BACKEND_PATH="/usr/local/lib"

EXPOSE 8080

# 6. Debug Check (Optional)
# This verifies that the system can resolve the CPU backend's dependencies before starting
RUN echo "Checking CPU backend linkage..." && \
    ldd /usr/local/lib/libggml-cpu.so

ENTRYPOINT ["/usr/local/bin/llama-server"]
