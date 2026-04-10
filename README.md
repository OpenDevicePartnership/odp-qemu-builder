# qemu-builder

Prebuilt QEMU `aarch64` binaries for Ubuntu 24.04, with TPM support enabled.
CI produces binaries for both `amd64` and `arm64` hosts (arm64 is cross-compiled).

## Downloading artifacts

QEMU build artifacts are uploaded as GitHub Actions artifacts on each CI run.
Download them from the [Actions tab](../../actions) for the latest build.

The builder Docker image is also published to GHCR for developer use:

```bash
docker pull ghcr.io/opendevicepartnership/odp-qemu-builder/builder:latest
```

## Building locally

```bash
./build.sh            # builds for both amd64 and arm64
./build.sh amd64      # build for amd64 only
./build.sh arm64      # build for arm64 only
```

This builds the builder Docker image, then runs it with local cache directories
under `~/.cache/qemu-builder/`. Subsequent builds reuse cached QEMU sources,
build objects, and ccache data for fast incremental rebuilds.

Output artifacts are placed in `~/.cache/qemu-builder/output-<arch>/usr/local/`.

### Prerequisites

- Docker (with BuildKit)
- `qemu-user-static` binfmt registered (for arm64 cross-library installation):
  ```bash
  docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
  ```

## Project structure

| File                  | Description                                                      |
|-----------------------|------------------------------------------------------------------|
| `build.sh`           | Host-side script: builds the Docker image and runs the build     |
| `build-in-docker.sh` | Runs inside the builder container: clones, configures, compiles  |
| `Dockerfile`          | Builder image with native + cross-compilation toolchains         |
| `qemu-sbsa-patch.patch` | SBSA platform TPM support patch applied to QEMU              |

## Configuration

| Variable       | Default                                    | Description             |
|----------------|--------------------------------------------|-------------------------|
| `QEMU_URL`     | `https://gitlab.com/qemu-project/qemu.git` | Git repository to clone |
| `QEMU_BRANCH`  | `v10.0.0`                                  | Branch or tag to build  |

These can be set as environment variables when running `build-in-docker.sh`
directly, or are defined in the CI workflow.

## License

See [LICENSE](LICENSE).

