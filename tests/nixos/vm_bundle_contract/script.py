"""Contract assertions for the VM bundle handoff."""

from typing import Protocol, runtime_checkable

from nix_machine_protocol import Machine as _MachineProtocol


@runtime_checkable
class Machine(_MachineProtocol, Protocol):
  """Runtime-checkable view of the NixOS VM driver protocol."""


def _require_machine(*, globals_dict: dict[str, object], key: str) -> Machine:
  """Return a required VM driver object from the driver globals."""
  value = globals_dict[key]
  assert isinstance(value, Machine), (
    f"Expected Machine for {key}, got {type(value)!r}"
  )
  return value


def _assert_copied_file(
  *, machine: Machine, source_path: str, target_path: str
) -> None:
  """Assert that the bundle copied a regular file with exact contents and mode."""
  _ = machine.succeed(f"test -f {source_path}")
  _ = machine.succeed(f"test -f {target_path}")
  _ = machine.succeed(f"test ! -L {target_path}")
  _ = machine.succeed(f"cmp -s {source_path} {target_path}")
  # Copied private keys must preserve the locked-down 0600 permissions.
  _ = machine.succeed(f"test $(stat -c %a {target_path}) -eq 600")


def _bundle_file_exists(*, machine: Machine, path: str) -> bool:
  """Return whether a file exists inside the mounted VM bundle."""
  status, _ = machine.execute(f"test -e {path}")
  return status == 0


def run(*, driver_globals: dict[str, object]) -> None:
  """Run the VM bundle contract assertions."""
  start_all = driver_globals.get("start_all")
  if callable(start_all):
    start_all()

  machine = _require_machine(globals_dict=driver_globals, key="machine")

  machine.wait_for_unit("multi-user.target")
  _ = machine.succeed("test -L /run/vm-bundle")
  # The runtime handoff must mount the bundle at the reviewed target path.
  _ = machine.succeed('test "$(readlink /run/vm-bundle)" = /mnt/vm-bundle')

  _assert_copied_file(
    machine=machine,
    source_path="/run/vm-bundle/age/key.txt",
    target_path="/root/.age/key.txt",
  )

  if _bundle_file_exists(
    machine=machine, path="/run/vm-bundle/ssh/id_ed25519"
  ):
    _assert_copied_file(
      machine=machine,
      source_path="/run/vm-bundle/ssh/id_ed25519",
      target_path="/root/.ssh/id_ed25519",
    )
  else:
    _ = machine.succeed("test ! -e /root/.ssh/id_ed25519")


if __name__ == "__main__":
  run(driver_globals=globals())
