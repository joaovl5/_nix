---
name: debugging-virtual-machines
description: Use when a live QEMU or NixOS VM needs reproducible framebuffer capture, QMP control, guest-side graphics evidence, or compositor debugging without relying on ad-hoc host screenshots or SSH-readiness guesses.
---

Use this skill for live VM debugging in this repo, especially when a compositor renders black, boot/login feels slow, or you need proof artifacts from a running guest.

## Repo-specific facts worth knowing

- Main launcher: `nix run .#vm -- <host>`
- Build output to inspect: `.#nixosConfigurations.<host>.config.system.build.vm`
- If you bypass `vm-launcher` and run a generated `run-<host>-vm` script directly, you **must** stage a bundle directory yourself and set `VM_BUNDLE_DIR=/tmp/<bundle>` or QEMU will fail to mount `vmBundle`.
- Proven debug launch pattern in this repo:

```bash
QEMU_OPTS='-serial file:/tmp/lavpc.serial.log -qmp unix:/tmp/lavpc.qmp,server=on,wait=off' \
QEMU_KERNEL_PARAMS='systemd.debug-shell=1' \
NIX_DISK_IMAGE=/tmp/lavpc.qcow2 \
nix run .#vm -- lavpc
```

- `systemd.debug-shell=1` gives a root shell on tty9.
- Switch to tty9 with QMP/HMP `sendkey alt-f9`.
- In this repo, the working accelerated VM graphics profile is `-display sdl,gl=on`, `-vga none`, `-device virtio-vga-gl`.
- VM variants in this repo should also force `my.nvidia.enable = false`; otherwise guest userspace may try to load `/run/opengl-driver/lib/gbm/nvidia-drm_gbm.so`, which is a host-oriented NVIDIA leak and not the correct VM graphics stack.
- Fresh qcow2 images matter for reproducibility here. Reusing the same proof disk across many experiments led to misleading Home Manager and session failures.
- QMP `screendump` is reliable on the non-GL path, but on the working SDL+GL path it can report `no surface` even while the guest boots and `niri` renders. Treat that as an observability limitation, not automatic proof of guest failure.
- Do **not** treat an open forwarded SSH port as proof that login or compositor startup is ready.
- Do **not** use a host screenshot of the QEMU window as proof when QMP framebuffer capture is available.
- Keep `serial-getty@ttyS0` alive when you need serial proof artifacts; disabling it makes `/dev/ttyS0`-redirected diagnostics much less useful.
- Serial logs from these VMs can contain ANSI control sequences and very long wrapped lines. Sanitize and truncate them before pasting into a TUI or agent chat.

## Helpers in this skill

- `scripts/vm_qmp.py`
  - generic QMP helper
  - supports `hmp`, `sendkey`, `screendump`, and raw JSON payloads
- `scripts/vm_qmp_type.py`
  - types shell commands into a VM through QMP `sendkey`
  - useful for tty9 debug-shell diagnostics

Run them with `python`:

```bash
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp.py /tmp/lavpc.qmp sendkey alt-f9
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp.py /tmp/lavpc.qmp screendump /tmp/lavpc.ppm
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp_type.py /tmp/lavpc.qmp 'echo tag analyze >/dev/ttyS0;systemd-analyze >/dev/ttyS0\n'
```

## Minimal workflow

### 1. Inspect the generated runner first

```bash
nix build .#nixosConfigurations.lavpc.config.system.build.vm --print-out-paths --no-link
```

Read the generated `run-<host>-vm` script and confirm:

- explicit `-m` / `-smp`
- explicit GPU flags
- expected `virtfs` / 9p mounts
- whether `QEMU_OPTS` is still appended

### 2. Launch a debuggable VM

Use serial log + QMP socket + persistent disk path:

```bash
QEMU_OPTS='-serial file:/tmp/lavpc.serial.log -qmp unix:/tmp/lavpc.qmp,server=on,wait=off' \
QEMU_KERNEL_PARAMS='systemd.debug-shell=1' \
NIX_DISK_IMAGE=/tmp/lavpc.qcow2 \
nix run .#vm -- lavpc
```

Good defaults:

- keep log/socket/image names aligned (`lavpc.*`)
- use a unique `/tmp/<name>.qcow2` per experiment, and prefer a fresh qcow2 when switching proof strategies
- add `QEMU_NET_OPTS='hostfwd=tcp::2222-:22'` only if you truly need SSH
- if using a raw generated runner instead of `nix run .#vm`, stage `/tmp/<name>-bundle` first with `age/key.txt` and export `VM_BUNDLE_DIR` before launch

### 3. Capture proof images from the guest framebuffer

Switch to tty9 debug shell:

```bash
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp.py /tmp/lavpc.qmp sendkey alt-f9
```

Capture framebuffer:

```bash
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp.py /tmp/lavpc.qmp screendump /tmp/lavpc-tty9.ppm
magick /tmp/lavpc-tty9.ppm /tmp/lavpc-tty9.png
```

Use `inspect_image` on the PNG when you need a structured reading of what is visible.

### 4. Collect guest-side graphics evidence through tty9

Type tagged commands into the debug shell and redirect output to `ttyS0` so it lands in the serial log.

Examples:

