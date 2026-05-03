# QEMU VM Debugging Reference

This skill uses one wrapper:

- `uv run scripts/qmp.py SOCKET key CHORD [--hold-ms MS]`
- `uv run scripts/qmp.py SOCKET type TEXT [--delay SECONDS]`
- `uv run scripts/qmp.py SOCKET mouse info|move-abs|move-rel|down|up|click|wheel ... [--steps N]`
- `uv run scripts/qmp.py SOCKET screendump OUTPUT [--format ppm|png] [--device ID] [--head N]`
- `uv run scripts/qmp.py SOCKET serial COMMAND [--serial-log PATH] [--timeout SECONDS] [--delay SECONDS] [--keep-ansi]`
- `uv run scripts/qmp.py SOCKET pull GUEST_PATH OUTPUT_PATH [--serial-log PATH] [--timeout SECONDS] [--delay SECONDS]`
- `uv run scripts/qmp.py SOCKET hmp COMMAND`
- `uv run scripts/qmp.py SOCKET raw JSON`

Use skill-relative paths. The harness resolves `scripts/qmp.py` and `references/qemu-vm-debugging.md` from this skill directory.

## Launch pattern

Default entrypoint:

```bash
nix run .#vm -- <host>
```

Recommended debugging launch:

```bash
QEMU_OPTS='-serial file:/tmp/lavpc.serial.log -qmp unix:/tmp/lavpc.qmp,server=on,wait=off' \
QEMU_KERNEL_PARAMS='systemd.debug-shell=1' \
NIX_DISK_IMAGE=/tmp/lavpc.qcow2 \
nix run .#vm -- lavpc
```

Keep names aligned across `/tmp/lavpc.qmp`, `/tmp/lavpc.serial.log`, and `/tmp/lavpc.qcow2`. Use a fresh qcow2 when changing proof strategy or reproducing a stateful bug.

## Wrapper examples

### Keyboard

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp key ctrl-alt-f9
uv run scripts/qmp.py /tmp/lavpc.qmp key ret
uv run scripts/qmp.py /tmp/lavpc.qmp key ctrl-alt-f9 --hold-ms 250
```

`key` uses QMP-native `send-key`.

### Type text

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp type 'root'
uv run scripts/qmp.py /tmp/lavpc.qmp type 'journalctl -b --no-pager -g drm' --delay 0.02
uv run scripts/qmp.py /tmp/lavpc.qmp key ret
```

### Mouse

Start with device discovery:

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp mouse info
```

Important details:

- QMP `query-mice` shows available pointer devices and which one is current.
- Absolute coordinates are `0..0x7fff` on each axis.
- Absolute moves require a current absolute pointer device, typically a USB tablet.
- If absolute movement does not work, verify the current device first, then fall back to relative movement.

Examples:

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp mouse move-abs 16384 16384
uv run scripts/qmp.py /tmp/lavpc.qmp mouse click left
uv run scripts/qmp.py /tmp/lavpc.qmp mouse move-rel 40 -20
uv run scripts/qmp.py /tmp/lavpc.qmp mouse wheel up
```

### Screendump

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp screendump /tmp/lavpc-frame.ppm
uv run scripts/qmp.py /tmp/lavpc.qmp screendump /tmp/lavpc-frame.png --format png
```

Interpretation:

- A screendump proves guest framebuffer contents only.
- On this repo's SDL+GL path, `screendump` can fail with `no surface`. That is an observability limit, not automatic proof of guest failure.

### Serial-backed guest commands

`serial` owns ttyS0 redirection, unique markers, serial-log offset handling, timeout, and local stdout printing.
It still types into the current guest input focus, so switch to a shell such as tty9 before using it.

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp key ctrl-alt-f9
uv run scripts/qmp.py /tmp/lavpc.qmp serial 'systemd-analyze'
uv run scripts/qmp.py /tmp/lavpc.qmp serial 'journalctl -b --no-pager -g drm' --serial-log /tmp/lavpc.serial.log
uv run scripts/qmp.py /tmp/lavpc.qmp serial '/run/current-system/sw/bin/ls -l /dev/dri' --timeout 20
```

Use absolute paths inside the guest when debugging minimal or unusual shell environments.

### Pull guest files through serial

`pull` exports an arbitrary guest file through the serial channel as base64 and decodes it on the host.
It has the same input-focus precondition as `serial`: switch to a shell such as tty9 before use.

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp key ctrl-alt-f9
uv run scripts/qmp.py /tmp/lavpc.qmp pull /tmp/guest-shot.png /tmp/guest-shot.png
uv run scripts/qmp.py /tmp/lavpc.qmp pull /var/log/Xorg.0.log /tmp/lavpc-xorg.log --serial-log /tmp/lavpc.serial.log
```

This proves the file existed in the guest and was readable from the session the wrapper used. Push is intentionally out of scope.

### Escape hatches

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp hmp 'info qtree'
uv run scripts/qmp.py /tmp/lavpc.qmp raw '{"execute":"query-status"}'
```

Use these only when the structured subcommands do not cover the needed action.

## Environment and runner behavior

`vm-launcher` owns some setup before the generated runner starts:

- `VM_BUNDLE_DIR` is wrapper-owned under the normal `nix run .#vm -- <host>` flow. The wrapper stages a temporary host directory, then points the generated runner at it.
- CPU and RAM flags from `vm-launcher` are merged into `QEMU_OPTS` before execution.

Common generated-runner environment knobs:

- `QEMU_OPTS`: extra QEMU flags; useful for `-serial` and `-qmp`.
- `QEMU_KERNEL_PARAMS`: extra kernel parameters such as `systemd.debug-shell=1`.
- `NIX_DISK_IMAGE`: qcow2 path for a persistent or throwaway disk.
- `QEMU_NET_OPTS`: optional network additions such as host forwarding.
- `SHARED_DIR`: generated-runner shared-directory support when applicable.
- `TMPDIR`: affects temporary files created by the generated runner.

Bundle-path rules:

- Under `vm-launcher`, the host bundle path is temporary and normally not discoverable from outside the wrapper.
- Inside the guest, use `/mnt/vm-bundle` and `/run/vm-bundle`.
- If you run a generated `run-<host>-vm` directly, you must stage `VM_BUNDLE_DIR` yourself before launch.

## Pressure-test checklist

Before concluding anything, check these traps:

- SSH-readiness trap: an open forwarded port is not proof that login, user services, or the compositor are ready.
- Wrong-proof trap: host screenshot, screendump, guest screenshot, and serial output each prove different layers.
- Stale serial marker trap: if you are reading an existing serial log, make sure you are consuming output after the wrapper's fresh marker and offset, not old boot noise.
- Input-focus trap: a key sequence sent to the wrong VT, login prompt, or shell proves only that you typed somewhere.
- Multi-VM naming trap: if sockets, logs, or qcow2 names collide, you can easily inspect the wrong VM.

## Repo-specific facts worth remembering

- `nix run .#vm -- <host>` invokes `vm-launcher`, which builds `config.system.build.vm`, stages a temporary bundle, and runs the resolved `run-<host>-vm` launcher.
- Guest bundle paths are `/mnt/vm-bundle` and `/run/vm-bundle`.
- VM variants use `-display sdl,gl=on`, `-vga none`, and `-device virtio-vga-gl`.
- VM variants force `my.nvidia.enable = false`.
