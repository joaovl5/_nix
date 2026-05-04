# QEMU VM Debugging Reference

This skill uses one wrapper

- **Key:** `uv run scripts/qmp.py SOCKET key CHORD [--hold-ms MS]`
- **Type:** `uv run scripts/qmp.py SOCKET type TEXT [--delay SECONDS]`
- **Mouse:** `uv run scripts/qmp.py SOCKET mouse info|move-abs|move-rel|down|up|click|wheel ... [--steps N]`
- **Screendump:** `uv run scripts/qmp.py SOCKET screendump OUTPUT [--format ppm|png] [--device ID] [--head N]`
- **Serial:** `uv run scripts/qmp.py SOCKET serial COMMAND [--serial-log PATH] [--timeout SECONDS] [--delay SECONDS] [--keep-ansi]`
- **Pull:** `uv run scripts/qmp.py SOCKET pull GUEST_PATH OUTPUT_PATH [--serial-log PATH] [--timeout SECONDS] [--delay SECONDS]`
- **HMP:** `uv run scripts/qmp.py SOCKET hmp COMMAND`
- **Raw:** `uv run scripts/qmp.py SOCKET raw JSON`

Use skill-relative paths. The harness resolves `scripts/qmp.py` and `references/qemu-vm-debugging.md` from this skill directory

## Launch pattern

- **Default entrypoint:** `nix run .#vm -- <host>`
- **Debug launch:** keep `/tmp/lavpc.qmp`, `/tmp/lavpc.serial.log`, and `/tmp/lavpc.qcow2` aligned

```bash
QEMU_OPTS='-serial file:/tmp/lavpc.serial.log -qmp unix:/tmp/lavpc.qmp,server=on,wait=off' \
QEMU_KERNEL_PARAMS='systemd.debug-shell=1' \
NIX_DISK_IMAGE=/tmp/lavpc.qcow2 \
nix run .#vm -- lavpc
```

- **Fresh disks:** use a fresh qcow2 when changing proof strategy or reproducing a stateful bug

## Wrapper examples

### Keyboard

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp key ctrl-alt-f9
uv run scripts/qmp.py /tmp/lavpc.qmp key ret
uv run scripts/qmp.py /tmp/lavpc.qmp key ctrl-alt-f9 --hold-ms 250
```

- **Mechanism:** `key` uses QMP-native `send-key`

### Type text

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp type 'root'
uv run scripts/qmp.py /tmp/lavpc.qmp type 'journalctl -b --no-pager -g drm' --delay 0.02
uv run scripts/qmp.py /tmp/lavpc.qmp key ret
```

### Mouse

- **Start:** begin with device discovery

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp mouse info
```

- **Device selection:** use QMP `query-mice` to show pointer devices and which one is current
- **Absolute range:** absolute coordinates are `0..0x7fff` on each axis
- **Absolute requirement:** absolute moves need a current absolute pointer device, usually a USB tablet
- **Fallback:** if absolute movement fails, confirm the current device first
  - Then fall back to relative movement

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

- **What it proves:** a screendump proves guest framebuffer contents only
- **Failure meaning:** on this repo's SDL plus GL path, `screendump` can fail with `no surface`
- **Interpretation:** treat that as an observability limit, not automatic proof of guest failure

### Serial-backed guest commands

- **Boundary:** `serial` owns ttyS0 redirection, unique markers, serial-log offset handling, timeout, and local stdout printing
- **Input focus:** it still types into the current guest input focus, so switch to a shell such as tty9 before using it

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp key ctrl-alt-f9
uv run scripts/qmp.py /tmp/lavpc.qmp serial 'systemd-analyze'
uv run scripts/qmp.py /tmp/lavpc.qmp serial 'journalctl -b --no-pager -g drm' --serial-log /tmp/lavpc.serial.log
uv run scripts/qmp.py /tmp/lavpc.qmp serial '/run/current-system/sw/bin/ls -l /dev/dri' --timeout 20
```

- **Guest paths:** use absolute paths inside the guest when debugging minimal or unusual shell environments

### Pull guest files through serial

- **Mechanism:** `pull` exports an arbitrary guest file through the serial channel as base64 and decodes it on the host
- **Input focus:** it has the same input-focus precondition as `serial`, so switch to a shell such as tty9 before use

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp key ctrl-alt-f9
uv run scripts/qmp.py /tmp/lavpc.qmp pull /tmp/guest-shot.png /tmp/guest-shot.png
uv run scripts/qmp.py /tmp/lavpc.qmp pull /var/log/Xorg.0.log /tmp/lavpc-xorg.log --serial-log /tmp/lavpc.serial.log
```

- **Proof boundary:** this proves the file existed in the guest and was readable from the session the wrapper used
- **Scope:** push is intentionally out of scope

### Escape hatches

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp hmp 'info qtree'
uv run scripts/qmp.py /tmp/lavpc.qmp raw '{"execute":"query-status"}'
```

- **Use only when:** structured subcommands do not cover the needed action

## Environment and runner behavior

- **Wrapper ownership:** `vm-launcher` owns setup before the generated runner starts
  - Under `nix run .#vm -- <host>`, the wrapper stages a temporary host `VM_BUNDLE_DIR`
  - It then points the generated runner at that bundle
  - CPU and RAM flags from `vm-launcher` are merged into `QEMU_OPTS` before execution

- **Common knobs:** generated runners commonly honor these environment variables
  - `QEMU_OPTS` for extra QEMU flags such as `-serial` and `-qmp`
  - `QEMU_KERNEL_PARAMS` for extra kernel parameters such as `systemd.debug-shell=1`
  - `NIX_DISK_IMAGE` for a persistent or throwaway qcow2 path
  - `QEMU_NET_OPTS` for optional network additions such as host forwarding
  - `SHARED_DIR` for generated-runner shared-directory support when applicable
  - `TMPDIR` for temporary files created by the generated runner

- **Bundle paths:**
  - Under `vm-launcher`, the host bundle path is temporary
  - It normally is not discoverable from outside the wrapper
  - Inside the guest, use `/mnt/vm-bundle` and `/run/vm-bundle`
  - If you run a generated `run-<host>-vm` directly, stage `VM_BUNDLE_DIR` yourself before launch

## Failure-mode checklist

Check these traps before concluding anything

- **SSH readiness:** an open forwarded port does not prove login, user services, or the compositor are ready
- **Wrong proof:** host screenshot, screendump, guest screenshot, and serial output prove different layers
- **Stale serial marker:** when reusing a serial log, read after the wrapper's fresh marker and offset
- **Input focus:** typing into the wrong VT, login prompt, or shell proves only that input landed somewhere
- **Multi-VM naming:** if sockets, logs, or qcow2 names collide, you can easily inspect the wrong VM

## Repo-specific facts worth remembering

- **Launcher:** `nix run .#vm -- <host>` invokes `vm-launcher` and builds `config.system.build.vm`
- **Launch flow:** it stages a temporary bundle, then runs the resolved `run-<host>-vm` launcher
- **Guest bundle paths:** `/mnt/vm-bundle` and `/run/vm-bundle`
- **Display stack:** repo VM variants use `-display sdl,gl=on`, `-vga none`, and `-device virtio-vga-gl`
- **NVIDIA setting:** repo VM variants force `my.nvidia.enable = false`
