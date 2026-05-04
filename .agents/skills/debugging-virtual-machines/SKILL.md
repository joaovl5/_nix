---
name: debugging-virtual-machines
description: Use when a live QEMU or NixOS VM in this repo needs reproducible framebuffer capture, QMP-driven input, serial-backed guest proof, or graphics debugging without confusing host screenshots, guest screenshots, and guest command execution
---

Use this for live VM debugging in this repo. Prove what happened in the guest instead of guessing from partial signals

## Proof model

Treat each artifact as proof of one layer only

- **Host screenshot:** proves host or QEMU presentation only
- **QMP screendump:** `uv run scripts/qmp.py SOCKET screendump ...` proves guest framebuffer contents only when QEMU exposes a surface
- **Guest-side screenshot:** pulled artifacts prove the compositor or app rendered inside the guest, not that the host-visible window rendered it
- **Serial command:** `uv run scripts/qmp.py SOCKET serial ...` proves commands ran in the guest shell or session the wrapper drove

Do not treat forwarded SSH, an open port, or a tty9 root shell as proof that the intended graphical user session is ready

## Launch and attach

- **Default entrypoint:** `nix run .#vm -- <host>`
- **Debug launch:** keep socket, log, and disk names aligned and unique per VM

```bash
QEMU_OPTS='-serial file:/tmp/lavpc.serial.log -qmp unix:/tmp/lavpc.qmp,server=on,wait=off' \
QEMU_KERNEL_PARAMS='systemd.debug-shell=1' \
NIX_DISK_IMAGE=/tmp/lavpc.qcow2 \
nix run .#vm -- lavpc
```

- **Wrapper path:** `nix run .#vm -- <host>` goes through `vm-launcher`; bundle-path details and direct-runner caveats are in `references/qemu-vm-debugging.md`
- **Framebuffer limit:** on this repo's SDL plus GL path, `screendump` can legitimately fail with `no surface`

## Common workflows

### Boot and login diagnostics

- **First move:** use serial-backed guest commands
- **Input focus:** `serial` types into the current guest input focus, so switch to a shell such as tty9 before using it

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp key ctrl-alt-f9
uv run scripts/qmp.py /tmp/lavpc.qmp serial 'systemd-analyze'
uv run scripts/qmp.py /tmp/lavpc.qmp serial 'journalctl -b --no-pager -g drm'
```

- **Preference:** prefer serial proof over SSH-readiness guesses

### Graphical diagnostics escalation

- **Step 1:** check launch arguments and serial evidence
- **Step 2:** try QMP screendump for framebuffer proof
- **Step 3:** if screendump says `no surface`, capture guest-side artifacts and treat that as guest-only proof
- **Step 4:** distinguish tty9 or root-shell results from the real user session

### Keyboard and mouse input

- **Use QMP-native input:** drive keys, typed text, and mouse events through the wrapper

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp key ctrl-alt-f9
uv run scripts/qmp.py /tmp/lavpc.qmp type 'loginctl list-sessions' --delay 0.02
uv run scripts/qmp.py /tmp/lavpc.qmp mouse info
```

### Screenshots and artifact pull

- **Input focus:** `pull`, like `serial`, types into the current guest input focus, so switch to a shell such as tty9 before using it

```bash
uv run scripts/qmp.py /tmp/lavpc.qmp screendump /tmp/lavpc.png --format png
uv run scripts/qmp.py /tmp/lavpc.qmp key ctrl-alt-f9
uv run scripts/qmp.py /tmp/lavpc.qmp pull /tmp/guest-shot.png /tmp/guest-shot.png
```

- **Use case:** use pulled guest artifacts when you need compositor or app-render proof from inside the VM

## Cleanup

- **Scope:** kill only the VM you started
- **Match:** use the unique socket or qcow2 path you chose, then remove temporary socket, log, and disk files if you no longer need them

## Reference

See `references/qemu-vm-debugging.md` for the full `scripts/qmp.py` command set, mouse details, wrapper environment behavior, and the failure-mode checklist
