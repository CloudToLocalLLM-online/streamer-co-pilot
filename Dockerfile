# Streamer Co-Pilot — Docker Build Image
#
# This Dockerfile builds the Streamer Co-Pilot Flutter desktop application
# inside a container. Since this is a Flutter desktop app (not a web/server app),
# the resulting binary is extracted from the container for local use.
#
# USAGE:
#   docker build -t streamer-co-pilot-builder .
#   docker run --rm -v ${PWD}/build:/app/build streamer-co-pilot-builder
#
# To build for a specific platform, use the TARGET_PLATFORM build arg:
#   docker build --build-arg TARGET_PLATFORM=linux -t streamer-co-pilot-builder .
#   docker build --build-arg TARGET_PLATFORM=windows --build-arg CROSS_PREFIX=x86_64-w64-mingw32- -t streamer-co-pilot-builder .
#
# Supported TARGET_PLATFORM values: linux (default), windows (cross-compile), macos (cross-compile)
#
# NOTE: Cross-compilation for Windows/macOS from Linux requires additional
# toolchains and is experimental. For reliable builds, use native CI runners.

# Use the official Flutter Docker image
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS base

# Install Linux desktop build dependencies
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
        clang \
        cmake \
        ninja-build \
        pkg-config \
        libgtk-3-dev \
        liblzma-dev \
        libstdc++-12-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy only dependency files first for better layer caching
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

# Copy the rest of the source
COPY . .

# Re-run pub get to ensure all dependencies are resolved
RUN flutter pub get

# Build the Linux release binary
ARG TARGET_PLATFORM=linux
RUN case "$TARGET_PLATFORM" in \
        linux) \
            flutter build linux --release ;; \
        windows) \
            flutter build windows --release ;; \
        macos) \
            flutter build macos --release ;; \
        *) \
            echo "Unknown target: $TARGET_PLATFORM"; exit 1 ;; \
    esac

# The build output is at:
#   Linux:   build/linux/x64/release/bundle/
#   Windows: build/windows/x64/runner/Release/
#   macOS:   build/macos/Build/Products/Release/
#
# To extract the build artifacts:
#   docker run --rm -v ${PWD}/build-output:/app/build streamer-co-pilot-builder
#   # Or use a multi-stage build to copy artifacts to a minimal image

# =============================================================================
# Minimal runtime image (optional — for Linux only)
# =============================================================================
FROM ubuntu:22.04 AS runtime

RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
        libgtk-3-0 \
        liblzma5 \
        libstdc++6 \
        libx11-6 \
        libxext6 \
        libxrender1 \
        libxcb1 \
        libglib2.0-0 \
        libgdk-pixbuf2.0-0 \
        libpango-1.0-0 \
        libcairo2 \
        libatk1.0-0 \
        libasound2 \
        libnss3 \
        libnspr4 \
        libxrandr2 \
        libxfixes3 \
        libxcomposite1 \
        libxdamage1 \
        libxcursor1 \
        libxi6 \
        libxtst6 \
        libdbus-1-3 \
        libfontconfig1 \
        libxss1 \
        libdrm2 \
        libgbm1 \
        libpulse0 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=base /app/build/linux/x64/release/bundle /app

WORKDIR /app
CMD ["./streamer_co_pilot"]
