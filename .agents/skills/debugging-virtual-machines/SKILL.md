---
name: debugging-virtual-machines
description: Use when a live QEMU or NixOS VM in this repo needs reproducible framebuffer capture, QMP-driven input, serial-backed guest proof, or graphics debugging without confusing host screenshots, guest screenshots, and guest command execution.
---

Use this for live VM debugging in this repo. It is for proving what happened in a running guest, not for guessing from partial signals.

## Proof model

Treat every artifact as proof of a specific layer only.

- Host screenshot: proves host/QEMU presentation only.
- `uv run scripts/qmp.py SOCKET screendump ...`: proves the guest framebuffer only when QEMU exposes a surface. On this repo's SDL+GL path it can legitimately fail with `no surface`.
- Guest-side screenshot pulled from the VM: proves the compositor or app rendered inside the guest, not that the host-visible window rendered it.
- `uv run scripts/qmp.py SOCKET serial ...`: proves commands ran in the guest shell/session context that the wrapper drove.

Do not treat forwarded SSH, an open port, or a tty9 root shell as proof that the intended graphical user session is ready.

## Launch and attach

Default entrypoint:

```bash
nix run .#vm -- <host>
```

When debugging, keep socket, log, and disk names aligned and unique per VM. Launch with QMP, serial logging, tty9 debug shell, and a unique qcow2:

```bash
QEMU_OPTS='-serial file:/tmp/lavpc.serial.log -qmp unix:/tmp/lavpc.qmp,server=on,wait=off' \
QEMU_KERNEL_PARAMS='systemd.debug-shell=1' \
NIX_DISK_IMAGE=/tmp/lavpc.qcow2 \
nix run .#vm -- lavpc
```

Repo facts that matter:

- `nix run .#vm -- <host>` invokes `vm-launcher`, which builds `config.system.build.vm`, stages a temporary host `VM_BUNDLE_DIR`, then runs the generated runner.
- Inside the guest, the stable bundle paths are `/mnt/vm-bundle` and `/run/vm-bundle`.
- If you bypass `vm-launcher` and run a generated `run-<host>-vm` directly, you must stage `VM_BUNDLE_DIR` yourself.
- VM variants here use SDL+GL with `virtio-vga-gl` and force `my.nvidia.enable = false`.

## Common workflows

### Boot and login diagnostics

Use serial-backed guest commands first. `serial` types into the current guest input focus; switch to a shell such as tty9 before using it:

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp key ctrl-alt-f9
uv run scripts/qmp.py /tmp/lavpc.qmp serial 'systemd-analyze'
uv run scripts/qmp.py /tmp/lavpc.qmp serial 'journalctl -b --no-pager -g drm'
```

Prefer serial proof over SSH-readiness guesses.

### Graphical diagnostics escalation

1. Check launch arguments and serial evidence.
2. Try QMP screendump for framebuffer proof.
3. If screendump says `no surface`, capture guest-side artifacts and treat that as guest-only proof.
4. Distinguish tty9/root-shell results from the real user session.

### Keyboard and mouse input

Use QMP-native input:

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp key ctrl-alt-f9
uv run scripts/qmp.py /tmp/lavpc.qmp type 'loginctl list-sessions' --delay 0.02
uv run scripts/qmp.py /tmp/lavpc.qmp mouse info
```

### Screenshots and artifact pull

`pull`, like `serial`, types into the current guest input focus; switch to a shell such as tty9 before using it.

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp screendump /tmp/lavpc.png --format png
uv run scripts/qmp.py /tmp/lavpc.qmp key ctrl-alt-f9
uv run scripts/qmp.py /tmp/lavpc.qmp pull /tmp/guest-shot.png /tmp/guest-shot.png
```

Use pulled guest artifacts when you need compositor or app-render proof from inside the VM.

## Cleanup

Kill only the VM you started. Match on the unique socket or qcow2 path you chose, then remove temporary socket, log, and disk files if you no longer need them.

## Reference

See `references/qemu-vm-debugging.md` for the full `scripts/qmp.py` command set, mouse details, wrapper environment behavior, and failure-mode checklist.
