FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    file \
    git \
    gradle \
    ninja-build \
    openjdk-17-jdk \
    perl \
    pkg-config \
    protobuf-compiler \
    python3 \
    unzip \
    xz-utils \
    zip && \
    rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV RUSTUP_HOME=/opt/rustup
ENV CARGO_HOME=/opt/cargo
ENV PATH=/opt/cargo/bin:${PATH}

RUN curl -fsSL https://sh.rustup.rs -o /tmp/rustup-init.sh && \
    sh /tmp/rustup-init.sh -y --profile minimal --default-toolchain stable && \
    rm -f /tmp/rustup-init.sh

RUN rustup toolchain install nightly --profile minimal && \
    rustup target add aarch64-linux-android armv7-linux-androideabi wasm32-unknown-unknown && \
    rustup target add --toolchain nightly wasm32-unknown-unknown && \
    cargo install --locked cargo-ndk && \
    cargo install --locked wasm-pack

ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${PATH}

RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools && \
    curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -o /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools && \
    mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest && \
    rm -f /tmp/cmdline-tools.zip

RUN yes | sdkmanager --licenses >/dev/null && \
    sdkmanager \
      "build-tools;36.0.0" \
      "cmake;3.22.1" \
      "ndk;28.2.13676358" \
      "platform-tools" \
      "platforms;android-36"

ENV ANDROID_NDK_HOME=/opt/android-sdk/ndk/28.2.13676358

COPY docker/build_release_inside.sh /opt/volvoxgrid/build_release.sh
RUN chmod +x /opt/volvoxgrid/build_release.sh

# Allow non-root users (docker run -u) to write to caches
RUN chmod -R a+w /opt/cargo /opt/rustup /opt/android-sdk

WORKDIR /workspace/volvoxgrid
ENTRYPOINT ["/opt/volvoxgrid/build_release.sh"]
