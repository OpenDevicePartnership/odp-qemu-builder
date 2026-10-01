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

### GTK display

QEMU is built with `--enable-modules`, so GTK display support ships as a loadable module (`ui-gtk.so`) rather than being linked into the binary. Headless usage (e.g. `-display none`, VNC) needs no GTK libraries at all.

To use `-display gtk` in a downstream image, copy the module directory and install the GTK runtime library:

```dockerfile
COPY --from=ghcr.io/opendevicepartnership/odp-qemu-builder/qemu:latest /usr/local/lib/qemu/ /usr/local/lib/qemu/
RUN apt-get update && apt-get install -y --no-install-recommends libgtk-3-0t64 && rm -rf /var/lib/apt/lists/*
```

`libgtk-3-0t64` is the only package you need to install — apt pulls in the rest of the GTK stack automatically. (That is the Ubuntu 24.04 package name; other distros/releases may call it differently, e.g. `libgtk-3-0`.)

QEMU loads `ui-gtk.so` only when `-display gtk` is requested (headless usage never touches these libraries), and the container still needs a display forwarded from the host (X11/Wayland) to show a window.

### EC GPIO wake channel

The RISC-V `ec` machine optionally connects GPIO1 to the `ec-gpio1` chardev.
For an active-high, idle-low wake wire, connect it to the AArch64 `virt` host's
`gpio1` chardev using the same socket path (start the host first):

```text
# Host QEMU, in its existing ACPI/GED firmware configuration:
-chardev socket,id=gpio1,path=/tmp/ec-wake.sock,server=on,wait=off
# EC QEMU:
-chardev socket,id=ec-gpio1,path=/tmp/ec-wake.sock
```

EC GPIO OUT bit 1 at `0x10003004` drives host PL061 pin 1 at `0x09030000`,
which shares GIC SPI 7 (INTID 39) with the other PL061 pins. Configure the
host pin as a level-high input interrupt; the wire alone does not implement
CPU suspend/resume. GPIO0 (`ec-gpio0` / `gpio0`) remains the independent HID
channel. Both EC backends are optional; unused pins and reset behavior are
unchanged. No EC GPIO2 source-detection channel is added.

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

