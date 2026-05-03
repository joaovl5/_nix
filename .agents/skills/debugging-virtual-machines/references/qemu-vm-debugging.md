# QEMU VM Debugging Reference

## Helpers

- `../scripts/vm_qmp.py`: generic QMP helper; supports `hmp`, `sendkey`, `screendump`, and raw JSON payloads.
- `../scripts/vm_qmp_type.py`: types shell commands into a VM through QMP `sendkey`; pass a real newline when you need Enter.

Examples:

```bash
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp.py /tmp/lavpc.qmp sendkey ctrl-alt-f9
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp.py /tmp/lavpc.qmp screendump /tmp/lavpc.ppm
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp_type.py /tmp/lavpc.qmp $'echo tag analyze >/dev/ttyS0;systemd-analyze >/dev/ttyS0\n'
```

## Diagnostic command batch

Type tagged commands into tty9 and redirect output to `ttyS0`; then read the serial log and search for `tag ...` markers.

```bash
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp_type.py /tmp/lavpc.qmp $'echo tag analyze >/dev/ttyS0;systemd-analyze >/dev/ttyS0\n'
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp_type.py /tmp/lavpc.qmp $'echo tag dri >/dev/ttyS0;/run/current-system/sw/bin/ls -l /dev/dri 1>/dev/ttyS0 2>/dev/ttyS0\n'
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp_type.py /tmp/lavpc.qmp $'echo tag drm >/dev/ttyS0;journalctl -b --no-pager -g drm >/dev/ttyS0\n'
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp_type.py /tmp/lavpc.qmp $'echo tag drmclass >/dev/ttyS0;/run/current-system/sw/bin/ls /sys/class/drm >/dev/ttyS0\n'
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp_type.py /tmp/lavpc.qmp $'echo tag ninep >/dev/ttyS0;findmnt -t 9p >/dev/ttyS0\n'
python .agents/skills/debugging-virtual-machines/scripts/vm_qmp_type.py /tmp/lavpc.qmp $'echo tag age >/dev/ttyS0;/run/current-system/sw/bin/ls /root/.age/key.txt >/dev/ttyS0 2>/dev/ttyS0\n'
```

## Launch notes

Good defaults:

- keep log/socket/image names aligned (`lavpc.*`)
- use a unique `/tmp/<name>.qcow2` per experiment
- add `QEMU_NET_OPTS='hostfwd=tcp::2222-:22'` only if you truly need SSH
- if using a raw generated runner, stage `/tmp/<name>-bundle` with `age/key.txt` and export `VM_BUNDLE_DIR`

## Session pitfalls

- The tty9 root shell proves kernel/system state, not user-session compositor state.
- Missing `$DBUS_SESSION_BUS_ADDRESS` or `$XDG_RUNTIME_DIR` usually means you tested the wrong session path.
- Final compositor proof on SDL+GL should be a real user session plus guest-side screenshot artifact.
- QMP `screendump` on SDL+GL can say `no surface`; treat that as an observability limit, not automatic guest failure.

## Cleanup

Kill only the VM you started. Match on a unique qcow2 path or QMP socket name.

```bash
ps -eo pid=,args= | grep '[q]emu-system-x86_64'
kill <pid>
ps -eo pid=,args= | grep '[q]emu-system-x86_64'
```

## Common mistakes

- Waiting on forwarded SSH instead of actual login/session readiness.
- Forgetting tty9 debug shell requires `systemd.debug-shell=1`.
- Using plain `ls` or `cat` in the debug shell and hitting PATH issues; prefer `/run/current-system/sw/bin/...`.
- Assuming a host screenshot proves guest rendering.
- Forgetting to tag ttyS0 output.
- Leaving multiple QEMU experiments running at once.
- Reusing a qcow2 across incompatible proof branches.
- Dumping raw serial logs with ANSI escapes and huge lines directly into a TUI.
- Calling raw `run-<host>-vm` without `VM_BUNDLE_DIR`.
