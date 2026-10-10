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
channel. Both backends are optional.

### Emulated EC external-power input

GPIO2 is a QEMU-emulated source input, not physical power detection: high
means AC and low means DC. Select the initial source explicitly before
starting the EC, independently of whether a runtime socket peer is connected:

```text
# Initial AC:
-global odp-gpio.input-reset-mask=0x4 -global odp-gpio.input-reset=0x4
# Initial DC:
-global odp-gpio.input-reset-mask=0x4 -global odp-gpio.input-reset=0x0
# Optional runtime control socket, on the EC:
-chardev socket,id=ec-gpio2,path=/tmp/ec-power.sock,server=on,wait=off
```

The peer sends raw bytes `0x01` (AC) or `0x00` (DC), not ASCII digits.
Other bytes on GPIO2 are rejected with a diagnostic and leave the source
unchanged. A missing or disconnected peer retains the selected/last source
and emits a diagnostic; disconnect never implies DC.

The 32-bit `input-reset-mask` marks explicitly initialized inputs;
`input-reset` supplies their initial levels and must not set bits outside
that mask. Both properties default to zero. Despite their names, they seed
external input state only when the device is first realized: an EC warm reset
preserves the current masked input levels, including runtime source changes.
Output and interrupt registers retain their normal reset behavior; unmasked
inputs reset to zero as before.

Firmware must check bit 2 of the read-only `INPUT_INITIALIZED` register at
`0x10003018`, then sample bit 2 of `IN` at `0x10003000` and configure the
service before starting its Runner. A clear initialization bit is an error,
not DC. QEMU also rejects an attached GPIO2 backend unless initialization
mask bit 2 is set. Received bytes do not establish missing initialization.

GPIO2 uses the existing GPIO interrupt controls at offsets `0x08` through
`0x14`, sharing EC PLIC source 4. One edge/level polarity is selectable per
pin; this is a level interface, not a lossless transition queue. GPIO0/HID
and GPIO1/wake are unchanged. This interface does not implement a power
service, physical source detection, or Windows sleep/resume.

## Building

### CI

A GitHub Actions workflow builds and pushes on every commit to `main`. Images are published to `ghcr.io/opendevicepartnership/odp-qemu-builder/qemu`.

The image build runs the native QEMU GPIO qtests included in the bus patch.
From a configured, patched QEMU source tree, run them independently with:

```bash
cd build
./pyvenv/bin/meson test --print-errorlogs qtest-riscv32/odp-gpio-test
```

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