```bash
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp_type.py /tmp/lavpc.qmp 'echo tag analyze >/dev/ttyS0;systemd-analyze >/dev/ttyS0\n'
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp_type.py /tmp/lavpc.qmp 'echo tag dri >/dev/ttyS0;/run/current-system/sw/bin/ls -l /dev/dri 1>/dev/ttyS0 2>/dev/ttyS0\n'
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp_type.py /tmp/lavpc.qmp 'echo tag drm >/dev/ttyS0;journalctl -b --no-pager -g drm >/dev/ttyS0\n'
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp_type.py /tmp/lavpc.qmp 'echo tag drmclass >/dev/ttyS0;/run/current-system/sw/bin/ls /sys/class/drm >/dev/ttyS0\n'
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp_type.py /tmp/lavpc.qmp 'echo tag ninep >/dev/ttyS0;findmnt -t 9p >/dev/ttyS0\n'
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp_type.py /tmp/lavpc.qmp 'echo tag age >/dev/ttyS0;/run/current-system/sw/bin/ls /root/.age/key.txt >/dev/ttyS0 2>/dev/ttyS0\n'
```

Then read the serial log and grep by `tag ...` markers.

## What to look for in this repo

### Graphics

Good:

- `virtio-vga` in QEMU command line
- `virtio_gpu` in boot journal
- `/dev/dri/renderD128`
- `/sys/class/drm` contains `renderD128`

Bad:

- `bochs-drm`
- only `/dev/dri/card0`
- no render node

### Performance

Useful commands:

- `systemd-analyze`
- `systemd-analyze blame`
- `systemd-analyze critical-chain`
- `findmnt -t 9p`

This repo’s measured pattern:

- 9p is present for `/nix/.ro-store` and VM bundle mounts
- main boot cost was `home-manager-lav.service`
- `libvirtd` and Azure VPN/strongSwan were measurable but secondary overhead

### Session pitfalls

- Running `niri-session` from the root debug shell is **not** equivalent to a real user session.
- Expected failure mode when launched the wrong way: missing `$DBUS_SESSION_BUS_ADDRESS` / `$XDG_RUNTIME_DIR`.
- If you invoke `niri-session` from inside an already running login shell, pass `-l`. The wrapper re-enters the login shell unless it sees `-l`, which can create an infinite relogin loop instead of starting the compositor.
- A real proof attempt in this repo showed that plain `niri-session` from `fish.loginShellInit` loops because the wrapper re-execs the login shell; `niri-session -l` avoids that recursion.
- A later proof attempt showed that `dbus-run-session -- niri-session -l` is also the wrong path here: it reached the wrapper, but failed to start `niri.service` through user-systemd.
- On the successful SDL+GL proof path, `niri-session -l` from a real `lav` shell started `niri.service`, but QMP framebuffer capture stayed unusable. The reliable artifact path became: use `niri msg action screenshot-screen` from the live session and export the saved PNG through `/mnt/vm-bundle`.
- For final compositor proof, use a real user session path, not tty9 root shell emulation.

## Quick reference

| Goal                                     | Best method                                          |
| ---------------------------------------- | ---------------------------------------------------- |
| Capture guest framebuffer on non-GL path | `vm_qmp.py ... screendump ...`                       |
| Capture proof on SDL+GL path             | `niri msg action screenshot-screen` + export the PNG |
| Switch TTYs                              | `vm_qmp.py ... sendkey ctrl-alt-f9`                  |
| Run many debug commands                  | `vm_qmp_type.py` + `>/dev/ttyS0` tags                |
| Check render-node health                 | `/run/current-system/sw/bin/ls -l /dev/dri`          |
| Check DRM driver                         | `journalctl -b --no-pager -g drm`                    |
| Verify AGE key staging                   | `/run/current-system/sw/bin/ls /root/.age/key.txt`   |
| Export guest artifact reliably           | copy to `/mnt/vm-bundle/`                            |
| Prove no stale VM remains                | check `ps` for `qemu-system-x86_64`                  |

## Common mistakes

- Waiting on forwarded SSH port instead of actual login/session readiness
- Forgetting tty9 debug shell requires `systemd.debug-shell=1`
- Using plain `ls` / `cat` in the debug shell and hitting PATH issues; prefer `/run/current-system/sw/bin/...`
- Assuming a host screenshot proves guest rendering
- Forgetting to tag ttyS0 output, making logs hard to parse
- Leaving multiple QEMU experiments running at once
- Reusing the same qcow2 across incompatible proof branches and then trusting the resulting failures
- Dumping raw serial logs with ANSI escapes and huge lines directly into a TUI; sanitize and truncate first
- Calling raw `run-<host>-vm` without `VM_BUNDLE_DIR`
- Calling `niri-session` from a login shell without `-l` and accidentally creating a recursion loop
- Trusting QMP `screendump` on the SDL+GL path when it says `no surface`; use a guest-side screenshot artifact instead

## Cleanup

Kill only the VM you started. Match on a unique qcow2 path or QMP socket name.

Example:

```bash
ps -eo pid=,args= | grep '[q]emu-system-x86_64'
kill <pid>
ps -eo pid=,args= | grep '[q]emu-system-x86_64'
```

## Final-proof architecture for `niri-session`

The clean proof shape in this repo is:

1. boot VM with SDL+GL virtio GPU (`-display sdl,gl=on`, `-device virtio-vga-gl`)
2. also force `my.nvidia.enable = false` in the VM path
3. trigger a real `lav` session path for `niri-session`
4. if invoking `niri-session` from an existing login shell, use `niri-session -l`
5. on the SDL+GL path, use guest-side `niri msg action screenshot-screen` and export the PNG through `/mnt/vm-bundle/`
6. collect matching journal/DRM evidence
7. declare success only when image + logs agree

Current best-known non-GL failure signature in this repo: `niri` starts, uses `/dev/dri/renderD128`, and listens on Wayland/X11 sockets, but then logs `error adding device ... ["EGL_EXT_device_drm"]`, `Error::DeviceMissing`, `no output for new layer surface, closing`, and the framebuffer degrades to `Display output is not active.` On the successful SDL+GL path, `niri` can render and produce a guest screenshot artifact even though QMP `screendump` reports `no surface`.
