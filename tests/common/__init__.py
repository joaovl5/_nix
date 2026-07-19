"""Shared helpers for NixOS Python VM tests."""

import shlex
from typing import Protocol, runtime_checkable

from nix_machine_protocol import Machine as _MachineProtocol


@runtime_checkable
class Machine(_MachineProtocol, Protocol):
  """Runtime-checkable view of the NixOS VM driver protocol."""


def require_machine(
  globals_dict: dict[str, object], key: str
) -> Machine:
  """Return a required VM driver object from the driver globals."""
  value = globals_dict[key]
  assert isinstance(value, Machine), (
    f"Expected Machine for {key}, got {type(value)!r}"
  )
  return value


def q(value: str) -> str:
  """Shell-quote a value for guest command execution."""
  return shlex.quote(value)


def repeat_until_succeeds(
  machine: Machine, command: str, message: str
) -> None:
  """Wait for a command to start succeeding, surfacing driver errors clearly."""
  try:
    _ = machine.wait_until_succeeds(command)
  except (
    Exception
  ) as exc:  # pragma: no cover - integration-driver surface
    error_message = f"{message}: {command}"
    raise AssertionError(error_message) from exc


def succeed(machine: Machine, command: str, message: str) -> str:
  """Run a command and reframe driver failures as assertion failures."""
  try:
    return machine.succeed(command).strip()
  except (
    Exception
  ) as exc:  # pragma: no cover - integration-driver surface
    error_message = f"{message}: {command}"
    raise AssertionError(error_message) from exc


def fail(machine: Machine, command: str, message: str) -> str:
  """Run a command and assert that it fails."""
  status, output = machine.execute(command)
  assert status != 0, (
    f"{message}. Command unexpectedly succeeded: {command}\n{output}"
  )
  return output.strip()
