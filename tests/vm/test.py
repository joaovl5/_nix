from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from collections.abc import Callable

    from nix_machine_protocol import Machine

    class _Machine: ...

    machine: Machine = _Machine()  # pyright: ignore[reportAssignmentType]
    start_all: Callable[[], None] = lambda: None  # noqa: E731

start_all()
machine.wait_for_unit("multi-user.target")
machine.wait_for_unit("NetworkManager.service")
_ = machine.succeed("id lav")
