#!/usr/bin/env bash
# build.sh — Build qemu-system-aarch64 inside the builder container.
#
# Usage:  build.sh <ARCH>
#   ARCH:  amd64  — native build
#          arm64  — cross-compile with aarch64-linux-gnu toolchain
#
# Expected mount points (bind-mounted by the caller):
#   /work/qemu    — QEMU source tree (cloned here if empty)
#   /work/build   — out-of-source build directory
#   /work/ccache  — ccache cache directory
#   /work/output  — the built binary is copied here
#
# Environment variables (optional):
#   QEMU_URL     — git remote  (default: https://gitlab.com/qemu-project/qemu.git)
#   QEMU_BRANCH  — git branch/tag to check out (default: v10.0.0)
set -euo pipefail

ARCH="${1:?Usage: build.sh <amd64|arm64>}"
QEMU_URL="${QEMU_URL:-https://gitlab.com/qemu-project/qemu.git}"
QEMU_BRANCH="${QEMU_BRANCH:-v10.0.0}"

# ----- ccache setup --------------------------------------------------------
export CCACHE_DIR=/work/ccache
export PATH="/usr/lib/ccache:${PATH}"
mkdir -p "$CCACHE_DIR"

# ----- Clone QEMU source if not already present ----------------------------
if [ ! -d /work/qemu/.git ]; then
    echo "==> Cloning QEMU ${QEMU_BRANCH} from ${QEMU_URL}"
    git clone "${QEMU_URL}" --branch "${QEMU_BRANCH}" --depth 1 /work/qemu
    echo "==> Applying sbsa patch"
    cd /work/qemu
    git apply /opt/builder/qemu-sbsa-patch.patch
else
    echo "==> QEMU source already present, skipping clone"
fi

# ----- Configure ------------------------------------------------------------
mkdir -p /work/build
cd /work/build

CONFIGURE_ARGS=(
    --target-list=aarch64-softmmu
    --enable-plugins
    --enable-tpm
)

case "${ARCH}" in
    amd64)
        echo "==> Configuring for native amd64 build"
        ;;
    arm64)
        echo "==> Configuring for arm64 cross-compilation"
        CONFIGURE_ARGS+=(
            --cross-prefix=aarch64-linux-gnu-
        )
        export PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig
        ;;
    *)
        echo "error: unsupported ARCH '${ARCH}' (expected amd64 or arm64)" >&2
        exit 1
        ;;
esac

# Only re-run configure if config-host.mak is missing (i.e. first build or
# cache was cleared).  On incremental builds the existing config is reused.
if [ ! -f /work/build/config-host.mak ]; then
    /work/qemu/configure "${CONFIGURE_ARGS[@]}"
else
    echo "==> config-host.mak exists, skipping configure (incremental build)"
fi

# ----- Build ----------------------------------------------------------------
echo "==> Building QEMU (ARCH=${ARCH})"
ninja

# ----- Install into output --------------------------------------------------
echo "==> Installing QEMU to /work/output"
DESTDIR=/work/output ninja install

echo "==> Build complete"
echo "    contents:"
find /work/output -type f | head -50
echo "    ccache stats:"
ccache --show-stats
