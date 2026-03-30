"""Contract assertions for the VM bundle handoff."""

from __future__ import annotations

from typing import TYPE_CHECKING, cast

if TYPE_CHECKING:
    from collections.abc import Callable

    from nix_machine_protocol import Machine


def _assert_copied_file(machine: "Machine", source_path: str, target_path: str) -> None:
    _ = machine.succeed(f"test -f {source_path}")
    _ = machine.succeed(f"test -f {target_path}")
    _ = machine.succeed(f"test ! -L {target_path}")
    _ = machine.succeed(f"cmp -s {source_path} {target_path}")
    _ = machine.succeed(f"test $(stat -c %a {target_path}) -eq 600")


def _bundle_file_exists(machine: "Machine", path: str) -> bool:
    status, _ = machine.execute(f"test -e {path}")
    return status == 0


def run(driver_globals: dict[str, object]) -> None:
    """Run the VM bundle contract assertions."""
    start_all = driver_globals.get("start_all")
    if callable(start_all):
        cast("Callable[[], None]", start_all)()

    machine = cast("Machine", driver_globals["machine"])

    machine.wait_for_unit("multi-user.target")
    _ = machine.succeed("test -L /run/vm-bundle")
    _ = machine.succeed('test "$(readlink /run/vm-bundle)" = /mnt/vm-bundle')

    _assert_copied_file(machine, "/run/vm-bundle/age/key.txt", "/root/.age/key.txt")

    if _bundle_file_exists(machine, "/run/vm-bundle/ssh/id_ed25519"):
        _assert_copied_file(
            machine,
            "/run/vm-bundle/ssh/id_ed25519",
            "/root/.ssh/id_ed25519",
        )
    else:
        _ = machine.succeed("test ! -e /root/.ssh/id_ed25519")


if __name__ == "__main__":
    run(globals())
