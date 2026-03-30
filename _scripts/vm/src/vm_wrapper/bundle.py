"""Bundle helpers for the VM wrapper."""

from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path
import shutil
import stat
import tempfile


class UserFacingError(RuntimeError):
    """Raised when user-provided inputs are invalid."""


@dataclass(frozen=True)
class ResolvedInputs:
    """Validated launcher inputs carried into bundle staging."""

    host: str
    age_key: Path
    ssh_key: Path | None


def resolve_inputs(
    host: str,
    home_dir: Path,
    age_key: Path | str | None,
    ssh_key: Path | str | None,
) -> ResolvedInputs:
    resolved_age_key = (
        Path(age_key).expanduser()
        if age_key is not None
        else home_dir / ".age" / "key.txt"
    )
    resolved_ssh_key = Path(ssh_key).expanduser() if ssh_key is not None else None

    validate_secret_file(resolved_age_key, label="AGE key")

    if resolved_ssh_key is not None:
        validate_secret_file(resolved_ssh_key, label="SSH key")

    return ResolvedInputs(host=host, age_key=resolved_age_key, ssh_key=resolved_ssh_key)


def validate_secret_file(path: Path, label: str) -> None:
    try:
        file_stat = path.stat(follow_symlinks=False)
    except FileNotFoundError as exc:
        raise UserFacingError(
            f"{label} does not exist: {path}. Create the file or pass a different path."
        ) from exc

    if not stat.S_ISREG(file_stat.st_mode):
        raise UserFacingError(f"{label} must be a regular file: {path}")

    permission_bits = stat.S_IMODE(file_stat.st_mode)
    if permission_bits & 0o077:
        raise UserFacingError(
            f"{label} has unsafe permissions: {path}. Restrict it with 'chmod 600 {path}'."
        )


def copy_secret(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temp_fd, temp_name = tempfile.mkstemp(dir=destination.parent)
    temp_path = Path(temp_name)

    try:
        os.close(temp_fd)
        shutil.copy2(source, temp_path)
        os.replace(temp_path, destination)
    finally:
        if temp_path.exists():
            temp_path.unlink()


def stage_bundle(bundle_dir: Path, resolved: ResolvedInputs) -> None:
    copy_secret(resolved.age_key, bundle_dir / "age" / "key.txt")

    if resolved.ssh_key is not None:
        copy_secret(resolved.ssh_key, bundle_dir / "ssh" / "id_ed25519")
