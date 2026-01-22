FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder
ARG RELEASE_TAG=master
RUN apt-get update && apt-get install -y \
    wget gnupg software-properties-common git cmake build-essential libcurl4-openssl-dev \
    && wget -qO - https://packages.lunarg.com/lunarg-signing-key-pub.asc | apt-key add - \
    && wget -qO /etc/apt/sources.list.d/lunarg-vulkan-jammy.list https://packages.lunarg.com/vulkan/lunarg-vulkan-jammy.list \
    && apt-get update && apt-get install -y vulkan-sdk \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
RUN git clone --depth 1 --branch ${RELEASE_TAG} https://github.com/ggml-org/llama.cpp.git .
RUN cmake -B build \
    -DGGML_CUDA=ON \
    -DGGML_VULKAN=ON \
    -DGGML_NATIVE=OFF \
    -DGGML_AVX=ON \
    -DGGML_AVX2=ON \
    -DGGML_BACKEND_DL=ON \
    -DBUILD_SHARED_LIBS=ON \
    && cmake --build build --config Release -j$(nproc)

FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y \
    libcurl4 \
    libvulkan1 \
    mesa-vulkan-drivers \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/build/bin/ .
ENV GGML_BACKEND_PATH="/app"
ENV LD_LIBRARY_PATH="/app:${LD_LIBRARY_PATH}"
EXPOSE 8080
ENTRYPOINT ["/app/llama-server"]
