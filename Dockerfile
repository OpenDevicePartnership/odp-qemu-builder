# Builder image: build tools + amd64/arm64 cross-compilation libraries.
# Does NOT compile QEMU itself — use build.sh with volume mounts for that.
FROM ubuntu:24.04

# --------------------------------------------------------------------------
# Enable arm64 multiarch so we can install :arm64 dev libraries for
# cross-compilation.  Ubuntu 24.04 uses deb822 format in sources.list.d.
# --------------------------------------------------------------------------
RUN dpkg --add-architecture arm64

# Add arm64 (ports) archive alongside the default amd64 archive.
# Pin the existing default source to amd64 only, then add a ports mirror
# for arm64 packages.
RUN sed -i 's/^Types:/Architectures: amd64\nTypes:/' /etc/apt/sources.list.d/ubuntu.sources && \
    printf '\n\
Types: deb\n\
URIs: http://ports.ubuntu.com/ubuntu-ports/\n\
Suites: noble noble-updates noble-security\n\
Components: main universe\n\
Architectures: arm64\n\
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n' \
    >> /etc/apt/sources.list.d/ubuntu.sources

# --------------------------------------------------------------------------
# Install native (amd64) build tools
# --------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash \
        bc \
        bison \
        bzip2 \
        ca-certificates \
        ccache \
        findutils \
        flex \
        g++ \
        gcc \
        git \
        libc6-dev \
        locales \
        make \
        meson \
        ninja-build \
        pkgconf \
        python3 \
        python3-venv \
        sed \
        tar \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------------------
# Install native (amd64) development libraries
# --------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libfdt-dev \
        libffi-dev \
        libglib2.0-dev \
        libpixman-1-dev \
        libtpms-dev \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------------------
# Install aarch64 cross-compiler and arm64 development libraries
# --------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        g++-aarch64-linux-gnu \
        gcc-aarch64-linux-gnu \
        libc6-dev-arm64-cross \
        libfdt-dev:arm64 \
        libffi-dev:arm64 \
        libglib2.0-dev:arm64 \
        libpixman-1-dev:arm64 \
        libtpms-dev:arm64 \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------------------
# The arm64 packages above pull in python3:arm64, which replaces the amd64
# python3 and drops python3-venv.  Reinstall the native amd64 versions so
# QEMU's configure (which needs venv) works correctly.
# --------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3:amd64 \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------------------------------
# Create ccache symlinks for the cross compilers so that
# PATH="/usr/lib/ccache:$PATH" also wraps them.
# --------------------------------------------------------------------------
RUN ln -sf /usr/bin/ccache /usr/lib/ccache/aarch64-linux-gnu-gcc && \
    ln -sf /usr/bin/ccache /usr/lib/ccache/aarch64-linux-gnu-g++

# --------------------------------------------------------------------------
# Copy build script and patch into the image
# --------------------------------------------------------------------------
COPY build.sh /opt/builder/build.sh
COPY qemu-sbsa-patch.patch /opt/builder/qemu-sbsa-patch.patch
RUN chmod +x /opt/builder/build.sh

WORKDIR /work
