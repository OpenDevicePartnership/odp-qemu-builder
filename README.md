# qemu-builder

Prebuilt QEMU `aarch64` and `riscv32` binaries for Ubuntu 24.04, published as a multi-arch Docker image (`amd64` / `arm64`) with TPM support enabled.

## Usage

Pull the image:

```bash
docker pull ghcr.io/opendevicepartnership/odp-qemu-builder/qemu:latest
```

Run QEMU directly:

```bash
docker run --rm ghcr.io/opendevicepartnership/odp-qemu-builder/qemu:latest qemu-system-aarch64 --version
```

Copy the binary into your own image:

```dockerfile
COPY --from=ghcr.io/opendevicepartnership/odp-qemu-builder/qemu:latest /usr/local/bin/qemu-system-aarch64 /usr/local/bin/
```

Or copy the riscv32 binary. RISC-V guests typically need OpenSBI as the boot firmware (loaded by QEMU via `-bios`), so copy the firmware blob alongside the binary:

```dockerfile
COPY --from=ghcr.io/opendevicepartnership/odp-qemu-builder/qemu:latest /usr/local/bin/qemu-system-riscv32 /usr/local/bin/
COPY --from=ghcr.io/opendevicepartnership/odp-qemu-builder/qemu:latest /usr/local/share/qemu/opensbi-riscv32-generic-fw_dynamic.bin /usr/local/share/qemu/
```

Skip the firmware copy if your downstream image uses `-bios none` or supplies its own firmware.

## Building

### CI

A GitHub Actions workflow builds and pushes on every commit to `main`. Images are published to `ghcr.io/opendevicepartnership/odp-qemu-builder/qemu`.

### Local

```bash
./build-local.sh
```

This will create a dedicated `buildx` builder, compile for `linux/amd64` and `linux/arm64`, and push to GHCR. A local layer cache under `~/.cache/docker-buildx/` is used to speed up repeated builds.

## Configuration

| Build Arg      | Default                                    | Description             |
|----------------|--------------------------------------------|-------------------------|
| `QEMU_URL`     | `https://gitlab.com/qemu-project/qemu.git` | Git repository to clone |
| `QEMU_BRANCH`  | `v10.0.0`                                  | Branch or tag to build  |

## License

See [LICENSE](LICENSE).

