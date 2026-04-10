#!/usr/bin/env bash
# build.sh — Build QEMU locally using the builder Docker image.
#
# This mirrors what CI does: build the builder image, then run
# build-in-docker.sh inside it for each architecture with persistent
# local caches.
#
# Usage:  ./build.sh [ARCH ...]
#   ARCH defaults to: amd64 arm64
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILDER_IMAGE="qemu-builder:local"
CACHE_DIR="${HOME}/.cache/qemu-builder"
ARCHS=("${@:-amd64 arm64}")

# ---------------------------------------------------------------------------
# Build the builder image
# ---------------------------------------------------------------------------
echo "==> Building builder image: ${BUILDER_IMAGE}"
docker build -t "${BUILDER_IMAGE}" "${SCRIPT_DIR}"

# ---------------------------------------------------------------------------
# Run build.sh for each architecture
# ---------------------------------------------------------------------------
for arch in "${ARCHS[@]}"; do
    echo
    echo "==> Building QEMU for ${arch}"
    mkdir -p "${CACHE_DIR}/qemu-src" \
             "${CACHE_DIR}/build-${arch}" \
             "${CACHE_DIR}/ccache-${arch}" \
             "${CACHE_DIR}/output-${arch}"

    docker run --rm \
        -v "${CACHE_DIR}/qemu-src:/work/qemu" \
        -v "${CACHE_DIR}/build-${arch}:/work/build" \
        -v "${CACHE_DIR}/ccache-${arch}:/work/ccache" \
        -v "${CACHE_DIR}/output-${arch}:/work/output" \
        "${BUILDER_IMAGE}" \
        /opt/builder/build-in-docker.sh "${arch}"

    echo "==> Output for ${arch}:"
    ls -lh "${CACHE_DIR}/output-${arch}/usr/local/bin/" 2>/dev/null || true
done

echo
echo "Done. Artifacts in: ${CACHE_DIR}/output-*/usr/local/"
