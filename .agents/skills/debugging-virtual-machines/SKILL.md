---
name: debugging-virtual-machines
description: Use when a live QEMU or NixOS VM needs reproducible framebuffer capture, QMP control, guest-side graphics evidence, or compositor debugging without relying on ad-hoc host screenshots or SSH-readiness guesses.
---

Use this for live VM debugging in this repo, especially when a compositor renders black, boot/login feels slow, or you need proof artifacts from a running guest.

## First rules

- Do not treat an open forwarded SSH port as proof that login or compositor startup is ready.
- Do not use a host screenshot as proof when QMP or guest-side capture is available.
- If bypassing `vm-launcher` and running a generated `run-<host>-vm`, stage `VM_BUNDLE_DIR=/tmp/<bundle>` yourself or QEMU will fail to mount `vmBundle`.
- Use a fresh, uniquely named qcow2 when switching proof strategies.

## Fast runbook

1. Inspect the generated runner:

```bash
nix build .#nixosConfigurations.lavpc.config.system.build.vm --print-out-paths --no-link
```

Confirm memory/CPU flags, GPU flags, 9p mounts, and whether `QEMU_OPTS` is appended.

2. Launch with serial log, QMP, tty9 debug shell, and a unique disk:

```bash
QEMU_OPTS='-serial file:/tmp/lavpc.serial.log -qmp unix:/tmp/lavpc.qmp,server=on,wait=off' \
QEMU_KERNEL_PARAMS='systemd.debug-shell=1' \
NIX_DISK_IMAGE=/tmp/lavpc.qcow2 \
nix run .#vm -- lavpc
```

3. Switch to tty9 and capture framebuffer:

```bash
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp.py /tmp/lavpc.qmp sendkey ctrl-alt-f9
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp.py /tmp/lavpc.qmp screendump /tmp/lavpc-tty9.ppm
magick /tmp/lavpc-tty9.ppm /tmp/lavpc-tty9.png
```

Use `inspect_image` on the PNG when visual evidence matters.

4. Type guest diagnostics into tty9 with `vm_qmp_type.py` and redirect tagged output to `ttyS0`:

```bash
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp_type.py /tmp/lavpc.qmp $'echo tag dri >/dev/ttyS0;/run/current-system/sw/bin/ls -l /dev/dri 1>/dev/ttyS0 2>/dev/ttyS0\n'
```

`vm_qmp_type.py` needs a real newline character to press Enter; Bash `$'...\n'` does that.

## Evidence checklist

- Graphics stack - check:
  - QEMU args
  - `virtio_gpu` in journal
  - `/dev/dri/renderD128`
  - `/sys/class/drm`.
- Bad graphics signs:
  - `bochs-drm`
  - only `/dev/dri/card0`
  - no render node.
- SDL+GL path:
  - QMP `screendump` can report `no surface`
  - Use guest-side `niri msg action screenshot-screen` and export through `/mnt/vm-bundle/`.
- Performance: measure current boot with `systemd-analyze`, `systemd-analyze blame`, `systemd-analyze critical-chain`, and `findmnt -t 9p`.
- Serial proof: keep `serial-getty@ttyS0` alive, tag output, and sanitize/truncate huge ANSI logs before pasting them.

## Repo-specific graphics reminders

- Working accelerated profile here: `-display sdl,gl=on`, `-vga none`, `-device virtio-vga-gl`.
- VM variants should force `my.nvidia.enable = false`; otherwise guest userspace may try a host-oriented NVIDIA GBM stack.
- Running `niri-session` from the root debug shell is not a real user session proof.
- If invoking `niri-session` from an existing login shell, pass `-l` to avoid relogin recursion.

## More detail

See `references/qemu-vm-debugging.md` for QMP helper commands, longer diagnostic batches, cleanup, and session pitfalls.
